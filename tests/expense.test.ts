import { describe, it, expect, beforeEach } from 'vitest'
import { resetTestDatabase, seedTestData } from './utils/testDb'
import db from '../src/database/index.js'

describe('Expense Module', () => {
  beforeEach(async () => {
    await resetTestDatabase()
    await seedTestData(db)
  })

  it('should query expense records from income_expense_records table', async () => {
    const expenses = await db.query(
      `SELECT SUM(amount) as total FROM income_expense_records WHERE type = '账户支出'`
    )
    expect(expenses[0].total).toBe(3500)
  })

  it('should insert and retrieve an expense transaction', async () => {
    await db.run(
      `INSERT INTO income_expense_records (id, type, sub_type, amount, account_id, balance_after, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      ['tx_exp', '账户支出', 'cat1', 500, 'acc1', 1000, '2024-06-15']
    )

    const expenses = await db.query(
      `SELECT * FROM income_expense_records WHERE type = '账户支出' AND id = ?`,
      ['tx_exp']
    )
    expect(expenses.length).toBe(1)
    expect(expenses[0].amount).toBe(500)
    expect(expenses[0].sub_type).toBe('cat1')
  })

  it('should filter expenses by date range', async () => {
    const now = new Date()
    const startOfMonth = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-01`

    const expenses = await db.query(
      `SELECT SUM(amount) as total FROM income_expense_records WHERE type = '账户支出' AND created_at >= ?`,
      [startOfMonth]
    )
    expect(expenses[0].total).toBe(3500)
  })
})
