import { describe, it, expect, beforeEach } from 'vitest'
import { resetTestDatabase, seedTestData } from './utils/testDb'
import db from '../src/database/index.js'
import {
  computeSandbox,
  saveSandboxSimulation,
  getSandboxHistoryList,
  getSandboxHistoryById,
  getSandboxResultByHistoryId,
  softDeleteSandboxHistory,
  getSceneByType,
  SCENES
} from '../src/services/sandbox/sandboxService'

describe('Sandbox Simulation Module', () => {
  beforeEach(async () => {
    await resetTestDatabase()
    await seedTestData(db)
  })

  describe('Scene Definitions', () => {
    it('should have exactly 14 preset scenes', () => {
      expect(SCENES.length).toBe(14)
    })

    it('should return scene by type', () => {
      const scene = getSceneByType(1)
      expect(scene).toBeDefined()
      expect(scene?.name).toBe('失业维持时长推演')
    })

    it('should return undefined for invalid scene type', () => {
      const scene = getSceneByType(99)
      expect(scene).toBeUndefined()
    })
  })

  describe('Simulation Engine', () => {
    it('should compute unemployment survival scenario', async () => {
      const result = await computeSandbox(1, { retain_passive_income: true, suspend_expense: false })
      expect(result.history.scene_type).toBe(1)
      expect(result.history.scene_name).toBe('失业维持时长推演')
      expect(result.result.survival_months).toBeGreaterThan(0)
      expect(result.result.net_assets).toBeDefined()
      expect(result.result.cash_flow_monthly).toBeDefined()
      expect(result.result.chart_x).toBeDefined()
      expect(result.result.chart_net_assets).toBeDefined()
      expect(result.result.conclusion).toContain('失业')
    })

    it('should compute debt rate increase scenario', async () => {
      const result = await computeSandbox(2, { rate_increase: 1.5 })
      expect(result.history.scene_type).toBe(2)
      expect(result.result.monthly_payment_change).toBeGreaterThan(0)
      expect(result.result.total_interest_change).toBeGreaterThan(0)
      expect(result.result.conclusion).toContain('利率')
    })

    it('should compute stock decline scenario', async () => {
      const result = await computeSandbox(3, { decline_rate: 20, hold_quantity: true })
      expect(result.history.scene_type).toBe(3)
      expect(result.result.net_assets).toBeLessThan(0)
      expect(result.result.cash_flow_change).toContain('无变化')
    })

    it('should compute monthly deposit scenario', async () => {
      const result = await computeSandbox(4, { monthly_deposit: 1000, simulate_period: 12 })
      expect(result.history.scene_type).toBe(4)
      expect(result.result.net_assets).toBeDefined()
      expect(JSON.parse(result.result.chart_x).length).toBe(12)
    })

    it('should compute early repayment scenario', async () => {
      const result = await computeSandbox(5, { repay_amount: 30000 })
      expect(result.history.scene_type).toBe(5)
      expect(result.result.interest_save).toBeGreaterThan(0)
      expect(result.result.monthly_payment_change).toBeLessThan(0)
    })

    it('should compute income increase scenario', async () => {
      const result = await computeSandbox(6, { rise_rate: 10, simulate_period: 12 })
      expect(result.history.scene_type).toBe(6)
      expect(result.result.cash_flow_monthly).toBeDefined()
    })

    it('should compute large expense scenario', async () => {
      const result = await computeSandbox(7, { expense_amount: 10000, fund_source: 'current_assets' })
      expect(result.history.scene_type).toBe(7)
      expect(result.result.net_assets).toBeLessThan(0)
    })

    it('should compute income decline scenario', async () => {
      const result = await computeSandbox(8, { decline_rate: 20, simulate_period: 12 })
      expect(result.history.scene_type).toBe(8)
      expect(result.result.cash_flow_monthly).toBeLessThan(0)
    })

    it('should compute investment liquidation scenario', async () => {
      const result = await computeSandbox(9, { sell_ratio: 50, fund_use: 'debt_repay' })
      expect(result.history.scene_type).toBe(9)
      expect(result.result.monthly_payment_change).toBeLessThanOrEqual(0)
    })

    it('should compute new debt scenario', async () => {
      const result = await computeSandbox(10, { debt_amount: 50000, annual_rate: 8, repay_period: 24 })
      expect(result.history.scene_type).toBe(10)
      expect(result.result.monthly_payment_change).toBeGreaterThan(0)
    })

    it('should compute emergency fund shortage scenario', async () => {
      const result = await computeSandbox(11, { target_months: 6, supplement_period: 12 })
      expect(result.history.scene_type).toBe(11)
    })

    it('should compute investment loss scenario', async () => {
      const result = await computeSandbox(12, { loss_rate: 15, hold_period: 6 })
      expect(result.history.scene_type).toBe(12)
      expect(result.result.net_assets).toBeLessThan(0)
    })

    it('should compute fixed expense increase scenario', async () => {
      const result = await computeSandbox(13, { increase_amount: 500, increase_period: 12 })
      expect(result.history.scene_type).toBe(13)
    })

    it('should compute passive income increase scenario', async () => {
      const result = await computeSandbox(14, { increase_amount: 500, stable_period: 24 })
      expect(result.history.scene_type).toBe(14)
      expect(result.result.cash_flow_monthly).toBeGreaterThan(0)
    })
  })

  describe('Persistence', () => {
    it('should save and retrieve simulation history', async () => {
      const historyId = await saveSandboxSimulation(1, { retain_passive_income: true, suspend_expense: false })
      expect(historyId).toBeTruthy()

      const history = await getSandboxHistoryById(historyId as number)
      expect(history).not.toBeNull()
      expect(history?.scene_type).toBe(1)

      const result = await getSandboxResultByHistoryId(historyId as number)
      expect(result).not.toBeNull()
      expect(result?.history_id).toBe(historyId)
    })

    it('should list all simulation histories', async () => {
      await saveSandboxSimulation(1, { retain_passive_income: true })
      await saveSandboxSimulation(2, { rate_increase: 1 })

      const histories = await getSandboxHistoryList()
      expect(histories.length).toBe(2)
    })

    it('should soft delete simulation history', async () => {
      const historyId = await saveSandboxSimulation(1, { retain_passive_income: true })
      await softDeleteSandboxHistory(historyId as number)

      const history = await getSandboxHistoryById(historyId as number)
      expect(history).toBeNull()

      const histories = await getSandboxHistoryList()
      expect(histories.length).toBe(0)
    })
  })
})
