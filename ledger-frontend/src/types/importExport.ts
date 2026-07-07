export interface ImportRowPreview {
  sheet: string
  row: number
  date: string
  category_top: string
  item: string | null
  amount: number
  type: 'income' | 'expense'
  will_create_category: boolean
  is_duplicate: boolean
  error: string | null
}

export interface ImportPreviewResponse {
  total_rows: number
  valid_rows: number
  new_categories: string[]
  errors: string[]
  rows: ImportRowPreview[]
}

export interface ImportCommitResponse {
  imported: number
  skipped_errors: number
  skipped_duplicates: number
  created_categories: number
}
