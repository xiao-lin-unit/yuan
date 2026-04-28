import { vi } from 'vitest'
import { dbManager } from '../../src/database/index.js'

let localStorageMock: Record<string, string> = {}

export function setupLocalStorageMock() {
  localStorageMock = {}
  Object.defineProperty(global, 'localStorage', {
    value: {
      getItem: (key: string) => localStorageMock[key] || null,
      setItem: (key: string, value: string) => { localStorageMock[key] = value },
      removeItem: (key: string) => { delete localStorageMock[key] },
      clear: () => { localStorageMock = {} },
    },
    writable: true,
  })
}

export async function resetTestDatabase() {
  // Close existing connection
  if (dbManager.db) {
    try {
      dbManager.db.close()
    } catch (e) {
      // ignore
    }
  }

  // Reset dbManager state
  dbManager.db = null
  dbManager.SQL = null
  dbManager.initialized = false
  dbManager.connecting = false
  dbManager.isNative = false
  dbManager.cache.clear()

  // Clear localStorage mock
  localStorageMock = {}

  // Re-initialize
  const db = (await import('../../src/database/index.js')).default
  await db.connect()
  return db
}

export async function seedTestData(db: any) {
  // Insert test categories
  await db.run(`INSERT INTO categories (id, name, type, icon, iconText) VALUES (?, ?, ?, ?, ?)`,
    ['cat1', '餐饮', 'expense', 'food', '🍽'])
  await db.run(`INSERT INTO categories (id, name, type, icon, iconText) VALUES (?, ?, ?, ?, ?)`,
    ['cat2', '工资', 'income', 'salary', '💰'])

  // Insert test accounts
  await db.run(`INSERT INTO accounts (id, name, type, balance, used_limit, total_limit, is_liquid, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
    ['acc1', '现金', '现金', 5000, 0, 0, 1, '启用'])
  await db.run(`INSERT INTO accounts (id, name, type, balance, used_limit, total_limit, is_liquid, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
    ['acc2', '招商信用卡', '信用卡', 0, 2000, 10000, 0, '启用'])
  await db.run(`INSERT INTO accounts (id, name, type, balance, used_limit, total_limit, is_liquid, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
    ['acc3', '工资卡', '储蓄卡', 20000, 0, 0, 1, '启用'])

  // Insert test assets
  await db.run(`INSERT INTO assets (id, type, name, amount, account_id, annual_yield_rate, ended) VALUES (?, ?, ?, ?, ?, ?, ?)`,
    ['asset1', '储蓄', '定期存款', 10000, 'acc3', 2.5, 0])

  // Insert test stocks
  await db.run(`INSERT INTO stocks (id, name, code, quantity, current_price, cost_price, account_id, ended) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
    ['stock1', '测试股票', '000001', 100, 50, 45, 'acc3', 0])

  // Insert test funds
  await db.run(`INSERT INTO funds (id, name, code, shares, current_nav, cost_nav, account_id, ended) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
    ['fund1', '测试基金', '110022', 500, 2.5, 2.0, 'acc3', 0])

  // Insert test liability
  await db.run(
    `INSERT INTO liabilities (id, name, type, principal, remaining_principal, remaining_total_interest, is_interest, interest_rate, start_date, repayment_method, repayment_day, period, account_id, remark, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    ['lia1', '房贷', '房贷', 300000, 300000, 0, 1, 4.2, '2024-01-01', '等额本息', 15, 240, 'acc3', '', '未结清']
  )

  // Insert test transactions (income/expense)
  const now = new Date()
  const dateStr = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`
  await db.run(`INSERT INTO transactions (id, type, amount, account_id, balance_after, created_at) VALUES (?, ?, ?, ?, ?, ?)`,
    ['tx1', '账户收入', 8000, 'acc3', 28000, dateStr])
  await db.run(`INSERT INTO transactions (id, type, amount, account_id, balance_after, created_at) VALUES (?, ?, ?, ?, ?, ?)`,
    ['tx2', '账户支出', 2000, 'acc1', 3000, dateStr])
  await db.run(`INSERT INTO transactions (id, type, amount, account_id, balance_after, created_at) VALUES (?, ?, ?, ?, ?, ?)`,
    ['tx3', '账户支出', 1500, 'acc1', 1500, dateStr])
}
