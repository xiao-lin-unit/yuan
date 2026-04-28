import { describe, it, expect, beforeEach } from 'vitest'
import dayjs from 'dayjs'
import { resetTestDatabase, seedTestData } from './utils/testDb'
import {
  addAccount, updateAccount, deleteAccount, getAccounts, getAccountById,
  createDebitTransaction, createCreditTransaction
} from '../src/services/account/accountService'

describe('Account Module', () => {
  let db: any

  beforeEach(async () => {
    db = await resetTestDatabase()
    await seedTestData(db)
  })

  describe('CRUD Operations', () => {
    it('should add a new cash account with initial balance', async () => {
      await addAccount({
        name: '测试现金',
        type: '现金',
        balance: 1000,
        is_liquid: true
      })

      const accounts = await getAccounts()
      const found = accounts.find((a: any) => a.name === '测试现金')!
      expect(found).toBeDefined()
      expect(found.balance).toBe(1000)
      expect(found.type).toBe('现金')
    })

    it('should add a credit card account with limit', async () => {
      await addAccount({
        name: '测试信用卡',
        type: '信用卡',
        balance: 0,
        used_limit: 500,
        total_limit: 5000,
        is_liquid: false
      })

      const accounts = await getAccounts()
      const found = accounts.find((a: any) => a.name === '测试信用卡')!
      expect(found).toBeDefined()
      expect(found.used_limit).toBe(500)
      expect(found.total_limit).toBe(5000)
    })

    it('should update account balance', async () => {
      await updateAccount('acc1', { balance: 8000 })
      const account = await getAccountById('acc1')
      expect(account?.balance).toBe(8000)
    })

    it('should delete an account', async () => {
      await deleteAccount('acc1')
      const account = await getAccountById('acc1')
      expect(account).toBeNull()
    })

    it('should retrieve all active accounts', async () => {
      const accounts = await getAccounts()
      expect(accounts.length).toBeGreaterThanOrEqual(3)
      expect(accounts.every((a: any) => a.status === '启用' || a.status == null)).toBe(true)
    })
  })

  describe('Account Transactions', () => {
    it('should create a debit transaction and reduce balance', async () => {
      const result = await createDebitTransaction('acc1', 1000, '测试支出', 'dt1', dayjs())
      expect(result.balanceAfter).toBe(4000)

      await db.executeTransaction(result.statements)
      const account = await getAccountById('acc1')
      expect(account?.balance).toBe(4000)
    })

    it('should create a credit transaction and increase balance', async () => {
      const result = await createCreditTransaction('acc1', 2000, '测试收入', 'ct1', dayjs())
      expect(result.balanceAfter).toBe(7000)

      await db.executeTransaction(result.statements)
      const account = await getAccountById('acc1')
      expect(account?.balance).toBe(7000)
    })

    it('should reject debit when balance is insufficient for non-credit account', async () => {
      await expect(createDebitTransaction('acc1', 10000, '超额支出', 'dt2', dayjs()))
        .rejects.toThrow()
    })
  })
})
