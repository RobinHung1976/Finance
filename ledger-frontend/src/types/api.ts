export interface TokenResponse {
  access_token: string
  token_type: string
}

export interface HouseholdOut {
  id: string
  name: string
  created_at: string
}

export type UserRole = 'admin' | 'member'

export interface UserOut {
  id: string
  name: string
  username: string
  email: string
  role: UserRole
  created_at: string
}

export interface ApiError {
  detail: string
}
