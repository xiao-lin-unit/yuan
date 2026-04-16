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
  remark?: string
  created_at?: Date | string
  updated_at?: Date | string
}

// Account transaction record
export interface AccountTransaction {
  id: string
  account_id: string
  type: '收入' | '支出' | '转账'
  amount: number
  balance_after: number
  description?: string
  transaction_time: Date | string
  created_at?: Date | string
}

// Input for adding a new account
export interface AccountInput {
  name: string
  type: string
  balance: number
  usedLimit?: number
  totalLimit?: number
  isLiquid?: boolean
  remark?: string
}

// Input for balance adjustment
export interface BalanceAdjustInput {
  accountId: string
  type: string
  amount: number
  remark?: string
}

// Input for transfer
export interface TransferInput {
  fromAccountId: string
  toAccountId: string
  amount: number
  remark?: string
}
