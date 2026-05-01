import { describe, it, expect, beforeEach } from 'vitest'
import { resetTestDatabase, seedTestData } from './utils/testDb'
import db from '../src/database/index.js'
import { calculatePerAssetIncome } from '../src/services/asset/assetService'

describe('Asset Module', () => {
  beforeEach(async () => {
    await resetTestDatabase()
    await seedTestData(db)
  })

  describe('Asset CRUD', () => {
    it('should retrieve assets with account info', async () => {
      const assets = await db.query(`SELECT * FROM assets WHERE status != '结束'`)
      expect(assets.length).toBe(1)
      expect(assets[0].name).toBe('定期存款')
      expect(assets[0].amount).toBe(10000)
    })

    it('should retrieve stocks with market value', async () => {
      const stocks = await db.query(`SELECT * FROM stocks WHERE status != '结束'`)
      expect(stocks.length).toBe(1)
      expect(stocks[0].name).toBe('测试股票')
      const marketValue = (stocks[0].current_price || 0) * (stocks[0].quantity || 0)
      expect(marketValue).toBe(5000)
    })

    it('should retrieve funds with nav value', async () => {
      const funds = await db.query(`SELECT * FROM funds WHERE status != '结束'`)
      expect(funds.length).toBe(1)
      expect(funds[0].name).toBe('测试基金')
      const marketValue = (funds[0].current_nav || 0) * (funds[0].shares || 0)
      expect(marketValue).toBe(1250)
    })

    it('should calculate total liquid balance from accounts', async () => {
      const accounts = await db.query(`SELECT * FROM accounts WHERE type != '信用卡' AND status = '启用'`)
      const total = accounts.reduce((s: number, a: any) => s + (a.balance || 0), 0)
      expect(total).toBe(25000)
    })
  })

  describe('Asset Income Calculation', () => {
    it('should calculate daily income by annual rate', () => {
      const asset = {
        amount: 10000,
        annual_yield_rate: 0.0365,
        period: '日',
        calculation_type: '按年收益率计算'
      } as any
      const income = calculatePerAssetIncome(asset)
      expect(income).toBeCloseTo(1, 2)
    })

    it('should calculate monthly income by annual rate', () => {
      const asset = {
        amount: 12000,
        annual_yield_rate: 0.12,
        period: '月',
        calculation_type: '按年收益率计算'
      } as any
      const income = calculatePerAssetIncome(asset)
      expect(income).toBeCloseTo(120, 2)
    })

    it('should return 0 for none calculation type', () => {
      const asset = {
        amount: 10000,
        annual_yield_rate: 5,
        period: '月',
        calculation_type: '无'
      } as any
      const income = calculatePerAssetIncome(asset)
      expect(income).toBe(0)
    })

    it('should return fixed amount for fixed calculation', () => {
      const asset = {
        amount: 10000,
        income_amount: 500,
        period: '月',
        calculation_type: '按金额计算'
      } as any
      const income = calculatePerAssetIncome(asset)
      expect(income).toBe(500)
    })
  })
})
