/**
 * Fund Service
 * Handles all fund-related business logic and database operations
 */

import db from '../../database/index.js'
import type {
  Fund,
  FundHolding,
  FundTransaction,
  FundInput,
  FundBuyInput,
  FundSellInput,
  FundSellResult,
  FundDetail
} from '../../types/asset/fund.js'
import { calculateTotalCost, calculateFundWeightedNavCostPrice } from '../../utils/calculations.js'
import { createDebitTransaction, createCreditTransaction } from '../account/accountService.js'

/**
 * Get all funds
 */
export async function getAllFunds(): Promise<Fund[]> {
  return await db.query('SELECT * FROM funds ORDER BY created_at DESC')
}

/**
 * Validate fund code format (6 digits)
 */
export function validateFundCode(code: string): boolean {
  const codePattern = /^\d{6}$/
  return codePattern.test(code)
}

/**
 * Check if a fund with the given code already exists
 */
export async function checkFundExists(code: string): Promise<{ exists: boolean; ended: boolean }> {
  const existingFunds = await db.query('SELECT * FROM funds WHERE code = ?', [code])
  if (existingFunds.length > 0) {
    const fund = existingFunds[0]
    return { exists: true, ended: fund.ended === 1 || fund.ended === true }
  }
  return { exists: false, ended: false }
}

/**
 * Get available accounts for fund operations (excluding credit cards)
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
 * Calculate lock end date based on lock period
 */
export function calculateLockEndDate(transactionTime: Date, lockPeriod: number): Date | null {
  if (!lockPeriod || lockPeriod <= 0) return null
  const lockEndDate = new Date(transactionTime)
  lockEndDate.setMonth(lockEndDate.getMonth() + lockPeriod)
  return lockEndDate
}

/**
 * Add a new fund with initial buy transaction
 */
export async function addFund(fundData: FundInput): Promise<void> {
  const fundId = Date.now().toString()
  const totalCost = calculateTotalCost(fundData.cost_nav, fundData.shares, fundData.fee)

  // 使用新的出账接口
  const debitResult = await createDebitTransaction(fundData.account_id, totalCost, `基金买入：${fundData.name}`)

  // Calculate lock end date
  const lockEndDate = calculateLockEndDate(fundData.transaction_time, fundData.lock_period)

  const statements = []

  // Create fund record
  statements.push({
    statement: `INSERT INTO funds (id, name, code, shares, current_nav, cost_nav, total_fee, first_buy_date, has_lock, lock_period, account_id) 
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    values: [
      fundId,
      fundData.name,
      fundData.code,
      fundData.shares,
      fundData.cost_nav,
      fundData.cost_nav,
      fundData.fee,
      fundData.transaction_time,
      fundData.has_lock,
      fundData.lock_period,
      fundData.account_id
    ]
  })

  const holdingId = Date.now().toString() + '_hold'
  const transactionId = Date.now().toString()

  // Create fund holding record
  statements.push({
    statement: `INSERT INTO fund_holdings (id, fund_id, nav, shares, remaining_shares, fee, lock_period, lock_end_date, transaction_time, account_id) 
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    values: [
      holdingId,
      fundId,
      fundData.cost_nav,
      fundData.shares,
      fundData.shares,
      fundData.fee,
      fundData.lock_period,
      lockEndDate,
      fundData.transaction_time,
      fundData.account_id
    ]
  })

  // Create fund transaction record (buy)
  statements.push({
    statement: `INSERT INTO fund_transactions (id, fund_id, transaction_nav, shares, type, hold_ids, fee, transaction_time, account_id) 
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    values: [
      transactionId,
      fundId,
      fundData.cost_nav,
      fundData.shares,
      '买入',
      holdingId,
      fundData.fee,
      fundData.transaction_time,
      fundData.account_id
    ]
  })

  // 使用出账接口返回的SQL语句（已包含账户更新和交易记录）
  statements.push(...debitResult.statements)

  await db.executeTransaction(statements)
}

/**
 * Buy additional shares of an existing fund
 */
export async function buyFund(fundId: string, buyData: FundBuyInput): Promise<void> {
  // Get current fund data
  const fundData = await db.query('SELECT * FROM funds WHERE id = ?', [fundId])
  if (fundData.length === 0) {
    throw new Error('基金不存在')
  }
  const currentFund = fundData[0]

  const totalCost = calculateTotalCost(buyData.nav, buyData.shares, buyData.fee)

  // 使用新的出账接口
  const debitResult = await createDebitTransaction(buyData.account_id, totalCost, `基金买入：${currentFund.name}`)

  // Calculate new cost nav using weighted average
  const currentTotalValue = currentFund.cost_nav * currentFund.shares
  const newBuyValue = buyData.nav * buyData.shares
  const newShares = currentFund.shares + buyData.shares
  const newCostNav = (currentTotalValue + newBuyValue) / newShares

  // Calculate lock end date
  const lockEndDate = calculateLockEndDate(buyData.transaction_time, buyData.lock_period)

  const holdingId = Date.now().toString() + '_hold'
  const transactionId = Date.now().toString()
  const accountTransactionId = Date.now().toString() + '_acc'

  const statements = [
    // Create fund holding record
    {
      statement: `INSERT INTO fund_holdings (id, fund_id, nav, shares, remaining_shares, fee, lock_period, lock_end_date, transaction_time, account_id) 
                  VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      values: [
        holdingId,
        fundId,
        buyData.nav,
        buyData.shares,
        buyData.shares,
        buyData.fee,
        buyData.lock_period,
        lockEndDate,
        buyData.transaction_time,
        buyData.account_id
      ]
    },
    // Create fund transaction record (buy)
    {
      statement: `INSERT INTO fund_transactions (id, fund_id, transaction_nav, shares, type, hold_ids, fee, transaction_time, account_id) 
                  VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      values: [
        transactionId,
        fundId,
        buyData.nav,
        buyData.shares,
        '买入',
        holdingId,
        buyData.fee,
        buyData.transaction_time,
        buyData.account_id
      ]
    },
    // Update fund record (reset ended status to 0)
    {
      statement: `UPDATE funds SET shares = ?, current_nav = ?, cost_nav = ?, total_fee = ?, ended = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?`,
      values: [newShares, buyData.nav, newCostNav, currentFund.total_fee + buyData.fee, 0, fundId]
    },
    // 使用出账接口返回的SQL语句（已包含账户更新和交易记录）
    ...debitResult.statements
  ]

  await db.executeTransaction(statements)
}

/**
 * Sell fund shares using FIFO (First In First Out) method
 */
export async function sellFund(fundId: string, sellData: FundSellInput): Promise<FundSellResult> {
  // Check fund total shares
  const fundData = await db.query('SELECT * FROM funds WHERE id = ?', [fundId])
  if (fundData.length === 0) {
    throw new Error('基金不存在')
  }
  const fund = fundData[0]

  if (sellData.shares > fund.shares) {
    throw new Error('卖出份额不能大于基金的总份额')
  }

  // Query available holdings (not fully sold and lock period expired)
  const currentDate = new Date().toISOString()
  const holdings = await db.query(
    'SELECT * FROM fund_holdings WHERE fund_id = ? AND sell_status != ? AND (lock_end_date IS NULL OR lock_end_date <= ?) ORDER BY transaction_time ASC',
    [fundId, '已卖出', currentDate]
  )

  if (holdings.length === 0) {
    throw new Error('没有可卖出的持有记录（所有记录均在锁定期内）')
  }

  // Calculate total available shares
  const totalAvailableShares = holdings.reduce((total: number, holding: FundHolding) => total + holding.remaining_shares, 0)
  if (sellData.shares > totalAvailableShares) {
    throw new Error(`卖出份额不能大于可卖出的总份额（当前可卖出份额：${totalAvailableShares}）`)
  }

  // Prepare transaction statements
  const statements = []
  let remainingSharesToSell = sellData.shares
  const soldHoldIds: string[] = []

  // Deduct from earliest holdings first (FIFO)
  for (const holding of holdings) {
    if (remainingSharesToSell <= 0) break

    const availableShares = holding.remaining_shares
    const sharesToDeduct = Math.min(availableShares, remainingSharesToSell)

    // Update holding record
    const newRemainingShares = availableShares - sharesToDeduct
    let newSellStatus = holding.sell_status

    if (newRemainingShares === 0) {
      newSellStatus = '已卖出'
    } else if (newRemainingShares < availableShares) {
      newSellStatus = '部分卖出'
    }

    statements.push({
      statement: 'UPDATE fund_holdings SET remaining_shares = ?, sell_status = ? WHERE id = ?',
      values: [newRemainingShares, newSellStatus, holding.id]
    })

    soldHoldIds.push(holding.id)
    remainingSharesToSell -= sharesToDeduct
  }

  // Create fund transaction record (sell)
  const transactionId = Date.now().toString()
  statements.push({
    statement: `INSERT INTO fund_transactions (id, fund_id, transaction_nav, shares, type, hold_ids, fee, transaction_time, account_id) 
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    values: [
      transactionId,
      fundId,
      sellData.nav,
      sellData.shares,
      '卖出',
      soldHoldIds.join(','),
      sellData.fee,
      sellData.transaction_time,
      sellData.account_id
    ]
  })

  // Update fund record
  const newShares = fund.shares - sellData.shares
  const confirmedProfit = (sellData.nav - fund.cost_nav) * sellData.shares - sellData.fee
  const newConfirmedProfit = (fund.confirmed_profit || 0) + confirmedProfit
  const isEnded = newShares === 0 ? 1 : 0

  statements.push({
    statement: `UPDATE funds SET shares = ?, current_nav = ?, confirmed_profit = ?, ended = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?`,
    values: [newShares, sellData.nav, newConfirmedProfit, isEnded, fundId]
  })

  // Calculate net proceeds
  const netProceeds = (sellData.nav * sellData.shares) - sellData.fee

  // 使用新的入账接口（已包含账户更新和交易记录）
  const creditResult = await createCreditTransaction(sellData.account_id, netProceeds, `基金卖出：${fund.name}`)

  // 添加入账接口返回的SQL语句
  statements.push(...creditResult.statements)

  await db.executeTransaction(statements)

  return {
    soldShares: sellData.shares,
    confirmedProfit,
    netProceeds
  }
}

/**
 * Get fund detail by ID
 */
export async function getFundDetail(fundId: string): Promise<FundDetail> {
  const fund = await db.query('SELECT * FROM funds WHERE id = ?', [fundId])
  if (fund.length === 0) {
    throw new Error('基金不存在')
  }

  const f = fund[0]

  // Calculate derived values
  const costAmount = f.cost_nav * f.shares
  const currentAmount = f.current_nav * f.shares
  const totalReturn = currentAmount - costAmount
  const confirmedReturn = f.confirmed_profit || 0
  const holdReturn = totalReturn - confirmedReturn

  return {
    id: f.id,
    name: f.name,
    code: f.code,
    costAmount,
    costFee: f.cost_fee || 0,
    costNav: f.cost_nav,
    currentNav: f.current_nav,
    shares: f.shares,
    confirmedReturn,
    holdReturn,
    totalReturn
  }
}

/**
 * Get fund holdings
 */
export async function getFundHoldings(fundId: string): Promise<FundHolding[]> {
  return await db.query(
    'SELECT * FROM fund_holdings WHERE fund_id = ? ORDER BY transaction_time ASC',
    [fundId]
  )
}

/**
 * Get fund transactions (buy and sell)
 */
export async function getFundTransactions(fundId: string): Promise<{ buyTransactions: FundTransaction[]; sellTransactions: FundTransaction[] }> {
  const transactions = await db.query(
    'SELECT * FROM fund_transactions WHERE fund_id = ? ORDER BY transaction_time DESC',
    [fundId]
  )

  return {
    buyTransactions: transactions.filter((t: FundTransaction) => t.type === '买入'),
    sellTransactions: transactions.filter((t: FundTransaction) => t.type === '卖出')
  }
}

/**
 * Update fund NAV (current net asset value)
 */
export async function updateFundNav(fundId: string, newNav: number): Promise<void> {
  if (newNav <= 0) {
    throw new Error('净值必须大于0')
  }

  await db.run(
    'UPDATE funds SET current_nav = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
    [newNav, fundId]
  )
}

/**
 * Get fund by ID (basic info)
 */
export async function getFundById(fundId: string): Promise<Fund | null> {
  const result = await db.query('SELECT * FROM funds WHERE id = ?', [fundId])
  return result.length > 0 ? result[0] : null
}