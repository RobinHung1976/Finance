<script setup lang="ts">
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { login } from '@/api/auth'
import { useAuthStore } from '@/stores/auth'
import type { AxiosError } from 'axios'
import type { ApiError } from '@/types/api'

const router = useRouter()
const auth = useAuthStore()

const username = ref('')
const password = ref('')
const errorMessage = ref('')
const isSubmitting = ref(false)

async function handleSubmit() {
  errorMessage.value = ''
  isSubmitting.value = true
  try {
    const { access_token } = await login({ username: username.value, password: password.value })
    auth.setToken(access_token)
    router.push({ name: 'dashboard' })
  } catch (err) {
    const axiosErr = err as AxiosError<ApiError>
    errorMessage.value = axiosErr.response?.data?.detail ?? '登入失敗，請確認網路連線'
  } finally {
    isSubmitting.value = false
  }
}
</script>

<template>
  <div class="auth-page">
    <div class="auth-card">
      <h1>登入</h1>
      <p class="subtitle">家庭理財網站</p>

      <div v-if="errorMessage" class="error-banner">{{ errorMessage }}</div>

      <form @submit.prevent="handleSubmit">
        <div class="field">
          <label for="username">帳號</label>
          <input id="username" v-model="username" type="text" required autocomplete="username" />
        </div>
        <div class="field">
          <label for="password">密碼</label>
          <input id="password" v-model="password" type="password" required autocomplete="current-password" />
        </div>
        <button class="btn-primary" type="submit" :disabled="isSubmitting">
          {{ isSubmitting ? '登入中…' : '登入' }}
        </button>
      </form>

      <p class="auth-switch">
        <router-link to="/forgot-password">忘記密碼？</router-link>
      </p>
      <p class="auth-switch">
        還沒有家庭帳本？<router-link to="/register">建立新帳本</router-link>
      </p>
      <!-- TODO(paused): 忘記密碼功能已完成 API + 頁面(ForgotPasswordView/ResetPasswordView),
           待 SMTP 寄信基礎建設驗證穩定後再開放入口連結 -->
    </div>
  </div>
</template>
