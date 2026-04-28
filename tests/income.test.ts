import { describe, it, expect, beforeEach } from 'vitest'
import { resetTestDatabase, seedTestData } from './utils/testDb'
import db from '../src/database/index.js'

describe('Income Module', () => {
  beforeEach(async () => {
    await resetTestDatabase()
    await seedTestData(db)
  })

  it('should query income transactions from transactions table', async () => {
    const incomes = await db.query(
      `SELECT SUM(amount) as total FROM transactions WHERE type = '账户收入'`
    )
    expect(incomes[0].total).toBe(8000)
  })

  it('should insert and retrieve an income transaction', async () => {
    await db.run(
      `INSERT INTO transactions (id, type, sub_type, amount, account_id, balance_after, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      ['tx_inc', '账户收入', 'cat2', 5000, 'acc3', 25000, '2024-06-15']
    )

    const incomes = await db.query(
      `SELECT * FROM transactions WHERE type = '账户收入' AND id = ?`,
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
      `SELECT SUM(amount) as total FROM transactions WHERE type = '账户收入' AND created_at >= ?`,
      [startOfMonth]
    )
    expect(incomes[0].total).toBe(8000)
  })
})
