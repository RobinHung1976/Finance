import { defineStore } from 'pinia'
import { ref } from 'vue'
import { jwtDecode } from 'jwt-decode'

interface JwtPayload {
  sub: string
  household_id: string
  role: 'admin' | 'member'
  exp: number
}

const TOKEN_KEY = 'ledger_token'

export const useAuthStore = defineStore('auth', () => {
  const token = ref<string | null>(localStorage.getItem(TOKEN_KEY))
  const householdId = ref<string | null>(null)
  const userId = ref<string | null>(null)
  const role = ref<'admin' | 'member' | null>(null)

  function decodeAndSet(rawToken: string) {
    const payload = jwtDecode<JwtPayload>(rawToken)
    userId.value = payload.sub
    householdId.value = payload.household_id
    role.value = payload.role
  }

  if (token.value) {
    try {
      decodeAndSet(token.value)
    } catch {
      // token 損毀,清除
      token.value = null
      localStorage.removeItem(TOKEN_KEY)
    }
  }

  function setToken(rawToken: string) {
    token.value = rawToken
    localStorage.setItem(TOKEN_KEY, rawToken)
    decodeAndSet(rawToken)
  }

  function logout() {
    token.value = null
    householdId.value = null
    userId.value = null
    role.value = null
    localStorage.removeItem(TOKEN_KEY)
  }

  function isAuthenticated(): boolean {
    if (!token.value) return false
    try {
      const payload = jwtDecode<JwtPayload>(token.value)
      return payload.exp * 1000 > Date.now()
    } catch {
      return false
    }
  }

  return { token, householdId, userId, role, setToken, logout, isAuthenticated }
})
