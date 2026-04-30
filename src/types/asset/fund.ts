import type dayjs from 'dayjs'

/**
 * Fund type definitions
 */

// Base fund interface
export interface Fund {
  id: string
  name: string
  code: string
  shares: number
  current_nav: number
  cost_nav: number
  total_fee: number
  first_buy_date: dayjs.Dayjs | string
  has_lock: boolean
  lock_period: number
  account_id: string
  status: string
  created_at?: dayjs.Dayjs | string
  updated_at?: dayjs.Dayjs | string
}

// Fund holding record
export interface FundHolding {
  id: string
  fund_id: string
  nav: number
  shares: number
  remaining_shares: number
  fee: number
  lock_period: number
  lock_end_date: dayjs.Dayjs | string | null
  transaction_time: dayjs.Dayjs | string
  account_id: string
  sell_status?: string
}

// Fund transaction record
export interface FundTransaction {
  id: string
  fund_id: string
  transaction_nav: number
  shares: number
  type: '买入' | '卖出'
  hold_ids?: string
  fee: number
  transaction_time: dayjs.Dayjs | string
  account_id: string
}

// Input for adding a new fund
export interface FundInput {
  name: string
  code: string
  cost_nav: number
  shares: number
  fee: number
  has_lock: boolean
  lock_period: number
  transaction_time: dayjs.Dayjs
  account_id: string
}

// Input for buying fund
export interface FundBuyInput {
  nav: number
  shares: number
  fee: number
  has_lock: boolean
  lock_period: number
  transaction_time: dayjs.Dayjs
  account_id: string
}

// Input for selling fund
export interface FundSellInput {
  nav: number
  shares: number
  fee: number
  transaction_time: dayjs.Dayjs
  account_id: string
}

// Sell result with profit calculation
export interface FundSellResult {
  soldShares: number
  confirmedProfit: number
  netProceeds: number
}

// Detailed fund view
export interface FundDetail {
  id: string
  name: string
  code: string
  shares: number
  currentNav: number
  costNav: number
  costAmount: number
  costFee: number
  confirmedReturn: number
  holdReturn: number
  totalReturn: number
}
