<script setup lang="ts">
import { ref } from 'vue'
import { forgotPassword } from '@/api/auth'

const email = ref('')
const isSubmitting = ref(false)
const isSubmitted = ref(false)
const errorMessage = ref('')

async function handleSubmit() {
  errorMessage.value = ''
  isSubmitting.value = true
  try {
    await forgotPassword(email.value)
    isSubmitted.value = true // 無論帳號是否存在,一律顯示成功,避免帳號列舉
  } catch {
    errorMessage.value = '發送失敗，請稍後再試'
  } finally {
    isSubmitting.value = false
  }
}
</script>

<template>
  <div class="auth-page">
    <div class="auth-card">
      <template v-if="!isSubmitted">
        <h1>忘記密碼</h1>
        <p class="subtitle">輸入註冊時填寫的 email，我們會寄送重設連結</p>

        <div v-if="errorMessage" class="error-banner">{{ errorMessage }}</div>

        <form @submit.prevent="handleSubmit">
          <div class="field">
            <label for="email">Email</label>
            <input id="email" v-model="email" type="email" required autocomplete="email" />
          </div>
          <button class="btn-primary" type="submit" :disabled="isSubmitting">
            {{ isSubmitting ? '發送中…' : '發送重設信件' }}
          </button>
        </form>
      </template>

      <template v-else>
        <h1>信件已寄出</h1>
        <p class="subtitle">
          若該 email 有對應帳號，重設連結已寄至你的信箱。若家庭成員共用 email，信中會列出所有相關帳號。
        </p>
      </template>

      <p class="auth-switch">
        <router-link to="/login">返回登入</router-link>
      </p>
    </div>
  </div>
</template>
