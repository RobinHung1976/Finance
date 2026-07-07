<script setup lang="ts">
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { registerHousehold } from '@/api/auth'
import { useAuthStore } from '@/stores/auth'
import type { AxiosError } from 'axios'
import type { ApiError } from '@/types/api'

const router = useRouter()
const auth = useAuthStore()

const householdName = ref('')
const adminName = ref('')
const adminUsername = ref('')
const adminEmail = ref('')
const adminPassword = ref('')
const errorMessage = ref('')
const isSubmitting = ref(false)

const USERNAME_PATTERN = /^[a-zA-Z0-9_.-]{3,50}$/

async function handleSubmit() {
  errorMessage.value = ''

  if (!USERNAME_PATTERN.test(adminUsername.value)) {
    errorMessage.value = '帳號需為 3-50 字元，僅限英數、底線、句點、連字號'
    return
  }
  if (adminPassword.value.length < 8) {
    errorMessage.value = '密碼至少需要 8 個字元'
    return
  }

  isSubmitting.value = true
  try {
    const { access_token } = await registerHousehold({
      household_name: householdName.value,
      admin_name: adminName.value,
      admin_username: adminUsername.value,
      admin_email: adminEmail.value,
      admin_password: adminPassword.value,
    })
    auth.setToken(access_token)
    router.push({ name: 'dashboard' })
  } catch (err) {
    const axiosErr = err as AxiosError<ApiError>
    errorMessage.value = axiosErr.response?.data?.detail ?? '建立失敗，請確認網路連線'
  } finally {
    isSubmitting.value = false
  }
}
</script>

<template>
  <div class="auth-page">
    <div class="auth-card">
      <h1>建立家庭帳本</h1>
      <p class="subtitle">你將成為第一位管理者</p>

      <div v-if="errorMessage" class="error-banner">{{ errorMessage }}</div>

      <form @submit.prevent="handleSubmit">
        <div class="field">
          <label for="household-name">家庭帳本名稱</label>
          <input id="household-name" v-model="householdName" type="text" required maxlength="100" />
        </div>
        <div class="field">
          <label for="admin-name">你的姓名</label>
          <input id="admin-name" v-model="adminName" type="text" required maxlength="100" />
        </div>
        <div class="field">
          <label for="admin-username">帳號</label>
          <input
            id="admin-username"
            v-model="adminUsername"
            type="text"
            required
            autocomplete="username"
            placeholder="登入用,例如 dad01"
          />
        </div>
        <div class="field">
          <label for="admin-email">Email</label>
          <input
            id="admin-email"
            v-model="adminEmail"
            type="email"
            required
            autocomplete="email"
            placeholder="可與家人共用,忘記密碼時使用"
          />
        </div>
        <div class="field">
          <label for="admin-password">密碼</label>
          <input
            id="admin-password"
            v-model="adminPassword"
            type="password"
            required
            minlength="8"
            autocomplete="new-password"
          />
        </div>
        <button class="btn-primary" type="submit" :disabled="isSubmitting">
          {{ isSubmitting ? '建立中…' : '建立帳本' }}
        </button>
      </form>

      <p class="auth-switch">
        已經有帳本了？<router-link to="/login">登入</router-link>
      </p>
    </div>
  </div>
</template>
