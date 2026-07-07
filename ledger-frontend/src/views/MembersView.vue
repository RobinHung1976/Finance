<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { fetchMyHousehold, fetchMembers, addMember } from '@/api/auth'
import { useAuthStore } from '@/stores/auth'
import type { HouseholdOut, UserOut } from '@/types/api'
import type { AxiosError } from 'axios'
import type { ApiError } from '@/types/api'

const router = useRouter()
const auth = useAuthStore()

const household = ref<HouseholdOut | null>(null)
const members = ref<UserOut[]>([])
const isLoading = ref(true)
const loadError = ref('')

// 新增成員表單狀態
const showAddForm = ref(false)
const newName = ref('')
const newUsername = ref('')
const newEmail = ref('')
const newPassword = ref('')
const newRole = ref<'admin' | 'member'>('member')
const addError = ref('')
const isAdding = ref(false)

const USERNAME_PATTERN = /^[a-zA-Z0-9_.-]{3,50}$/

async function loadData() {
  try {
    const [householdData, membersData] = await Promise.all([fetchMyHousehold(), fetchMembers()])
    household.value = householdData
    members.value = membersData
  } catch {
    loadError.value = '載入資料失敗，請重新登入'
  } finally {
    isLoading.value = false
  }
}

onMounted(loadData)

function handleLogout() {
  auth.logout()
  router.push({ name: 'login' })
}

function resetAddForm() {
  newName.value = ''
  newUsername.value = ''
  newEmail.value = ''
  newPassword.value = ''
  newRole.value = 'member'
  addError.value = ''
}

async function handleAddMember() {
  addError.value = ''

  if (!USERNAME_PATTERN.test(newUsername.value)) {
    addError.value = '帳號需為 3-50 字元，僅限英數、底線、句點、連字號'
    return
  }
  if (newPassword.value.length < 8) {
    addError.value = '密碼至少需要 8 個字元'
    return
  }

  isAdding.value = true
  try {
    await addMember({
      name: newName.value,
      username: newUsername.value,
      email: newEmail.value,
      password: newPassword.value,
      role: newRole.value,
    })
    resetAddForm()
    showAddForm.value = false
    await loadData() // 重新載入成員列表
  } catch (err) {
    const axiosErr = err as AxiosError<ApiError>
    addError.value = axiosErr.response?.data?.detail ?? '新增成員失敗'
  } finally {
    isAdding.value = false
  }
}
</script>

<template>
  <div style="max-width: 720px; margin: 0 auto; padding: 32px 24px">
    <header style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 32px">
      <h1 style="font-size: 20px; margin: 0">{{ household?.name ?? '載入中…' }}</h1>
      <div style="display: flex; gap: 12px; align-items: center">
        <router-link to="/" style="font-size: 13px; color: var(--color-primary); text-decoration: none">
          返回理財首頁
        </router-link>
        <button class="btn-primary" style="width: auto; padding: 8px 16px" @click="handleLogout">
          登出
        </button>
      </div>
    </header>

    <div v-if="loadError" class="error-banner">{{ loadError }}</div>

    <section v-if="!isLoading">
      <div style="display: flex; justify-content: space-between; align-items: center">
        <h2 style="font-size: 15px; color: #6b7a74; text-transform: uppercase; letter-spacing: 0.04em; margin: 0">
          成員
        </h2>
        <!-- 僅管理者可見:新增成員為 UX 便利,實際權限由後端 require_admin 把關 -->
        <button
          v-if="auth.role === 'admin'"
          class="btn-primary"
          style="width: auto; padding: 6px 14px; font-size: 13px"
          @click="showAddForm = !showAddForm"
        >
          {{ showAddForm ? '取消' : '+ 新增成員' }}
        </button>
      </div>

      <form
        v-if="showAddForm"
        @submit.prevent="handleAddMember"
        style="
          background: var(--color-surface);
          border: 1px solid var(--color-border);
          border-radius: 8px;
          padding: 16px;
          margin: 12px 0;
        "
      >
        <div v-if="addError" class="error-banner">{{ addError }}</div>

        <div class="field">
          <label for="new-name">姓名</label>
          <input id="new-name" v-model="newName" type="text" required maxlength="100" />
        </div>
        <div class="field">
          <label for="new-username">帳號</label>
          <input
            id="new-username"
            v-model="newUsername"
            type="text"
            required
            autocomplete="off"
            placeholder="登入用,例如 mom01"
          />
        </div>
        <div class="field">
          <label for="new-email">Email</label>
          <input id="new-email" v-model="newEmail" type="email" required autocomplete="off" />
        </div>
        <div class="field">
          <label for="new-password">初始密碼</label>
          <input
            id="new-password"
            v-model="newPassword"
            type="password"
            required
            minlength="8"
            autocomplete="new-password"
          />
        </div>
        <div class="field">
          <label for="new-role">權限</label>
          <select
            id="new-role"
            v-model="newRole"
            style="
              width: 100%;
              padding: 10px 12px;
              border: 1px solid var(--color-border);
              border-radius: 8px;
              font-size: 14px;
              background: var(--color-bg);
            "
          >
            <option value="member">使用者</option>
            <option value="admin">管理者</option>
          </select>
        </div>
        <button class="btn-primary" type="submit" :disabled="isAdding">
          {{ isAdding ? '新增中…' : '確認新增' }}
        </button>
      </form>

      <ul style="list-style: none; padding: 0; margin: 12px 0 0">
        <li
          v-for="member in members"
          :key="member.id"
          style="
            display: flex;
            justify-content: space-between;
            padding: 12px 16px;
            background: var(--color-surface);
            border: 1px solid var(--color-border);
            border-radius: 8px;
            margin-bottom: 8px;
          "
        >
          <span>{{ member.name }}</span>
          <span style="color: #6b7a74; font-size: 13px">{{ member.role === 'admin' ? '管理者' : '使用者' }}</span>
        </li>
      </ul>
    </section>

    <p style="color: #6b7a74; font-size: 13px; margin-top: 32px">
      交易紀錄、多帳戶與統計圖表功能將在下一步接續開發。
    </p>
  </div>
</template>
