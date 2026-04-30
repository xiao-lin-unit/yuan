/**
 * Monthly Financial Snapshot Task
 * 每月末财务快照自动保存任务
 *
 * On app startup, calculates current total assets/liabilities/net worth
 * and saves a snapshot to asset_monthly_snapshots table.
 */
import db from '../../database'
import { getCurrentDate } from '../../utils/timezone'
import { registerTask } from '../index'

registerTask('monthlyFinancialSnapshot', async () => {
  await db.connect()

  const now = getCurrentDate()  
  const year = now.year()
  const month = now.month() + 1

  // Load all accounts
  const accounts = await db.query(
    "SELECT * FROM accounts WHERE status = '启用'"
  )

  // Load all assets
  const assets = await db.query('SELECT * FROM assets')

  // Load all stocks
  const stocks = await db.query('SELECT * FROM stocks')

  // Load all funds
  const funds = await db.query('SELECT * FROM funds')

  // Load all liabilities
  const liabilities = await db.query('SELECT * FROM liabilities')

  // Calculate liquid funds (non-credit card accounts)
  const liquidFunds = accounts
    .filter((a: any) => a.type !== '信用卡')
    .reduce((sum: number, a: any) => sum + (a.balance || 0), 0)

  // Social security & provident fund
  const socialSecurity = assets
    .filter((a: any) => a.type === '社保')
    .reduce((sum: number, a: any) => sum + (a.amount || 0), 0)

  const providentFund = assets
    .filter((a: any) => a.type === '公积金')
    .reduce((sum: number, a: any) => sum + (a.amount || 0), 0)

  // Stock & fund market value
  const stockValue = stocks.reduce(
    (sum: number, s: any) => sum + (s.current_price || 0) * (s.quantity || 0),
    0
  )

  const fundValue = funds.reduce(
    (sum: number, f: any) => sum + (f.current_nav || 0) * (f.shares || 0),
    0
  )

  // Loans to friends/family
  const loans = assets
    .filter((a: any) => a.type === '亲友借款')
    .reduce((sum: number, a: any) => sum + (a.amount || 0), 0)

  // Total assets
  const totalAssets =
    liquidFunds + socialSecurity + providentFund + stockValue + fundValue + loans

  // Credit card used limit
  const creditCardUsed = accounts
    .filter((a: any) => a.type === '信用卡')
    .reduce((sum: number, a: any) => sum + (a.used_limit || 0), 0)

  // Total liabilities
  const liabilityPrincipal = liabilities.reduce(
    (sum: number, l: any) => sum + (l.remaining_principal || 0),
    0
  )
  const totalLiabilities = liabilityPrincipal + creditCardUsed

  // Net worth
  const netWorth = totalAssets - totalLiabilities

  // Confirmed profits
  const confirmedProfitStocks = stocks.reduce(
    (sum: number, s: any) => sum + (s.confirmed_profit || 0),
    0
  )

  const confirmedProfitFunds = funds.reduce(
    (sum: number, f: any) => sum + (f.confirmed_profit || 0),
    0
  )

  // Check if snapshot already exists for this month
  const existing = await db.query(
    'SELECT id FROM asset_monthly_snapshots WHERE year = ? AND month = ?',
    [year, month]
  )
  console.log('新增或者修改月统计数据:', totalAssets, totalLiabilities, netWorth, confirmedProfitStocks, confirmedProfitFunds, year, month)

  if (existing.length > 0) {
    // Update existing record
    await db.run(
      `UPDATE asset_monthly_snapshots
       SET total_assets = ?, total_liabilities = ?, net_worth = ?, confirmed_profit_stocks = ?, confirmed_profit_funds = ?, created_at = CURRENT_TIMESTAMP
       WHERE year = ? AND month = ?`,
      [totalAssets, totalLiabilities, netWorth, confirmedProfitStocks, confirmedProfitFunds, year, month]
    )
  } else {
    // Insert new record
    const id = `${year}_${month}_${Date.now()}`
    await db.run(
      `INSERT INTO asset_monthly_snapshots (id, year, month, total_assets, total_liabilities, net_worth, confirmed_profit_stocks, confirmed_profit_funds)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [id, year, month, totalAssets, totalLiabilities, netWorth, confirmedProfitStocks, confirmedProfitFunds]
    )
  }
})
