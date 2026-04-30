import { describe, it, expect, beforeEach } from 'vitest'
import { resetTestDatabase, seedTestData } from './utils/testDb'
import db from '../src/database/index.js'

describe('Income Module', () => {
  beforeEach(async () => {
    await resetTestDatabase()
    await seedTestData(db)
  })

  it('should query income records from income_expense_records table', async () => {
    const incomes = await db.query(
      `SELECT SUM(amount) as total FROM income_expense_records WHERE type = '账户收入'`
    )
    expect(incomes[0].total).toBe(8000)
  })

  it('should insert and retrieve an income transaction', async () => {
    await db.run(
      `INSERT INTO income_expense_records (id, type, sub_type, amount, account_id, balance_after, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      ['tx_inc', '账户收入', 'cat2', 5000, 'acc3', 25000, '2024-06-15']
    )

    const incomes = await db.query(
      `SELECT * FROM income_expense_records WHERE type = '账户收入' AND id = ?`,
      ['tx_inc']
    )
    expect(incomes.length).toBe(1)
    expect(incomes[0].amount).toBe(5000)
    expect(incomes[0].sub_type).toBe('cat2')
  })

  it('should calculate monthly income total', async () => {
    const now = new Date()
    const startOfMonth = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-01`

    const incomes = await db.query(
      `SELECT SUM(amount) as total FROM income_expense_records WHERE type = '账户收入' AND created_at >= ?`,
      [startOfMonth]
    )
    expect(incomes[0].total).toBe(8000)
  })
})
