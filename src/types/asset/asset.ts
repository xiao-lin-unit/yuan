/**
 * General asset type definitions
 */

// Base asset interface
export interface Asset {
  id: string
  type: string
  name: string
  amount: number
  account_id: string
  period?: string
  period_count?: number
  income_date?: string
  next_income_date?: string
  ended: number
  created_at?: Date | string
  updated_at?: Date | string
}

// Input for adding a new asset
export interface AssetInput {
  type: string
  name: string
  amount: number
  account_id: string
  period?: string
  period_count?: number
  income_date?: string
}
