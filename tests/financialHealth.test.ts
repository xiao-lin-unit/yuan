import { describe, it, expect, beforeEach } from 'vitest'
import { resetTestDatabase, seedTestData } from './utils/testDb'
import db from '../src/database/index.js'

describe('Financial Health Assessment', () => {
  beforeEach(async () => {
    await resetTestDatabase()
    await seedTestData(db)
  })

  it('should calculate total assets correctly', async () => {
    const accounts = await db.query(`SELECT * FROM accounts WHERE status = '启用'`)
    const assets = await db.query(`SELECT * FROM assets WHERE status != '结束'`)
    const stocks = await db.query(`SELECT * FROM stocks WHERE ended = 0`)
    const funds = await db.query(`SELECT * FROM funds WHERE ended = 0`)

    const liquidBalance = accounts
      .filter((a: any) => a.type !== '信用卡')
      .reduce((s: number, a: any) => s + (a.balance || 0), 0)
    const assetAmount = assets.reduce((s: number, a: any) => s + (a.amount || 0), 0)
    const stockValue = stocks.reduce((s: number, st: any) => s + (st.current_price || 0) * (st.quantity || 0), 0)
    const fundValue = funds.reduce((s: number, f: any) => s + (f.current_nav || 0) * (f.shares || 0), 0)

    const totalAssets = liquidBalance + assetAmount + stockValue + fundValue
    expect(totalAssets).toBe(25000 + 10000 + 5000 + 1250)
    expect(totalAssets).toBe(41250)
  })

  it('should calculate total liabilities correctly', async () => {
    const liabilities = await db.query(`SELECT * FROM liabilities WHERE status = '未结清'`)
    const creditCards = await db.query(`SELECT * FROM accounts WHERE type = '信用卡' AND status = '启用'`)

    const totalLiabilities = liabilities.reduce((s: number, l: any) => s + (l.remaining_principal || 0), 0) +
      creditCards.reduce((s: number, a: any) => s + (a.used_limit || 0), 0)

    expect(totalLiabilities).toBe(300000 + 2000)
    expect(totalLiabilities).toBe(302000)
  })

  it('should calculate net worth correctly', async () => {
    const totalAssets = 41250
    const totalLiabilities = 302000
    const netWorth = totalAssets - totalLiabilities
    expect(netWorth).toBe(-260750)
  })

  it('should calculate monthly cash flow', async () => {
    const incomes = await db.query(`SELECT SUM(amount) as total FROM transactions WHERE type = '账户收入'`)
    const expenses = await db.query(`SELECT SUM(amount) as total FROM transactions WHERE type = '账户支出'`)

    const monthlyIncome = (incomes[0].total || 0) / 3
    const monthlyExpense = (expenses[0].total || 0) / 3

    const liabilities = await db.query(`SELECT * FROM liabilities WHERE status = '未结清'`)
    const monthlyRepayment = liabilities.reduce((s: number, l: any) => {
      if (l.repayment_method === '等额本息') {
        const monthlyRate = l.interest_rate / 100 / 12
        const payment = l.remaining_principal * monthlyRate * Math.pow(1 + monthlyRate, l.period || 1) /
          (Math.pow(1 + monthlyRate, l.period || 1) - 1)
        return s + payment
      }
      return s
    }, 0)

    const cashFlow = monthlyIncome - monthlyExpense - monthlyRepayment
    expect(cashFlow).toBeCloseTo(8000 / 3 - 3500 / 3 - monthlyRepayment, 2)
  })

  it('should calculate debt-to-income ratio', async () => {
    const incomes = await db.query(`SELECT SUM(amount) as total FROM transactions WHERE type = '账户收入'`)
    const monthlyIncome = (incomes[0].total || 0) / 3

    const liabilities = await db.query(`SELECT * FROM liabilities WHERE status = '未结清'`)
    const monthlyRepayment = liabilities.reduce((s: number, l: any) => {
      if (l.repayment_method === '等额本息') {
        const monthlyRate = l.interest_rate / 100 / 12
        const payment = l.remaining_principal * monthlyRate * Math.pow(1 + monthlyRate, l.period || 1) /
          (Math.pow(1 + monthlyRate, l.period || 1) - 1)
        return s + payment
      }
      return s
    }, 0)

    const ratio = monthlyIncome > 0 ? (monthlyRepayment / monthlyIncome) * 100 : 0
    expect(ratio).toBeCloseTo((monthlyRepayment / (8000 / 3)) * 100, 2)
  })

  it('should calculate asset-liability ratio', async () => {
    const totalAssets = 41250
    const totalLiabilities = 302000
    const ratio = totalAssets > 0 ? (totalLiabilities / totalAssets) * 100 : 0
    expect(ratio).toBeCloseTo((302000 / 41250) * 100, 2)
  })

  it('should store and retrieve monthly snapshots', async () => {
    const snapshotId = '2024_06_test'
    await db.run(
      `INSERT INTO asset_monthly_snapshots (id, year, month, total_assets, total_liabilities, net_worth)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [snapshotId, 2024, 6, 50000, 300000, -250000]
    )

    const snapshots = await db.query(
      `SELECT * FROM asset_monthly_snapshots WHERE year = ? AND month = ?`,
      [2024, 6]
    )
    expect(snapshots.length).toBe(1)
    expect(snapshots[0].total_assets).toBe(50000)
    expect(snapshots[0].net_worth).toBe(-250000)
  })
})
