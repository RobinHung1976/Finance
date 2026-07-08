<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
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

const router = useRouter()
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

function handleLogout() {
  auth.logout()
  router.push({ name: 'login' })
}

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
  <div
    v-if="household && !household.is_active"
    style="max-width: 480px; margin: 80px auto; padding: 32px 24px; text-align: center"
  >
    <h1 style="font-size: 20px; margin-bottom: 12px">{{ household.name }}</h1>
    <p style="color: #6b7a74; font-size: 14px; margin-bottom: 24px">
      此帳本已封存,目前僅能檢視,無法使用其他功能。
    </p>
    <div v-if="loadError" class="error-banner" style="margin-bottom: 16px">{{ loadError }}</div>
    <button
      v-if="auth.role === 'admin'"
      class="btn-primary"
      style="width: auto; padding: 8px 20px"
      :disabled="isTogglingArchive"
      @click="handleUnarchive"
    >
      {{ isTogglingArchive ? '解封中…' : '解封帳本' }}
    </button>
    <button
      class="btn-primary"
      style="width: auto; padding: 8px 20px; margin-left: 8px; background: #6b7a74"
      @click="handleLogout"
    >
      登出
    </button>
  </div>

  <div v-else style="max-width: 720px; margin: 0 auto; padding: 32px 24px">
    <header style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 32px">
      <div v-if="!editingName" style="display: flex; align-items: center; gap: 8px">
        <h1 style="font-size: 20px; margin: 0">{{ household?.name ?? '載入中…' }}</h1>
        <button
          v-if="auth.role === 'admin' && household"
          style="border: none; background: none; cursor: pointer; color: var(--color-primary); font-size: 13px; padding: 2px 6px"
          @click="startEditName"
        >
          編輯
        </button>
      </div>
      <div v-else style="display: flex; flex-direction: column; gap: 6px; max-width: 320px">
        <div style="display: flex; gap: 8px">
          <input
            v-model="nameDraft"
            type="text"
            maxlength="50"
            style="flex: 1; padding: 6px 10px; border: 1px solid var(--color-border); border-radius: 6px; font-size: 15px"
            @keyup.enter="saveHouseholdName"
          />
          <button
            class="btn-primary"
            style="width: auto; padding: 6px 12px; font-size: 13px"
            :disabled="isSavingName"
            @click="saveHouseholdName"
          >
            {{ isSavingName ? '儲存中…' : '儲存' }}
          </button>
          <button style="width: auto; padding: 6px 12px; font-size: 13px" @click="cancelEditName">取消</button>
        </div>
        <span v-if="nameError" style="color: #dc2626; font-size: 12px">{{ nameError }}</span>
      </div>

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
          <div style="display: flex; align-items: center; gap: 12px">
            <span style="color: #6b7a74; font-size: 13px">{{ member.role === 'admin' ? '管理者' : '使用者' }}</span>
            <button
              v-if="auth.role === 'admin' && member.id !== auth.userId"
              style="padding: 4px 10px; font-size: 12px; background: #dc2626; color: #fff; border: none; border-radius: 6px; cursor: pointer"
              @click="handleDeleteMember(member)"
            >
              刪除
            </button>
          </div>
        </li>
      </ul>
    </section>

    <div
      v-if="auth.role === 'admin' && !isLoading"
      style="margin-top: 32px; padding-top: 16px; border-top: 1px solid var(--color-border)"
    >
      <button
        style="width: auto; padding: 6px 14px; font-size: 13px; background: #6b7a74; color: #fff; border: none; border-radius: 6px; cursor: pointer"
        :disabled="isTogglingArchive"
        @click="handleArchive"
      >
        {{ isTogglingArchive ? '封存中…' : '封存此帳本' }}
      </button>
      <span style="color: #6b7a74; font-size: 12px; margin-left: 8px">僅在帳本內只剩自己一位成員時可封存</span>
    </div>

    <p style="color: #6b7a74; font-size: 13px; margin-top: 32px">
      交易紀錄、多帳戶與統計圖表功能將在下一步接續開發。
    </p>
  </div>
</template>
