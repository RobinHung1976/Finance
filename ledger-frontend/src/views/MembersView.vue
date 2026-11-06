<script setup lang="ts">
import { onMounted, ref } from 'vue'
import {
  fetchMyHousehold,
  fetchMembers,
  addMember,
  deleteMember,
  updateHousehold,
  archiveHousehold,
  unarchiveHousehold,
} from '@/api/auth'
import { useAuthStore } from '@/stores/auth'
import type { HouseholdOut, UserOut } from '@/types/api'
import type { AxiosError } from 'axios'
import type { ApiError } from '@/types/api'
import { validateHouseholdName } from '@/utils/validators'
import AppIcon from '@/components/AppIcon.vue'

const auth = useAuthStore()

const household = ref<HouseholdOut | null>(null)
const members = ref<UserOut[]>([])
const isLoading = ref(true)
const loadError = ref('')

// 帳本名稱編輯狀態(僅 admin 可編輯)
const editingName = ref(false)
const nameDraft = ref('')
const nameError = ref('')
const isSavingName = ref(false)

// 封存/解封狀態(僅 admin 可操作)
const isTogglingArchive = ref(false)

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

function startEditName() {
  if (!household.value) return
  nameDraft.value = household.value.name
  nameError.value = ''
  editingName.value = true
}

function cancelEditName() {
  editingName.value = false
  nameError.value = ''
}

async function saveHouseholdName() {
  const err = validateHouseholdName(nameDraft.value)
  if (err) {
    nameError.value = err
    return
  }
  isSavingName.value = true
  try {
    const updated = await updateHousehold(nameDraft.value.trim())
    household.value = updated
    editingName.value = false
  } catch (err) {
    const axiosErr = err as AxiosError<ApiError>
    nameError.value = axiosErr.response?.data?.detail ?? '更新帳本名稱失敗'
  } finally {
    isSavingName.value = false
  }
}

async function handleArchive() {
  const otherMemberCount = members.value.filter((m) => m.id !== auth.userId).length
  if (otherMemberCount > 0) {
    loadError.value = '帳本內還有其他成員,只有最後一位成員時才能封存'
    return
  }
  if (!confirm('確定要封存這個帳本嗎?封存後僅能檢視,需由管理者解封才能恢復使用。')) return

  isTogglingArchive.value = true
  try {
    household.value = await archiveHousehold()
  } catch (err) {
    const axiosErr = err as AxiosError<ApiError>
    loadError.value = axiosErr.response?.data?.detail ?? '封存帳本失敗'
  } finally {
    isTogglingArchive.value = false
  }
}

async function handleUnarchive() {
  isTogglingArchive.value = true
  try {
    household.value = await unarchiveHousehold()
  } catch (err) {
    const axiosErr = err as AxiosError<ApiError>
    loadError.value = axiosErr.response?.data?.detail ?? '解封帳本失敗'
  } finally {
    isTogglingArchive.value = false
  }
}

async function handleDeleteMember(member: UserOut) {
  if (!confirm(`確定要刪除成員「${member.name}」嗎?此操作無法復原。`)) return
  try {
    await deleteMember(member.id)
    await loadData()
  } catch (err) {
    const axiosErr = err as AxiosError<ApiError>
    loadError.value = axiosErr.response?.data?.detail ?? '刪除成員失敗'
  }
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
  <section v-if="household && !household.is_active" class="panel archived">
    <div class="panel-body">
      <h2>{{ household.name }}</h2>
      <p class="hint">此帳本已封存,目前僅能檢視,無法使用其他功能。</p>
      <div v-if="loadError" class="error-banner">{{ loadError }}</div>
      <button
        v-if="auth.role === 'admin'"
        class="btn primary"
        type="button"
        :disabled="isTogglingArchive"
        @click="handleUnarchive"
      >
        {{ isTogglingArchive ? '解封中…' : '解封帳本' }}
      </button>
    </div>
  </section>

  <template v-else>
    <section class="panel">
      <div class="panel-head">
        <h2 v-if="!editingName">
          <AppIcon name="book" />{{ household?.name ?? '載入中…' }}
          <button
            v-if="auth.role === 'admin' && household"
            class="btn ghost sm"
            type="button"
            @click="startEditName"
          >
            編輯
          </button>
        </h2>
        <div v-else class="name-edit">
          <div class="row">
            <input v-model="nameDraft" type="text" maxlength="50" aria-label="帳本名稱" @keyup.enter="saveHouseholdName" />
            <button class="btn primary sm" type="button" :disabled="isSavingName" @click="saveHouseholdName">
              {{ isSavingName ? '儲存中…' : '儲存' }}
            </button>
            <button class="btn sm" type="button" @click="cancelEditName">取消</button>
          </div>
          <span v-if="nameError" class="field-error">{{ nameError }}</span>
        </div>
        <span class="spacer"></span>
        <!-- 僅管理者可見:新增成員為 UX 便利,實際權限由後端 require_admin 把關 -->
        <button
          v-if="auth.role === 'admin' && !isLoading"
          class="btn sm"
          :class="{ on: showAddForm }"
          type="button"
          @click="showAddForm = !showAddForm"
        >
          {{ showAddForm ? '取消' : '+ 新增成員' }}
        </button>
      </div>

      <div class="panel-body">
        <div v-if="loadError" class="error-banner">{{ loadError }}</div>

        <form v-if="showAddForm" class="add-form" @submit.prevent="handleAddMember">
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
            <select id="new-role" v-model="newRole">
              <option value="member">使用者</option>
              <option value="admin">管理者</option>
            </select>
          </div>
          <button class="btn primary" type="submit" :disabled="isAdding">
            {{ isAdding ? '新增中…' : '確認新增' }}
          </button>
        </form>

        <div v-if="!isLoading" class="table-wrap">
          <table class="grid">
            <thead>
              <tr>
                <th>姓名</th>
                <th>權限</th>
                <th class="num">操作</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="member in members" :key="member.id">
                <td>{{ member.name }}</td>
                <td>
                  <span class="pill" :class="{ ok: member.role === 'admin' }">
                    {{ member.role === 'admin' ? '管理者' : '使用者' }}
                  </span>
                </td>
                <td class="num">
                  <button
                    v-if="auth.role === 'admin' && member.id !== auth.userId"
                    class="btn danger sm"
                    type="button"
                    @click="handleDeleteMember(member)"
                  >
                    刪除
                  </button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </section>

    <section v-if="auth.role === 'admin' && !isLoading" class="panel">
      <div class="panel-body row">
        <button class="btn sm" type="button" :disabled="isTogglingArchive" @click="handleArchive">
          {{ isTogglingArchive ? '封存中…' : '封存此帳本' }}
        </button>
        <span class="hint">僅在帳本內只剩自己一位成員時可封存</span>
      </div>
    </section>
  </template>
</template>

<style scoped>
.archived { max-width: 520px; }
.archived h2 { margin: 0 0 6px; font-size: 18px; }
.archived .hint { margin: 0 0 18px; }
.panel-head h2 .btn { margin-left: 4px; }
.name-edit { display: flex; flex-direction: column; gap: 4px; }
.name-edit input { width: 240px; }
.field-error { color: var(--bad); font-size: 12px; }
.add-form {
  max-width: 420px;
  margin-bottom: 20px;
  padding-bottom: 20px;
  border-bottom: 1px dashed var(--line);
}
</style>
