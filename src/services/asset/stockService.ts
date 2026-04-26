/**
 * Stock Service
 * Handles all stock-related business logic and database operations
 */

import dayjs from 'dayjs'
import db from '../../database/index.js'
import type {
  Stock,
  StockHolding,
  StockTransaction,
  StockInput,
  StockBuyInput,
  StockSellInput,
  StockSellResult,
  StockDetail
} from '../../types/asset/stock.js'
import { calculateTotalCost, calculateCostPrice, calculateWeightedCostPrice, calculateSellProfit } from '../../utils/calculations.js'
import { createDebitTransaction, createCreditTransaction } from '../account/accountService.js'

/**
 * Get all stocks
 */
export async function getAllStocks(): Promise<Stock[]> {
  return await db.query('SELECT * FROM stocks ORDER BY created_at DESC')
}

/**
 * Validate stock code format (6 digits)
 */
export function validateStockCode(code: string): boolean {
  const codePattern = /^\d{6}$/
  return codePattern.test(code)
}

/**
 * Check if a stock with the given code already exists
 */
export async function checkStockExists(code: string): Promise<{ exists: boolean; ended: boolean }> {
  const existingStocks = await db.query('SELECT * FROM stocks WHERE code = ?', [code])
  if (existingStocks.length > 0) {
    const stock = existingStocks[0]
    return { exists: true, ended: stock.ended === 1 || stock.ended === true }
  }
  return { exists: false, ended: false }
}

/**
 * Get available accounts for stock operations (excluding credit cards)
 */
export async function getAvailableAccounts(): Promise<Array<{ id: string; name: string; balance: number }>> {
  return await db.query('SELECT id, name, balance FROM accounts WHERE type != ?', ['信用卡'])
}

/**
 * Check if account has sufficient balance
 */
export async function checkAccountBalance(accountId: string, requiredAmount: number): Promise<{ sufficient: boolean; currentBalance: number }> {
  const accountData = await db.query('SELECT balance FROM accounts WHERE id = ?', [accountId])
  if (accountData.length === 0) {
    return { sufficient: false, currentBalance: 0 }
  }
  const currentBalance = accountData[0].balance
  return { sufficient: currentBalance >= requiredAmount, currentBalance }
}

/**
 * Add a new stock with initial buy transaction
 */
export async function addStock(stockData: StockInput, deductFromAccount: boolean = true): Promise<void> {
  const stockId = dayjs().valueOf().toString()
  const totalCost = calculateTotalCost(stockData.price, stockData.quantity, stockData.fee)

  // Calculate cost price
  const costPrice = calculateCostPrice(stockData.price, stockData.quantity, stockData.fee)

  const statements: { statement: string; values: any[] }[] = []

  // Create stock record
  statements.push({
    statement: `INSERT INTO stocks (id, name, code, quantity, current_price, cost_price, first_buy_date, account_id)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
    values: [
      stockId,
      stockData.name,
      stockData.code,
      stockData.quantity,
      stockData.price,
      costPrice,
      stockData.transaction_time,
      stockData.account_id
    ]
  })

  const holdingId = dayjs().valueOf().toString() + '_hold'
  const transactionId = dayjs().valueOf().toString()

  // Create stock holding record
  statements.push({
    statement: `INSERT INTO stock_holdings (id, stock_id, price, quantity, remaining_quantity, fee, transaction_time, account_id)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
    values: [
      holdingId,
      stockId,
      stockData.price,
      stockData.quantity,
      stockData.quantity,
      stockData.fee,
      stockData.transaction_time,
      stockData.account_id
    ]
  })

  // Create stock transaction record (buy)
  statements.push({
    statement: `INSERT INTO stock_transactions (id, stock_id, price, quantity, type, hold_ids, fee, transaction_time, account_id)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    values: [
      transactionId,
      stockId,
      stockData.price,
      stockData.quantity,
      '买入',
      holdingId,
      stockData.fee,
      stockData.transaction_time,
      stockData.account_id
    ]
  })

  // Deduct from account if requested
  if (deductFromAccount) {
    const debitResult = await createDebitTransaction(stockData.account_id, totalCost, `股票买入：${stockData.name}`)
    statements.push(...debitResult.statements)
  }

  await db.executeTransaction(statements)
}

/**
 * Buy additional shares of an existing stock
 */
export async function buyStock(stockId: string, buyData: StockBuyInput): Promise<void> {
  // Get current stock data
  const stockData = await db.query('SELECT * FROM stocks WHERE id = ?', [stockId])
  if (stockData.length === 0) {
    throw new Error('股票不存在')
  }
  const currentStock = stockData[0]

  // Check account balance
  const accountCheck = await checkAccountBalance(buyData.account_id, calculateTotalCost(buyData.price, buyData.quantity, buyData.fee))
  if (!accountCheck.sufficient) {
    throw new Error(`账户余额不足，需要 ¥${calculateTotalCost(buyData.price, buyData.quantity, buyData.fee).toFixed(2)}，当前余额 ¥${accountCheck.currentBalance.toFixed(2)}`)
  }

  const totalCost = calculateTotalCost(buyData.price, buyData.quantity, buyData.fee)

  // 使用新的出账接口
  const debitResult = await createDebitTransaction(buyData.account_id, totalCost, `股票买入：${currentStock.name}`)

  // Calculate new cost price using weighted average
  const newCostPrice = calculateWeightedCostPrice(
    currentStock.cost_price,
    currentStock.quantity,
    buyData.price,
    buyData.quantity,
    buyData.fee
  )
  const newQuantity = currentStock.quantity + buyData.quantity

  // Prepare transaction statements
  const holdingId = dayjs().valueOf().toString() + '_hold'
  const transactionId = dayjs().valueOf().toString()

  const statements = [
    // Create stock holding record
    {
      statement: `INSERT INTO stock_holdings (id, stock_id, price, quantity, remaining_quantity, fee, transaction_time, account_id) 
                  VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      values: [
        holdingId,
        stockId,
        buyData.price,
        buyData.quantity,
        buyData.quantity,
        buyData.fee,
        buyData.transaction_time,
        buyData.account_id
      ]
    },
    // Create stock transaction record (buy)
    {
      statement: `INSERT INTO stock_transactions (id, stock_id, price, quantity, type, hold_ids, fee, transaction_time, account_id) 
                  VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      values: [
        transactionId,
        stockId,
        buyData.price,
        buyData.quantity,
        '买入',
        holdingId,
        buyData.fee,
        buyData.transaction_time,
        buyData.account_id
      ]
    },
    // Update stock record (reset ended status to 0)
    {
      statement: `UPDATE stocks SET quantity = ?, current_price = ?, cost_price = ?, ended = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?`,
      values: [newQuantity, buyData.price, newCostPrice, 0, stockId]
    },
    // 使用出账接口返回的SQL语句（已包含账户更新和交易记录）
    ...debitResult.statements
  ]

  await db.executeTransaction(statements)
}

/**
 * Sell stock shares using FIFO (First In First Out) method
 */
export async function sellStock(stockId: string, sellData: StockSellInput): Promise<StockSellResult> {
  // Check stock total quantity
  const stockData = await db.query('SELECT * FROM stocks WHERE id = ?', [stockId])
  if (stockData.length === 0) {
    throw new Error('股票不存在')
  }
  const stock = stockData[0]

  if (sellData.quantity > stock.quantity) {
    throw new Error('卖出数量不能大于股票的总数量')
  }

  // Query available holdings (not fully sold)
  const holdings = await db.query(
    'SELECT * FROM stock_holdings WHERE stock_id = ? AND sell_status != ? ORDER BY transaction_time ASC',
    [stockId, '已卖出']
  )

  if (holdings.length === 0) {
    throw new Error('没有可卖出的持有记录')
  }

  // Calculate total available quantity
  const totalAvailableQuantity = holdings.reduce((total: number, holding: StockHolding) => total + holding.remaining_quantity, 0)
  if (sellData.quantity > totalAvailableQuantity) {
    throw new Error(`卖出数量不能大于可卖出的总数量（当前可卖出数量：${totalAvailableQuantity}）`)
  }

  // Prepare transaction statements
  const statements = []
  let remainingQuantityToSell = sellData.quantity
  const soldHoldIds: string[] = []

  // Deduct from earliest holdings first (FIFO)
  for (const holding of holdings) {
    if (remainingQuantityToSell <= 0) break

    const availableQuantity = holding.remaining_quantity
    const quantityToDeduct = Math.min(availableQuantity, remainingQuantityToSell)

    // Update holding record
    const newRemainingQuantity = availableQuantity - quantityToDeduct
    let newSellStatus = holding.sell_status

    if (newRemainingQuantity === 0) {
      newSellStatus = '已卖出'
    } else if (newRemainingQuantity < availableQuantity) {
      newSellStatus = '部分卖出'
    }

    statements.push({
      statement: 'UPDATE stock_holdings SET remaining_quantity = ?, sell_status = ? WHERE id = ?',
      values: [newRemainingQuantity, newSellStatus, holding.id]
    })

    soldHoldIds.push(holding.id)
    remainingQuantityToSell -= quantityToDeduct
  }

  // Create stock transaction record (sell)
  const transactionId = dayjs().valueOf().toString()
  statements.push({
    statement: `INSERT INTO stock_transactions (id, stock_id, price, quantity, type, hold_ids, fee, transaction_time, account_id) 
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    values: [
      transactionId,
      stockId,
      sellData.price,
      sellData.quantity,
      '卖出',
      soldHoldIds.join(','),
      sellData.fee,
      sellData.transaction_time,
      sellData.account_id
    ]
  })

  // Update stock record
  const newQuantity = stock.quantity - sellData.quantity
  const confirmedProfit = calculateSellProfit(sellData.price, stock.cost_price, sellData.quantity, sellData.fee)
  const newConfirmedProfit = (stock.confirmed_profit || 0) + confirmedProfit
  const isEnded = newQuantity === 0 ? 1 : 0

  statements.push({
    statement: `UPDATE stocks SET quantity = ?, current_price = ?, confirmed_profit = ?, ended = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?`,
    values: [newQuantity, sellData.price, newConfirmedProfit, isEnded, stockId]
  })

  // Calculate net proceeds
  const netProceeds = (sellData.price * sellData.quantity) - sellData.fee

  // 使用新的入账接口（已包含账户更新和交易记录）
  const creditResult = await createCreditTransaction(sellData.account_id, netProceeds, `股票卖出：${stock.name}`)

  // 添加入账接口返回的SQL语句
  statements.push(...creditResult.statements)

  await db.executeTransaction(statements)

  return {
    soldQuantity: sellData.quantity,
    confirmedProfit,
    netProceeds
  }
}

/**
 * Get stock detail by ID
 */
export async function getStockDetail(stockId: string): Promise<StockDetail> {
  const stock = await db.query('SELECT * FROM stocks WHERE id = ?', [stockId])
  if (stock.length === 0) {
    throw new Error('股票不存在')
  }

  const s = stock[0]

  // Calculate derived values
  const costAmount = s.cost_price * s.quantity
  const currentAmount = s.current_price * s.quantity
  const totalReturn = currentAmount - costAmount
  const confirmedReturn = s.confirmed_profit || 0
  const holdReturn = totalReturn - confirmedReturn

  return {
    id: s.id,
    name: s.name,
    code: s.code,
    costAmount,
    costPrice: s.cost_price,
    currentPrice: s.current_price,
    quantity: s.quantity,
    confirmedProfit: confirmedReturn,
    marketValue: currentAmount
  }
}

/**
 * Get stock holdings
 */
export async function getStockHoldings(stockId: string): Promise<StockHolding[]> {
  return await db.query(
    'SELECT * FROM stock_holdings WHERE stock_id = ? ORDER BY transaction_time ASC',
    [stockId]
  )
}

/**
 * Get stock transactions (buy and sell)
 */
export async function getStockTransactions(stockId: string): Promise<{ buyTransactions: StockTransaction[]; sellTransactions: StockTransaction[] }> {
  const transactions = await db.query(
    'SELECT * FROM stock_transactions WHERE stock_id = ? ORDER BY transaction_time DESC',
    [stockId]
  )

  return {
    buyTransactions: transactions.filter((t: StockTransaction) => t.type === '买入'),
    sellTransactions: transactions.filter((t: StockTransaction) => t.type === '卖出')
  }
}

/**
 * Update stock current price
 */
export async function updateStockPrice(stockId: string, newPrice: number): Promise<void> {
  if (newPrice <= 0) {
    throw new Error('股价必须大于0')
  }

  await db.run(
    'UPDATE stocks SET current_price = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
    [newPrice, stockId]
  )
}

/**
 * Get stock by ID (basic info)
 */
export async function getStockById(stockId: string): Promise<Stock | null> {
  const result = await db.query('SELECT * FROM stocks WHERE id = ?', [stockId])
  return result.length > 0 ? result[0] : null
}