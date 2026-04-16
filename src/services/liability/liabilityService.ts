/**
 * Liability Service
 * Handles liability and repayment operations
 */

import db from '../../database/index.js'
import type { Liability, Repayment, LiabilityInput, RepaymentInput } from '../../types/liability/liability.js'

/**
 * Add a new liability
 */
export async function addLiability(liabilityData: LiabilityInput): Promise<void> {
  const id = Date.now().toString()
  await db.run(
    `INSERT INTO liabilities (id, name, type, principal, remaining_principal, is_interest, interest_rate, 
      start_date, repayment_method, repayment_day, period, account_id, remark, status) 
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      id,
      liabilityData.name,
      liabilityData.type,
      liabilityData.principal,
      liabilityData.principal, // remaining_principal starts as principal
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
  )
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
  await db.run('DELETE FROM liabilities WHERE id = ?', [liabilityId])
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
 * Make a repayment
 */
export async function makeRepayment(input: RepaymentInput): Promise<void> {
  const liability = await getLiabilityById(input.liabilityId)
  if (!liability) {
    throw new Error('负债不存在')
  }

  if (liability.status === '已结清') {
    throw new Error('该负债已结清')
  }

  const newRemainingPrincipal = liability.remaining_principal - input.amount
  if (newRemainingPrincipal < 0) {
    throw new Error('还款金额不能超过剩余本金')
  }

  const isSettled = newRemainingPrincipal === 0
  const newStatus = isSettled ? '已结清' : '未结清'

  const repaymentId = Date.now().toString()

  const statements = [
    // Update liability
    {
      statement: `UPDATE liabilities SET remaining_principal = ?, status = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?`,
      values: [newRemainingPrincipal, newStatus, input.liabilityId]
    },
    // Create repayment record
    {
      statement: `INSERT INTO repayments (id, liability_id, amount, type, remark, repayment_time) 
                  VALUES (?, ?, ?, ?, ?, ?)`,
      values: [
        repaymentId,
        input.liabilityId,
        input.amount,
        input.type,
        input.remark || '',
        new Date()
      ]
    }
  ]

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
