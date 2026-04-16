/**
 * Stock type definitions
 */

// Base stock interface
export interface Stock {
  id: string
  name: string
  code: string
  quantity: number
  current_price: number
  cost_price: number
  confirmed_profit: number
  first_buy_date: Date | string
  account_id: string
  ended: number
  created_at?: Date | string
  updated_at?: Date | string
}

// Stock holding record
export interface StockHolding {
  id: string
  stock_id: string
  price: number
  quantity: number
  remaining_quantity: number
  fee: number
  transaction_time: Date | string
  account_id: string
  sell_status?: string
}

// Stock transaction record
export interface StockTransaction {
  id: string
  stock_id: string
  price: number
  quantity: number
  type: '买入' | '卖出'
  hold_ids?: string
  fee: number
  transaction_time: Date | string
  account_id: string
}

// Input for adding a new stock
export interface StockInput {
  name: string
  code: string
  price: number
  quantity: number
  fee: number
  transaction_time: Date
  account_id: string
}

// Input for buying stock
export interface StockBuyInput {
  price: number
  quantity: number
  fee: number
  transaction_time: Date
  account_id: string
}

// Input for selling stock
export interface StockSellInput {
  price: number
  quantity: number
  fee: number
  transaction_time: Date
  account_id: string
}

// Sell result with profit calculation
export interface StockSellResult {
  soldQuantity: number
  confirmedProfit: number
  netProceeds: number
}

// Detailed stock view
export interface StockDetail {
  id: string
  name: string
  code: string
  quantity: number
  currentPrice: number
  costPrice: number
  costAmount: number
  confirmedProfit: number
  marketValue: number
}
