/**
 * Liability Service
 * Handles liability and repayment operations
 */

import dayjs from 'dayjs'
import db from '../../database/index.js'
import { getCurrentDate, getDate } from '../../utils/timezone.js'
import type { Liability, Repayment, PendingRepayment, LiabilityInput, RepaymentInput } from '../../types/liability/liability.js'
import { createDebitTransaction, createCreditTransaction, getAccountById } from '../../services/account/accountService'

/**
 * Calculate total interest based on repayment method
 */
export function calculateTotalInterest(
  principal: number,
  annualRate: number,
  periods: number,
  repaymentMethod: string
): number {
  if (!annualRate || annualRate <= 0 || !periods || periods <= 0) return 0

  const monthlyRate = annualRate / 100 / 12

  switch (repaymentMethod) {
    case '等额本息': {
      const monthlyPayment = principal * monthlyRate * Math.pow(1 + monthlyRate, periods) /
        (Math.pow(1 + monthlyRate, periods) - 1)
      return Math.round((monthlyPayment * periods - principal) * 100) / 100
    }
    case '等额本金': {
      return Math.round((monthlyRate * principal * (periods + 1) / 2) * 100) / 100
    }
    case '随借随还':
    default:
      return 0
  }
}

/**
 * Generate a pending repayment record for a specific period
 */
export function generatePendingRepayment(
  liability: Liability,
  periodNumber: number
): { id: string; liability_id: string; period_number: number; due_date: string; principal_amount: number; interest_amount: number; total_amount: number } {
  const monthlyRate = liability.interest_rate / 100 / 12
  let principalAmount = 0
  let interestAmount = 0
  let totalAmount = 0

  const totalPeriods = liability.period || 1

  switch (liability.repayment_method) {
    case '等额本息': {
      const remainingPeriods = totalPeriods - periodNumber + 1
      if (remainingPeriods > 0) {
        const monthlyPayment = liability.remaining_principal * monthlyRate * Math.pow(1 + monthlyRate, remainingPeriods) /
          (Math.pow(1 + monthlyRate, remainingPeriods) - 1)
        interestAmount = liability.remaining_principal * monthlyRate
        principalAmount = monthlyPayment - interestAmount
        totalAmount = monthlyPayment
      }
      break
    }
    case '等额本金': {
      principalAmount = liability.principal / totalPeriods
      interestAmount = liability.remaining_principal * monthlyRate
      totalAmount = principalAmount + interestAmount
      break
    }
    case '随借随还':
    default: {
      principalAmount = 0
      interestAmount = 0
      totalAmount = 0
    }
  }

  // Due date: start_date + periodNumber months
  let dueDate = getDate(liability.start_date).add(periodNumber, 'month')
  if (liability.repayment_day && liability.repayment_day >= 1 && liability.repayment_day <= 31) {
    dueDate = dueDate.date(Math.min(liability.repayment_day, dueDate.daysInMonth()))
  }

  return {
    id: getCurrentDate().valueOf().toString(),
    liability_id: liability.id,
    period_number: periodNumber,
    due_date: dueDate.format('YYYY-MM-DD'),
    principal_amount: Math.round(principalAmount * 100) / 100,
    interest_amount: Math.round(interestAmount * 100) / 100,
    total_amount: Math.round(totalAmount * 100) / 100
  }
}

/**
 * Add a new liability
 * Executes liability insert and first pending repayment generation in a transaction
 */
export async function addLiability(liabilityData: LiabilityInput): Promise<void> {
  const id = getCurrentDate().valueOf().toString()

  // Calculate total interest
  const totalInterest = liabilityData.is_interest && liabilityData.period
    ? calculateTotalInterest(
        liabilityData.principal,
        liabilityData.interest_rate,
        liabilityData.period,
        liabilityData.repayment_method
      )
    : 0

  // Build liability insert statement
  const statements: { statement: string; values: any[] }[] = [
    {
      statement: `INSERT INTO liabilities (id, name, type, principal, remaining_principal, remaining_total_interest, is_interest, interest_rate,
             start_date, repayment_method, repayment_day, period, account_id, remark, status)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      values: [
        id,
        liabilityData.name,
        liabilityData.type,
        liabilityData.principal,
        liabilityData.principal,
        totalInterest,
        liabilityData.is_interest ? 1 : 0,
        liabilityData.interest_rate,
        liabilityData.start_date,
        liabilityData.repayment_method,
        liabilityData.repayment_day || null,
        liabilityData.period || null,
        liabilityData.account_id,
        liabilityData.remark || '',
        '未结清'
      ]
    }
  ]

  // Generate first pending repayment statement (if not 随借随还 and has periods)
  if (liabilityData.repayment_method !== '随借随还' && liabilityData.period && liabilityData.period > 0) {
    const liability: Liability = {
      id,
      name: liabilityData.name,
      type: liabilityData.type,
      principal: liabilityData.principal,
      remaining_principal: liabilityData.principal,
      remaining_total_interest: totalInterest,
      is_interest: liabilityData.is_interest,
      interest_rate: liabilityData.interest_rate,
      start_date: liabilityData.start_date,
      repayment_method: liabilityData.repayment_method,
      repayment_day: liabilityData.repayment_day,
      period: liabilityData.period,
      account_id: liabilityData.account_id,
      remark: liabilityData.remark,
      status: '未结清'
    }

    const pendingStmt = generateNextPendingRepaymentStatement(liability, 1)
    if (pendingStmt.values[6] > 0) { // total_amount > 0
      statements.push(pendingStmt)
    }
  }

  await db.executeTransaction(statements)
}

/**
 * Update liability
 */
export async function updateLiability(liabilityId: string, data: Partial<Liability>): Promise<void> {
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
  if (data.principal !== undefined) {
    fields.push('principal = ?')
    values.push(data.principal)
  }
  if (data.remaining_principal !== undefined) {
    fields.push('remaining_principal = ?')
    values.push(data.remaining_principal)
  }
  if (data.remaining_total_interest !== undefined) {
    fields.push('remaining_total_interest = ?')
    values.push(data.remaining_total_interest)
  }
  if (data.is_interest !== undefined) {
    fields.push('is_interest = ?')
    values.push(data.is_interest ? 1 : 0)
  }
  if (data.interest_rate !== undefined) {
    fields.push('interest_rate = ?')
    values.push(data.interest_rate)
  }
  if (data.repayment_method !== undefined) {
    fields.push('repayment_method = ?')
    values.push(data.repayment_method)
  }
  if (data.repayment_day !== undefined) {
    fields.push('repayment_day = ?')
    values.push(data.repayment_day)
  }
  if (data.period !== undefined) {
    fields.push('period = ?')
    values.push(data.period)
  }
  if (data.account_id !== undefined) {
    fields.push('account_id = ?')
    values.push(data.account_id)
  }
  if (data.remark !== undefined) {
    fields.push('remark = ?')
    values.push(data.remark)
  }
  if (data.status !== undefined) {
    fields.push('status = ?')
    values.push(data.status)
  }

  if (fields.length === 0) return

  fields.push('updated_at = CURRENT_TIMESTAMP')
  values.push(liabilityId)

  await db.run(
    `UPDATE liabilities SET ${fields.join(', ')} WHERE id = ?`,
    values
  )
}

/**
 * Delete liability
 */
export async function deleteLiability(liabilityId: string): Promise<void> {
  // Delete related records first
  const statements: { statement: string; values: any[] }[] = [
    { statement: 'DELETE FROM pending_repayments WHERE liability_id = ?', values: [liabilityId] },
    { statement: 'DELETE FROM repayments WHERE liability_id = ?', values: [liabilityId] },
    { statement: 'DELETE FROM liabilities WHERE id = ?', values: [liabilityId] }
  ]
  await db.executeTransaction(statements)
}

/**
 * Get all liabilities
 */
export async function getLiabilities(): Promise<Liability[]> {
  return await db.query('SELECT * FROM liabilities ORDER BY created_at DESC')
}

/**
 * Get liability by ID
 */
export async function getLiabilityById(liabilityId: string): Promise<Liability | null> {
  const result = await db.query('SELECT * FROM liabilities WHERE id = ?', [liabilityId])
  return result.length > 0 ? result[0] : null
}

/**
 * Get pending repayments for a liability
 */
export async function getPendingRepayments(liabilityId: string): Promise<PendingRepayment[]> {
  return await db.query(
    'SELECT * FROM pending_repayments WHERE liability_id = ? ORDER BY period_number ASC',
    [liabilityId]
  )
}

/**
 * Get earliest pending repayment for a liability
 */
export async function getEarliestPendingRepayment(liabilityId: string): Promise<PendingRepayment | null> {
  const result = await db.query(
    'SELECT * FROM pending_repayments WHERE liability_id = ? AND status = ? ORDER BY period_number ASC LIMIT 1',
    [liabilityId, '未还']
  )
  return result.length > 0 ? result[0] : null
}

/**
 * Get completed repayment periods count
 */
export async function getCompletedPeriods(liabilityId: string): Promise<number> {
  const result = await db.query(
    'SELECT COUNT(*) as count FROM pending_repayments WHERE liability_id = ? AND status = ?',
    [liabilityId, '已还']
  )
  return result.length > 0 ? result[0].count : 0
}

/**
 * Generate SQL statement for inserting next pending repayment
 * Returns a statement object for batch/transaction execution
 */
export function generateNextPendingRepaymentStatement(
  liability: Liability,
  periodNumber: number
): { statement: string; values: any[] } {
  const pending = generatePendingRepayment(liability, periodNumber)
  return {
    statement: `INSERT INTO pending_repayments (id, liability_id, period_number, due_date, principal_amount, interest_amount, total_amount, status)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
    values: [
      pending.id,
      pending.liability_id,
      pending.period_number,
      pending.due_date,
      pending.principal_amount,
      pending.interest_amount,
      pending.total_amount,
      '未还'
    ]
  }
}

/**
 * Make a repayment
 * Normal repayment: amount must exactly match pending total; splits into principal + interest
 * Early repayment: deducts from principal, marks pending as void, recalculates interest
 */
export async function makeRepayment(input: RepaymentInput): Promise<void> {
  const liability = await getLiabilityById(input.liabilityId)
  if (!liability) {
    throw new Error('负债不存在')
  }

  if (liability.status === '已结清') {
    throw new Error('该负债已结清')
  }

  const repaymentId = getCurrentDate().valueOf().toString()
  let principalAmount = 0
  let interestAmount = 0
  let periodNumber: number | null = null
  let statements: {}[] = []
  if (input.type === '正常还款') {
    const pending = await getEarliestPendingRepayment(input.liabilityId)
    if (!pending) {
      throw new Error('没有待还记录，无法执行正常还款')
    }

    // Exact amount check
    if (input.amount !== pending.total_amount) {
      throw new Error(`还款金额必须等于本期应还金额 ¥${pending.total_amount.toFixed(2)}`)
    }

    periodNumber = pending.period_number
    principalAmount = pending.principal_amount
    interestAmount = pending.interest_amount

    const newRemainingPrincipal = liability.remaining_principal - pending.principal_amount
    const newRemainingTotalInterest = Math.max(0, liability.remaining_total_interest - pending.interest_amount)
    const isSettled = newRemainingPrincipal <= 0
    const newStatus = isSettled ? '已结清' : '未结清'

    if (newRemainingPrincipal < 0) {
      throw new Error('还款后剩余本金不能为负数')
    }

    statements.push({
      statement: `UPDATE pending_repayments SET status = '已还', paid_date = ? WHERE id = ?`,
      values: [getCurrentDate().format('YYYY-MM-DD'), pending.id]
    })
    statements.push({statement: `UPDATE liabilities SET remaining_principal = ?, remaining_total_interest = ?, status = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?`,
      values: [newRemainingPrincipal, newRemainingTotalInterest, newStatus, input.liabilityId]
    })

    if (!isSettled) {
      const updatedLiability = { ...liability, remaining_principal: newRemainingPrincipal, remaining_total_interest: newRemainingTotalInterest }
        const nextPending = generatePendingRepayment(updatedLiability, pending.period_number + 1)
        if (nextPending.total_amount > 0) {
            statements.push({
              statement: `INSERT INTO pending_repayments (id, liability_id, period_number, due_date, principal_amount, interest_amount, total_amount, status)
                  VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
              values: [
                    nextPending.id,
                    nextPending.liability_id,
                    nextPending.period_number,
                    nextPending.due_date,
                    nextPending.principal_amount,
                    nextPending.interest_amount,
                    nextPending.total_amount,
                    '未还'
                  ]
          })
        }
    }

    statements.push({
      statement: `INSERT INTO repayments (id, liability_id, period_number, amount, principal_amount, interest_amount, type, remark, repayment_time)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      values: [
          repaymentId,
          input.liabilityId,
          periodNumber,
          input.amount,
          principalAmount,
          interestAmount,
          input.type,
          input.remark || '',
          getCurrentDate().toISOString()
        ]
    })

  } else {
    // 提前还款
    const newRemainingPrincipal = liability.remaining_principal - input.amount
    if (newRemainingPrincipal < 0) {
      throw new Error('还款金额不能超过剩余本金')
    }
    const isSettled = newRemainingPrincipal === 0
    const newStatus = isSettled ? '已结清' : '未结清'

    principalAmount = input.amount
    interestAmount = 0

    // Recalculate remaining interest
    let newTotalInterest = 0
    if (!isSettled && liability.is_interest && liability.period) {
      const completedPeriods = await getCompletedPeriods(input.liabilityId)
      const remainingPeriods = liability.period - completedPeriods
      if (remainingPeriods > 0) {
        newTotalInterest = calculateTotalInterest(newRemainingPrincipal, liability.interest_rate, remainingPeriods, liability.repayment_method)
      }
    }

    statements.push({
      statement: `UPDATE pending_repayments SET status = '作废' WHERE liability_id = ? AND status = '未还'`,
      values: [input.liabilityId]
    })
    statements.push({
      statement: `UPDATE liabilities SET remaining_principal = ?, remaining_total_interest = ?, status = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?`,
      values: [newRemainingPrincipal, newTotalInterest, newStatus, input.liabilityId]
    })
    if (!isSettled && liability.repayment_method !== '随借随还' && liability.period) {
        const completedPeriods = await getCompletedPeriods(input.liabilityId)
        const nextPeriod = completedPeriods + 1
        const updatedLiability = { ...liability, remaining_principal: newRemainingPrincipal, remaining_total_interest: newTotalInterest }
        const nextPending = generatePendingRepayment(updatedLiability, nextPeriod)
        if (nextPending.total_amount > 0) {
          statements.push({
            statement: `INSERT INTO pending_repayments (id, liability_id, period_number, due_date, principal_amount, interest_amount, total_amount, status)
              VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
            values: [
              nextPending.id,
              nextPending.liability_id,
              nextPending.period_number,
              nextPending.due_date,
              nextPending.principal_amount,
              nextPending.interest_amount,
              nextPending.total_amount,
              '未还'
            ]
          })
      }
    }

    statements.push({
      statement: `INSERT INTO repayments (id, liability_id, period_number, amount, principal_amount, interest_amount, type, remark, repayment_time)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      values: [
          repaymentId,
          input.liabilityId,
          periodNumber,
          input.amount,
          principalAmount,
          interestAmount,
          input.type,
          input.remark || '',
          getCurrentDate().toISOString()
        ]
    })
  }

  // 调用账户出账/入账接口，从对应账户扣款
  const account = await getAccountById(liability.account_id)
  if (!account) {
    throw new Error('关联账户不存在')
  }

  const accountTxId = (getCurrentDate().valueOf() + 1).toString()
  if (account.type === '信用卡') {
    // 信用卡还款：减少已用额度（入账）
    const creditResult = await createCreditTransaction(
      liability.account_id,
      input.amount,
      `负债还款：${liability.name}`,
      accountTxId
    )
    statements.push(...creditResult.statements)
  } else {
    // 其他账户还款：扣除余额（出账）
    const debitResult = await createDebitTransaction(
      liability.account_id,
      input.amount,
      `负债还款：${liability.name}`,
      accountTxId
    )
    statements.push(...debitResult.statements)
  }

  await db.executeTransaction(statements)
}

/**
 * Get repayments for a liability
 */
export async function getRepayments(liabilityId: string): Promise<Repayment[]> {
  return await db.query(
    'SELECT * FROM repayments WHERE liability_id = ? ORDER BY repayment_time DESC',
    [liabilityId]
  )
}
