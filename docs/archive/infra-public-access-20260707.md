# 對外連線基礎建設:FortiGate + Nginx

建立日期:2026-07-07

## 一、背景

原規劃(`finance-1st-core-feature-20260706.md`)用 Cloudflare Tunnel 對外連線。目前**雲端方案暫停**,改用內部網路測試(`192.168.100.205:5173`),對外改走 **FortiGate 防火牆 + 固定 public IP**。

## 二、決策

| 項目 | 決定 |
|---|---|
| Public IP | 固定 |
| 網域 | 暫不使用,先用 public IP:port(⚠️ 見下方 SSL 限制) |
| 對外 port | `17756`(避開已被佔用的 80/443,不用標準 port) |
| 前端服務型態 | 從 `vite --host` dev server 轉為 `vite build` 靜態檔,由 Nginx serve |

## 三、FortiGate 設定

```
# VIP:外部 17756 -> 內部 192.168.100.205:17756
config firewall vip
    edit "ledger-vip"
        set extip <PUBLIC_IP>
        set extintf "wan1"
        set portforward enable
        set mappedip "192.168.100.205"
        set extport 17756
        set mappedport 17756
        set protocol tcp
    next
end

# Custom service,收斂 policy 只放行這個 port
config firewall service custom
    edit "tcp-17756"
        set tcp-portrange 17756
    next
end

# Firewall Policy
config firewall policy
    edit 0
        set name "ledger-inbound"
        set srcintf "wan1"
        set dstintf "internal"
        set srcaddr "all"
        set dstaddr "ledger-vip"
        set action accept
        set schedule "always"
        set service "tcp-17756"
        set logtraffic all
        set nat disable
    next
end
```

**狀態**:✅ 已設定並測試完成

## 四、Nginx 設定(單一入口,靜態檔 + API reverse proxy)

```nginx
# /etc/nginx/sites-available/ledger
server {
    listen 17756;
    server_name _;

    root /var/www/ledger-frontend;
    index index.html;

    location ~ ^/(auth|households|accounts|categories|transactions|stats)(/|$) {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location = /health {
        proxy_pass http://127.0.0.1:8000;
    }

    location / {
        try_files $uri $uri/ /index.html;
    }

    location /assets/ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
```

```bash
sudo ln -sf /etc/nginx/sites-available/ledger /etc/nginx/sites-enabled/ledger
sudo rm -f /etc/nginx/sites-enabled/default
sudo ufw allow 17756/tcp comment 'ledger public via fortigate'
```

**好處**:前端呼叫 API 改用相對路徑(`VITE_API_BASE_URL=` 空字串),同源請求,不需要 CORS 設定。

## 五、Service 現況(對照 `software-architecture-20260707.md` 更新)

| Service | 狀態 | 說明 |
|---|---|---|
| PostgreSQL | systemd 常駐 | 不變 |
| `ledger-api`(後端) | systemd,已 enabled | 不變,`WorkingDirectory=/root/apps/ledger-backend` |
| 前端 | **不再是獨立 process** | 原本 `nohup npm run dev -- --host &`,現改為 `vite build` 產出靜態檔,由 Nginx 直接 serve,不需要 systemd unit |
| Nginx | systemd 常駐 | 從只反代 backend(8000),改為單一入口(靜態檔 + API proxy),監聽 `17756` |
| Cloudflare Tunnel | **暫停使用** | 未設定 `/etc/cloudflared`,改用 FortiGate 對外 |
| Postfix | systemd 常駐,入口暫停 | 不變,忘記密碼信件功能暫不恢復 |

## 六、已知限制 / 風險

- **無域名 = 無 HTTPS**:Let's Encrypt 需要域名做驗證,純 public IP 無法申請受信任憑證
- **目前是明文 HTTP 對外**:JWT token 在網路上可被側錄,⚠️ 僅適合短期測試,不建議放正式資料/密碼
- **緩解方案(擇一,尚未執行)**:
  - FortiGate policy 的 `srcaddr` 收斂成白名單,而非 `all`
  - 申請免費動態域名(如 DuckDNS)接 Let's Encrypt,成本接近零

## 七、後續建議

1. 若要長期對外使用,建議至少做上述緩解方案其中一項
2. `frontend_base_url`(`config.py`)目前是內網位址 `http://192.168.100.205:5173`,Postfix 恢復時記得改成 `http://<PUBLIC_IP>:17756`
3. 是否需要幫忙寫 DuckDNS + Let's Encrypt 的設定,之後有需要再說
