const ALLOWED_HOUSEHOLD_NAME_PATTERN = /^[\u4e00-\u9fffA-Za-z0-9 _-]+$/
const MAX_HOUSEHOLD_NAME_LENGTH = 50

/** 回傳 null 代表通過驗證,否則回傳錯誤訊息(規則需與後端 app/validators.py 保持同步) */
export function validateHouseholdName(name: string): string | null {
  const trimmed = name.trim()
  if (!trimmed) return '帳本名稱不可為空'
  if (trimmed.length > MAX_HOUSEHOLD_NAME_LENGTH) return `帳本名稱長度不可超過 ${MAX_HOUSEHOLD_NAME_LENGTH} 字`
  if (!ALLOWED_HOUSEHOLD_NAME_PATTERN.test(trimmed)) {
    return '帳本名稱僅能包含中文、英文、數字、空白、底線(_)、連字號(-)'
  }
  return null
}
