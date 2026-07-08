import { apiClient } from './client'
import type { TokenResponse, HouseholdOut, UserOut, UserRole, AuditLogPage, AuditLogFilters } from '@/types/api'

export interface RegisterHouseholdPayload {
  household_name: string
  admin_name: string
  admin_username: string
  admin_email: string
  admin_password: string
}

export interface LoginPayload {
  username: string
  password: string
}

export function registerHousehold(payload: RegisterHouseholdPayload) {
  return apiClient.post<TokenResponse>('/auth/register', payload).then((r) => r.data)
}

export function login(payload: LoginPayload) {
  return apiClient.post<TokenResponse>('/auth/login', payload).then((r) => r.data)
}

export function fetchMyHousehold() {
  return apiClient.get<HouseholdOut>('/households/me').then((r) => r.data)
}

export function fetchMembers() {
  return apiClient.get<UserOut[]>('/households/me/members').then((r) => r.data)
}

export interface AddMemberPayload {
  name: string
  username: string
  email: string
  password: string
  role: UserRole
}

export function addMember(payload: AddMemberPayload) {
  return apiClient.post<UserOut>('/households/me/members', payload).then((r) => r.data)
}

export function deleteMember(userId: string) {
  return apiClient.delete(`/households/me/members/${userId}`)
}

export function fetchAuditLogs(limit: number, offset: number, filters: AuditLogFilters = {}) {
  return apiClient
    .get<AuditLogPage>('/households/me/audit-logs', { params: { limit, offset, ...filters } })
    .then((r) => r.data)
}

export function forgotPassword(email: string) {
  return apiClient.post<{ message: string }>('/auth/forgot-password', { email }).then((r) => r.data)
}

export function resetPassword(token: string, newPassword: string) {
  return apiClient
    .post<{ message: string }>('/auth/reset-password', { token, new_password: newPassword })
    .then((r) => r.data)
}

export async function updateHousehold(name: string): Promise<HouseholdOut> {
  const { data } = await apiClient.patch<HouseholdOut>('/households/me', { name })
  return data
}

export async function archiveHousehold(): Promise<HouseholdOut> {
  const { data } = await apiClient.post<HouseholdOut>('/households/me/archive')
  return data
}

export async function unarchiveHousehold(): Promise<HouseholdOut> {
  const { data } = await apiClient.post<HouseholdOut>('/households/me/unarchive')
  return data
}
