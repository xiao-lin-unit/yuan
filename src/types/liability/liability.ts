/**
 * Liability type definitions
 */

// Base liability interface
export interface Liability {
  id: string
  name: string
  type: string
  principal: number
  remaining_principal: number
  is_interest: boolean
  interest_rate: number
  start_date: Date | string
  repayment_method: string
  repayment_day?: number
  period?: number
  account_id: string
  remark?: string
  status: '未结清' | '已结清'
  created_at?: Date | string
  updated_at?: Date | string
}

// Repayment record
export interface Repayment {
  id: string
  liability_id: string
  amount: number
  type: '正常还款' | '提前还款'
  remark?: string
  repayment_time: Date | string
  created_at?: Date | string
}

// Input for adding a new liability
export interface LiabilityInput {
  name: string
  type: string
  principal: number
  is_interest: boolean
  interest_rate: number
  start_date: Date
  repayment_method: string
  repayment_day?: number
  period?: number
  account_id: string
  remark?: string
}

// Input for making repayment
export interface RepaymentInput {
  liabilityId: string
  amount: number
  type: '正常还款' | '提前还款'
  remark?: string
}
