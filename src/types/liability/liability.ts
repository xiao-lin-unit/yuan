/**
 * Liability type definitions
 */
import type dayjs from 'dayjs'

// Base liability interface
export interface Liability {
  id: string
  name: string
  type: string
  principal: number
  remaining_principal: number
  remaining_total_interest: number
  is_interest: boolean
  interest_rate: number
  start_date: dayjs.Dayjs | string
  repayment_method: string
  repayment_day?: number
  period?: number
  account_id: string
  remark?: string
  status: '未结清' | '已结清'
  created_at?: dayjs.Dayjs | string
  updated_at?: dayjs.Dayjs | string
}

// Repayment record
export interface Repayment {
  id: string
  liability_id: string
  period_number?: number
  amount: number
  principal_amount: number
  interest_amount: number
  type: '正常还款' | '提前还款'
  remark?: string
  repayment_time: dayjs.Dayjs | string
  created_at?: dayjs.Dayjs | string
}

// Input for adding a new liability
export interface LiabilityInput {
  name: string
  type: string
  principal: number
  is_interest: boolean
  interest_rate: number
  start_date: dayjs.Dayjs
  repayment_method: string
  repayment_day?: number
  period?: number
  account_id: string
  remark?: string
}

// Pending repayment record
export interface PendingRepayment {
  id: string
  liability_id: string
  period_number: number
  due_date: dayjs.Dayjs | string
  principal_amount: number
  interest_amount: number
  total_amount: number
  status: '未还' | '已还' | '作废'
  paid_date?: dayjs.Dayjs | string
  created_at?: dayjs.Dayjs | string
}

// Input for making repayment
export interface RepaymentInput {
  liabilityId: string
  amount: number
  type: '正常还款' | '提前还款'
  remark?: string
}
