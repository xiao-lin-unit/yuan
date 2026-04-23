import type dayjs from 'dayjs'

/**
 * Account type definitions
 */

// Base account interface
export interface Account {
  id: string
  name: string
  type: string
  balance: number
  used_limit?: number
  total_limit?: number
  is_liquid?: boolean | number
  status?: string
  remark?: string
  created_at?: dayjs.Dayjs | string
  updated_at?: dayjs.Dayjs | string
}

// Account transaction record
export interface AccountTransaction {
  id: string
  account_id: string
  type: '收入' | '支出' | '转账'
  amount: number
  balance_after: number
  description?: string
  transaction_time: dayjs.Dayjs | string
  created_at?: dayjs.Dayjs | string
}

// Input for adding a new account
export interface AccountInput {
  name: string
  type: string
  balance: number
  used_limit?: number
  total_limit?: number
  is_liquid?: boolean
  remark?: string
}

// Input for balance adjustment
export interface BalanceAdjustInput {
  account_id: string
  type: string
  amount: number
  remark?: string
}

// Input for transfer
export interface TransferInput {
  from_account_id: string
  to_account_id: string
  amount: number
  remark?: string
}

// Input for credit card repayment
export interface RepayCreditCardInput {
  credit_card_id: string
  from_account_id: string
  amount: number
  transaction_time: dayjs.Dayjs
  remark?: string
}
