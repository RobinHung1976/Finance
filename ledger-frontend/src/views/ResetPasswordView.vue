<script setup lang="ts">
import { ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { resetPassword } from '@/api/auth'
import type { AxiosError } from 'axios'
import type { ApiError } from '@/types/api'

const route = useRoute()
const router = useRouter()

const token = (route.query.token as string) ?? ''
const newPassword = ref('')
const confirmPassword = ref('')
const errorMessage = ref('')
const isSubmitting = ref(false)
const isDone = ref(false)

async function handleSubmit() {
  errorMessage.value = ''

  if (!token) {
    errorMessage.value = '重設連結無效，請重新申請'
    return
  }
  if (newPassword.value.length < 8) {
    errorMessage.value = '密碼至少需要 8 個字元'
    return
  }
  if (newPassword.value !== confirmPassword.value) {
    errorMessage.value = '兩次輸入的密碼不一致'
    return
  }

  isSubmitting.value = true
  try {
    await resetPassword(token, newPassword.value)
    isDone.value = true
    setTimeout(() => router.push({ name: 'login' }), 2000)
  } catch (err) {
    const axiosErr = err as AxiosError<ApiError>
    errorMessage.value = axiosErr.response?.data?.detail ?? '重設失敗，請稍後再試'
  } finally {
    isSubmitting.value = false
  }
}
</script>

<template>
  <div class="auth-page">
    <div class="auth-card">
      <template v-if="!isDone">
        <h1>設定新密碼</h1>

        <div v-if="!token" class="error-banner">連結無效，請重新申請忘記密碼</div>
        <div v-else-if="errorMessage" class="error-banner">{{ errorMessage }}</div>

        <form @submit.prevent="handleSubmit">
          <div class="field">
            <label for="new-password">新密碼</label>
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
            <label for="confirm-password">確認新密碼</label>
            <input
              id="confirm-password"
              v-model="confirmPassword"
              type="password"
              required
              minlength="8"
              autocomplete="new-password"
            />
          </div>
          <button class="btn-primary" type="submit" :disabled="isSubmitting || !token">
            {{ isSubmitting ? '處理中…' : '重設密碼' }}
          </button>
        </form>
      </template>

      <template v-else>
        <h1>密碼已重設</h1>
        <p class="subtitle">即將導向登入頁…</p>
      </template>
    </div>
  </div>
</template>
