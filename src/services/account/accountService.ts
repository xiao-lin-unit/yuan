/**
 * Account Service
 * Handles account CRUD and balance operations
 */

import db from '../../database/index.js'
import type { Account, AccountTransaction, AccountInput, BalanceAdjustInput, TransferInput } from '../../types/account/account.js'

/**
 * Add a new account
 */
export async function addAccount(accountData: AccountInput): Promise<void> {
  const id = Date.now().toString()
  await db.run(
    `INSERT INTO accounts (id, name, type, balance, used_limit, total_limit, is_liquid, remark) 
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      id,
      accountData.name,
      accountData.type,
      accountData.balance,
      accountData.usedLimit || 0,
      accountData.totalLimit || 0,
      accountData.isLiquid !== false ? 1 : 0,
      accountData.remark || ''
    ]
  )
}

/**
 * Update account
 */
export async function updateAccount(accountId: string, data: Partial<Account>): Promise<void> {
  const fields: string[] = []
  const values: any[] = []

  if (data.name !== undefined) {
    fields.push('name = ?')
    values.push(data.name)
  }
  if (data.type !== undefined) {
    fields.push('type = ?')
    values.push(data.type)
  }
  if (data.balance !== undefined) {
    fields.push('balance = ?')
    values.push(data.balance)
  }
  if (data.used_limit !== undefined) {
    fields.push('used_limit = ?')
    values.push(data.used_limit)
  }
  if (data.total_limit !== undefined) {
    fields.push('total_limit = ?')
    values.push(data.total_limit)
  }
  if (data.is_liquid !== undefined) {
    fields.push('is_liquid = ?')
    values.push(data.is_liquid === true || data.is_liquid === 1 ? 1 : 0)
  }
  if (data.remark !== undefined) {
    fields.push('remark = ?')
    values.push(data.remark)
  }

  if (fields.length === 0) return

  fields.push('updated_at = CURRENT_TIMESTAMP')
  values.push(accountId)

  await db.run(
    `UPDATE accounts SET ${fields.join(', ')} WHERE id = ?`,
    values
  )
}

/**
 * Delete account
 */
export async function deleteAccount(accountId: string): Promise<void> {
  await db.run('DELETE FROM accounts WHERE id = ?', [accountId])
}

/**
 * Get all accounts
 */
export async function getAccounts(): Promise<Account[]> {
  return await db.query('SELECT * FROM accounts ORDER BY created_at DESC')
}

/**
 * Get account by ID
 */
export async function getAccountById(accountId: string): Promise<Account | null> {
  const result = await db.query('SELECT * FROM accounts WHERE id = ?', [accountId])
  return result.length > 0 ? result[0] : null
}

/**
 * Adjust account balance
 */
export async function adjustBalance(input: BalanceAdjustInput): Promise<void> {
  const account = await getAccountById(input.accountId)
  if (!account) {
    throw new Error('账户不存在')
  }

  const newBalance = account.balance + input.amount
  const transactionId = Date.now().toString()

  const statements = [
    // Update account balance
    {
      statement: 'UPDATE accounts SET balance = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
      values: [newBalance, input.accountId]
    },
    // Create account transaction record
    {
      statement: `INSERT INTO account_transactions (id, account_id, type, amount, balance_after, description, transaction_time) 
                  VALUES (?, ?, ?, ?, ?, ?, ?)`,
      values: [
        transactionId,
        input.accountId,
        input.amount >= 0 ? '收入' : '支出',
        Math.abs(input.amount),
        newBalance,
        input.remark || `${input.type}：余额调整`,
        new Date()
      ]
    }
  ]

  await db.executeTransaction(statements)
}

/**
 * Transfer between accounts
 */
export async function transfer(input: TransferInput): Promise<void> {
  if (input.fromAccountId === input.toAccountId) {
    throw new Error('转出账户和转入账户不能相同')
  }

  const fromAccount = await getAccountById(input.fromAccountId)
  const toAccount = await getAccountById(input.toAccountId)

  if (!fromAccount) {
    throw new Error('转出账户不存在')
  }
  if (!toAccount) {
    throw new Error('转入账户不存在')
  }
  if (fromAccount.balance < input.amount) {
    throw new Error('转出账户余额不足')
  }

  const fromNewBalance = fromAccount.balance - input.amount
  const toNewBalance = toAccount.balance + input.amount
  const transactionId = Date.now().toString()

  const statements = [
    // Deduct from source account
    {
      statement: 'UPDATE accounts SET balance = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
      values: [fromNewBalance, input.fromAccountId]
    },
    // Add to destination account
    {
      statement: 'UPDATE accounts SET balance = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
      values: [toNewBalance, input.toAccountId]
    },
    // Create transaction record for source account
    {
      statement: `INSERT INTO account_transactions (id, account_id, type, amount, balance_after, description, transaction_time) 
                  VALUES (?, ?, ?, ?, ?, ?, ?)`,
      values: [
        transactionId + '_from',
        input.fromAccountId,
        '支出',
        input.amount,
        fromNewBalance,
        `转账至：${toAccount.name}${input.remark ? ' - ' + input.remark : ''}`,
        new Date()
      ]
    },
    // Create transaction record for destination account
    {
      statement: `INSERT INTO account_transactions (id, account_id, type, amount, balance_after, description, transaction_time) 
                  VALUES (?, ?, ?, ?, ?, ?, ?)`,
      values: [
        transactionId + '_to',
        input.toAccountId,
        '收入',
        input.amount,
        toNewBalance,
        `转账来自：${fromAccount.name}${input.remark ? ' - ' + input.remark : ''}`,
        new Date()
      ]
    }
  ]

  await db.executeTransaction(statements)
}

/**
 * Get account transactions
 */
export async function getAccountTransactions(accountId: string): Promise<AccountTransaction[]> {
  return await db.query(
    'SELECT * FROM account_transactions WHERE account_id = ? ORDER BY transaction_time DESC',
    [accountId]
  )
}

/**
 * Get accounts excluding credit cards
 */
export async function getNonCreditCardAccounts(): Promise<Account[]> {
  return await db.query('SELECT * FROM accounts WHERE type != ? ORDER BY created_at DESC', ['信用卡'])
}
