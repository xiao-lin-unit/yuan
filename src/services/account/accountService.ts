/**
 * Account Service
 * Handles account CRUD and balance operations
 */

import db from '../../database/index.js'
import type { Account, AccountTransaction, AccountInput, BalanceAdjustInput, TransferInput, RepayCreditCardInput } from '../../types/account/account.js'
import { getCurrentISOString, dateNow } from '../../utils/timezone'

/**
 * Add a new account
 * 同时生成一条入账记录
 */
export async function addAccount(accountData: AccountInput): Promise<void> {
  const id = dateNow().toString()
  const transactionId = (dateNow() + 1).toString()

  const statements = [
    // 1. 创建账户
    {
      statement: `INSERT INTO accounts (id, name, type, balance, used_limit, total_limit, is_liquid, remark) 
                   VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      values: [
        id,
        accountData.name,
        accountData.type,
        accountData.balance,
        accountData.used_limit || 0,
        accountData.total_limit || 0,
        accountData.is_liquid !== false ? 1 : 0,
        accountData.remark || ''
      ]
    }
  ]

  // 2. 非信用卡且余额大于0时，创建入账记录
  if (accountData.type !== '信用卡' && accountData.balance > 0) {
    statements.push({
      statement: `INSERT INTO account_transactions (id, account_id, type, amount, balance_after, description, transaction_time) 
                   VALUES (?, ?, ?, ?, ?, ?, ?)`,
      values: [
        transactionId,
        id,
        '收入',
        accountData.balance,
        accountData.balance,
        '账户初始入账',
        getCurrentISOString()
      ]
    })
  }

  // 3. 信用卡且已用额度大于0时，创建借款记录（出账）
  const usedLimit = accountData.used_limit || 0
  if (accountData.type === '信用卡' && usedLimit > 0) {
    statements.push({
      statement: `INSERT INTO account_transactions (id, account_id, type, amount, balance_after, description, transaction_time) 
                   VALUES (?, ?, ?, ?, ?, ?, ?)`,
      values: [
        transactionId,
        id,
        '支出',
        usedLimit,
        usedLimit,
        '信用卡初始借款',
        getCurrentISOString()
      ]
    })
  }

  await db.executeTransaction(statements)
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
 * 只返回状态为启用的账户
 */
export async function getAccounts(): Promise<Account[]> {
  return await db.query("SELECT * FROM accounts WHERE status IS NULL OR status = '启用' ORDER BY created_at DESC")
}

/**
 * Get account by ID
 */
export async function getAccountById(accountId: string): Promise<Account | null> {
  const result = await db.query('SELECT * FROM accounts WHERE id = ?', [accountId])
  return result.length > 0 ? result[0] : null
}

// ==================== 账户出账入账接口 ====================

/**
 * 出账（从账户扣款）
 * 返回SQL语句和参数，包括账户更新和交易记录
 * 
 * 规则：
 * 1. 非流动储蓄账户且非信用卡：不允许出账
 * 2. 流动储蓄账户：出账金额不能大于账户余额
 * 3. 信用卡：出账金额不能大于剩余可用额度
 * 
 * @param accountId 账户ID
 * @param amount 出账金额（必须为正数）
 * @param description 交易描述
 * @param transactionId 交易记录ID（可选，不传则自动生成）
 * @param transactionTime 交易时间（可选，不传则使用当前时间）
 * @returns 包含SQL语句数组和参数的对象，用于事务执行
 */
export async function createDebitTransaction(
  accountId: string, 
  amount: number, 
  description: string,
  transactionId?: string,
  transactionTime?: Date
): Promise<{ 
  statements: { statement: string; values: any[] }[]; 
  balanceAfter: number;
  transactionId: string;
}> {
  if (amount <= 0) {
    throw new Error('出账金额必须大于0')
  }

  const account = await getAccountById(accountId)
  if (!account) {
    throw new Error('账户不存在')
  }

  // 检查账户状态
  if (account.status === '停用') {
    throw new Error('账户已停用，无法出账')
  }

  // 规则1：非流动储蓄账户且非信用卡，不允许出账
  const isLiquid = account.is_liquid === 1 || account.is_liquid === true
  const isCreditCard = account.type === '信用卡'
  
  if (!isLiquid && !isCreditCard) {
    throw new Error(`账户类型"${account.type}"不允许出账，仅流动储蓄账户和信用卡支持出账`)
  }

  const txId = transactionId || dateNow().toString()
  const txTime = transactionTime || new Date(getCurrentISOString())
  let balanceAfter: number
  let accountUpdateStatement: { statement: string; values: any[] }

  if (isCreditCard) {
    // 规则3：信用卡，出账金额不能大于剩余可用额度
    const availableLimit = (account.total_limit || 0) - (account.used_limit || 0)
    if (amount > availableLimit) {
      throw new Error(`信用卡可用额度不足，可用额度：¥${availableLimit.toFixed(2)}，需要：¥${amount.toFixed(2)}`)
    }
    // 信用卡：增加已用额度（used_limit）
    balanceAfter = (account.used_limit || 0) + amount
    accountUpdateStatement = {
      statement: 'UPDATE accounts SET used_limit = used_limit + ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
      values: [amount, accountId]
    }
  } else {
    // 规则2：流动储蓄账户，出账金额不能大于账户余额
    if (amount > account.balance) {
      throw new Error(`账户余额不足，当前余额：¥${account.balance.toFixed(2)}，需要：¥${amount.toFixed(2)}`)
    }
    // 储蓄账户：减少余额
    balanceAfter = account.balance - amount
    accountUpdateStatement = {
      statement: 'UPDATE accounts SET balance = balance - ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
      values: [amount, accountId]
    }
  }

  // 创建交易记录
  const transactionStatement = {
    statement: `INSERT INTO account_transactions (id, account_id, type, amount, balance_after, description, transaction_time) 
                VALUES (?, ?, ?, ?, ?, ?, ?)`,
    values: [
      txId,
      accountId,
      '支出',
      amount,
      balanceAfter,
      description,
      txTime instanceof Date ? txTime.toISOString() : txTime
    ]
  }

  return {
    statements: [accountUpdateStatement, transactionStatement],
    balanceAfter,
    transactionId: txId
  }
}

/**
 * 入账（向账户加款）
 * 返回SQL语句和参数，包括账户更新和交易记录
 * 
 * @param accountId 账户ID
 * @param amount 入账金额（必须为正数）
 * @param description 交易描述
 * @param transactionId 交易记录ID（可选，不传则自动生成）
 * @param transactionTime 交易时间（可选，不传则使用当前时间）
 * @returns 包含SQL语句数组和参数的对象，用于事务执行
 */
export async function createCreditTransaction(
  accountId: string, 
  amount: number,
  description: string,
  transactionId?: string,
  transactionTime?: Date
): Promise<{ 
  statements: { statement: string; values: any[] }[]; 
  balanceAfter: number;
  transactionId: string;
}> {
  if (amount <= 0) {
    throw new Error('入账金额必须大于0')
  }

  const account = await getAccountById(accountId)
  if (!account) {
    throw new Error('账户不存在')
  }

  // 检查账户状态
  if (account.status === '停用') {
    throw new Error('账户已停用，无法入账')
  }

  const isCreditCard = account.type === '信用卡'
  const txId = transactionId || dateNow().toString()
  const txTime = transactionTime || new Date(getCurrentISOString())
  let balanceAfter: number
  let accountUpdateStatement: { statement: string; values: any[] }

  if (isCreditCard) {
    // 信用卡：减少已用额度（还款）
    // 确保还款金额不超过已用额度
    const repaymentAmount = Math.min(amount, account.used_limit || 0)
    balanceAfter = Math.max(0, (account.used_limit || 0) - amount)
    accountUpdateStatement = {
      statement: 'UPDATE accounts SET used_limit = used_limit - ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
      values: [repaymentAmount, accountId]
    }
  } else {
    // 储蓄账户：增加余额
    balanceAfter = account.balance + amount
    accountUpdateStatement = {
      statement: 'UPDATE accounts SET balance = balance + ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
      values: [amount, accountId]
    }
  }

  // 创建交易记录
  const transactionStatement = {
    statement: `INSERT INTO account_transactions (id, account_id, type, amount, balance_after, description, transaction_time) 
                VALUES (?, ?, ?, ?, ?, ?, ?)`,
    values: [
      txId,
      accountId,
      '收入',
      amount,
      balanceAfter,
      description,
      txTime instanceof Date ? txTime.toISOString() : txTime
    ]
  }

  return {
    statements: [accountUpdateStatement, transactionStatement],
    balanceAfter,
    transactionId: txId
  }
}

/**
 * Adjust account balance
 */
export async function adjustBalance(input: BalanceAdjustInput): Promise<void> {
  const account = await getAccountById(input.account_id)
  if (!account) {
    throw new Error('账户不存在')
  }

  const newBalance = account.balance + input.amount
  const transactionId = dateNow().toString()

  const statements = [
    // Update account balance
    {
      statement: 'UPDATE accounts SET balance = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
      values: [newBalance, input.account_id]
    },
    // Create account transaction record
    {
      statement: `INSERT INTO account_transactions (id, account_id, type, amount, balance_after, description, transaction_time) 
                  VALUES (?, ?, ?, ?, ?, ?, ?)`,
      values: [
        transactionId,
        input.account_id,
        input.amount >= 0 ? '收入' : '支出',
        Math.abs(input.amount),
        newBalance,
        input.remark || `${input.type}：余额调整`,
        getCurrentISOString()
      ]
    }
  ]

  await db.executeTransaction(statements)
}

/**
 * Transfer between accounts
 */
export async function transfer(input: TransferInput): Promise<void> {
  if (input.from_account_id === input.to_account_id) {
    throw new Error('转出账户和转入账户不能相同')
  }

  const fromAccount = await getAccountById(input.from_account_id)
  const toAccount = await getAccountById(input.to_account_id)

  if (!fromAccount) {
    throw new Error('转出账户不存在')
  }
  if (!toAccount) {
    throw new Error('转入账户不存在')
  }

  const transactionId = dateNow().toString()
  const transactionTime = new Date(getCurrentISOString())

  // 使用新的出账入账接口（现在已包含交易记录创建）
  const debitResult = await createDebitTransaction(
    input.from_account_id, 
    input.amount, 
    `转账至：${toAccount.name}`,
    transactionId + '_from',
    transactionTime
  )
  const creditResult = await createCreditTransaction(
    input.to_account_id, 
    input.amount,
    `转账来自：${fromAccount.name}`,
    transactionId + '_to',
    transactionTime
  )

  // 合并所有语句（出账和入账接口已包含交易记录）
  const statements = [
    ...debitResult.statements,
    ...creditResult.statements
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
 * 只返回状态为启用的账户
 */
export async function getNonCreditCardAccounts(): Promise<Account[]> {
  return await db.query("SELECT * FROM accounts WHERE type != ? AND (status IS NULL OR status = '启用') ORDER BY created_at DESC", ['信用卡'])
}

// ==================== 账户停用接口 ====================

/**
 * 停用普通账户
 * 校验：账户余额必须为0
 * @param accountId 账户ID
 */
export async function deactivateAccount(accountId: string): Promise<void> {
  const account = await getAccountById(accountId)
  if (!account) {
    throw new Error('账户不存在')
  }

  if (account.balance !== 0) {
    throw new Error(`账户余额不为0，当前余额：¥${account.balance.toFixed(2)}，无法停用`)
  }

  // 更新账户状态为停用
  await db.run(
    'UPDATE accounts SET status = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
    ['停用', accountId]
  )
}

/**
 * 停用信用卡
 * 校验：已用额度必须为0（即全部还完借款）
 * @param accountId 账户ID
 */
export async function deactivateCreditCard(accountId: string): Promise<void> {
  const account = await getAccountById(accountId)
  if (!account) {
    throw new Error('账户不存在')
  }

  if (account.type !== '信用卡') {
    throw new Error('该账户不是信用卡')
  }

  const usedLimit = account.used_limit || 0
  if (usedLimit > 0) {
    throw new Error(`信用卡仍有未还借款 ¥${usedLimit.toFixed(2)}，无法停用`)
  }

  // 更新账户状态为停用
  await db.run(
    'UPDATE accounts SET status = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
    ['停用', accountId]
  )
}

// ==================== 信用卡还款接口 ====================

/**
 * 信用卡还款
 * 从指定账户扣款，减少信用卡已用额度
 * @param input 还款输入参数
 */
export async function repayCreditCard(input: RepayCreditCardInput): Promise<void> {
  const { credit_card_id, from_account_id, amount, transaction_time, remark } = input

  if (amount <= 0) {
    throw new Error('还款金额必须大于0')
  }

  const creditCard = await getAccountById(credit_card_id)
  if (!creditCard) {
    throw new Error('信用卡不存在')
  }

  if (creditCard.type !== '信用卡') {
    throw new Error('该账户不是信用卡')
  }

  const fromAccount = await getAccountById(from_account_id)
  if (!fromAccount) {
    throw new Error('还款来源账户不存在')
  }

  // 检查信用卡已用额度
  const usedLimit = creditCard.used_limit || 0
  if (amount > usedLimit) {
    throw new Error(`还款金额不能超过已用额度 ¥${usedLimit.toFixed(2)}`)
  }

  // 检查来源账户余额
  if (fromAccount.balance < amount) {
    throw new Error(`还款来源账户余额不足，当前余额：¥${fromAccount.balance.toFixed(2)}`)
  }

  const transactionId = dateNow().toString()

  const statements = [
    // 1. 减少信用卡已用额度
    {
      statement: 'UPDATE accounts SET used_limit = used_limit - ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
      values: [amount, credit_card_id]
    },
    // 2. 减少还款来源账户余额
    {
      statement: 'UPDATE accounts SET balance = balance - ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
      values: [amount, from_account_id]
    },
    // 3. 创建信用卡还款记录（入账记录）
    {
      statement: `INSERT INTO account_transactions (id, account_id, type, amount, balance_after, description, transaction_time) 
                  VALUES (?, ?, ?, ?, ?, ?, ?)`,
      values: [
        transactionId + '_cc',
        credit_card_id,
        '收入',
        amount,
        Math.max(0, usedLimit - amount),
        `还款来自：${fromAccount.name}${remark ? ' - ' + remark : ''}`,
        transaction_time instanceof Date ? transaction_time.toISOString() : transaction_time
      ]
    },
    // 4. 创建来源账户支出记录
    {
      statement: `INSERT INTO account_transactions (id, account_id, type, amount, balance_after, description, transaction_time) 
                  VALUES (?, ?, ?, ?, ?, ?, ?)`,
      values: [
        transactionId + '_from',
        from_account_id,
        '支出',
        amount,
        fromAccount.balance - amount,
        `还款至：${creditCard.name}${remark ? ' - ' + remark : ''}`,
        transaction_time instanceof Date ? transaction_time.toISOString() : transaction_time
      ]
    }
  ]

  await db.executeTransaction(statements)
}