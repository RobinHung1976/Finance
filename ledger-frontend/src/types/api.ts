export interface TokenResponse {
  access_token: string
  token_type: string
}

export interface HouseholdOut {
  id: string
  name: string
  is_active: boolean
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

export interface AuditLogOut {
  id: string
  actor_name: string | null
  action: 'login' | 'create' | 'update' | 'delete'
  resource_type: string
  resource_id: string | null
  detail: string | null
  created_at: string
}

export interface AuditLogPage {
  items: AuditLogOut[]
  total: number
  limit: number
  offset: number
}

export interface AuditLogFilters {
  action?: string
  resource_type?: string
  start_date?: string
  end_date?: string
}
