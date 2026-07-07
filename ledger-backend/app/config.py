from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    database_url: str
    secret_key: str
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 43200  # 30 天
    cors_origins: str = "http://localhost:5173"
    smtp_host: str = "localhost"
    smtp_port: int = 25
    smtp_from: str = "noreply@finance-server.local"
    frontend_base_url: str = "http://192.168.100.205:5173"

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    @property
    def cors_origin_list(self) -> list[str]:
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]


settings = Settings()
