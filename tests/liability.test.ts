import { describe, it, expect, beforeEach } from 'vitest'
import { resetTestDatabase, seedTestData } from './utils/testDb'
import db from '../src/database/index.js'
import { calculateTotalInterest } from '../src/services/liability/liabilityService'

describe('Liability Module', () => {
  beforeEach(async () => {
    await resetTestDatabase()
    await seedTestData(db)
  })

  describe('Liability CRUD', () => {
    it('should retrieve active liabilities', async () => {
      const liabilities = await db.query(`SELECT * FROM liabilities WHERE status = '未结清'`)
      expect(liabilities.length).toBe(1)
      expect(liabilities[0].name).toBe('房贷')
      expect(liabilities[0].remaining_principal).toBe(300000)
    })

    it('should calculate total remaining principal', async () => {
      const liabilities = await db.query(`SELECT * FROM liabilities WHERE status = '未结清'`)
      const total = liabilities.reduce((s: number, l: any) => s + (l.remaining_principal || 0), 0)
      expect(total).toBe(300000)
    })

    it('should calculate monthly repayment amount', async () => {
      const liability = (await db.query(`SELECT * FROM liabilities WHERE id = 'lia1'`))[0]
      // 等额本息月供计算: P * r * (1+r)^n / ((1+r)^n - 1)
      const principal = liability.remaining_principal
      const monthlyRate = liability.interest_rate / 100 / 12
      const periods = liability.period
      const monthlyPayment = principal * monthlyRate * Math.pow(1 + monthlyRate, periods) /
        (Math.pow(1 + monthlyRate, periods) - 1)
      expect(monthlyPayment).toBeGreaterThan(0)
    })
  })

  describe('Interest Calculation', () => {
    it('should calculate total interest for equal principal and interest', () => {
      const interest = calculateTotalInterest(100000, 4.2, 240, '等额本息')
      expect(interest).toBeGreaterThan(0)
      // Total payment should be > principal
      const monthlyRate = 4.2 / 12 / 100
      const monthlyPayment = 100000 * monthlyRate * Math.pow(1 + monthlyRate, 240) /
        (Math.pow(1 + monthlyRate, 240) - 1)
      const expectedTotalInterest = Math.round((monthlyPayment * 240 - 100000) * 100) / 100
      expect(interest).toBeCloseTo(expectedTotalInterest, 2)
    })

    it('should calculate total interest for equal principal', () => {
      const interest = calculateTotalInterest(100000, 4.2, 240, '等额本金')
      const monthlyRate = 4.2 / 12 / 100
      const expectedInterest = Math.round((monthlyRate * 100000 * (240 + 1) / 2) * 100) / 100
      expect(interest).toBeCloseTo(expectedInterest, 2)
    })

    it('should return 0 for pay-as-you-go method', () => {
      const interest = calculateTotalInterest(100000, 4.2, 240, '随借随还')
      expect(interest).toBe(0)
    })

    it('should return 0 when rate is 0', () => {
      const interest = calculateTotalInterest(100000, 0, 240, '等额本息')
      expect(interest).toBe(0)
    })
  })

  describe('Debt Pressure Metrics', () => {
    it('should calculate debt-to-income ratio', async () => {
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

      const incomes = await db.query(`SELECT SUM(amount) as total FROM income_expense_records WHERE type = '账户收入'`)
      const monthlyIncome = (incomes[0].total || 0) / 3

      const ratio = monthlyIncome > 0 ? (monthlyRepayment / monthlyIncome) * 100 : 0
      expect(ratio).toBeGreaterThanOrEqual(0)
    })
  })
})
