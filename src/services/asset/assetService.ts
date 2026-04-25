/**
 * Asset Service
 * Handles general asset operations
 */

import dayjs from 'dayjs'
import db from '../../database/index.js'
import type { Asset, AssetInput } from '../../types/asset/asset.js'

/**
 * Calculate next income date based on period and income date
 */
function calculateNextIncomeDate(period: string, incomeDate: string): string {
  if (!period) return ''

  const now = dayjs()

  if (period === '日') {
    // 每日：下一个收益日是明天
    return now.add(1, 'day').format('YYYY-MM-DD')
  } else if (period === '年') {
    // 每年：income_date format is MM-DD, next income date is this year or next year
    if (!incomeDate) return ''
    const [month, day] = incomeDate.split('-')
    let nextDate = dayjs().year(now.year()).month(parseInt(month) - 1).date(parseInt(day))

    // If this year's income date has passed, next year
    if (nextDate.isBefore(now) || nextDate.isSame(now, 'day')) {
      nextDate = nextDate.add(1, 'year')
    }

    return nextDate.format('YYYY-MM-DD')
  } else if (period === '月') {
    // 每月：income_date format is DD, next income date is this month or next month
    if (!incomeDate) return ''
    const [day] = incomeDate.split('-')
    let nextDate = dayjs().year(now.year()).month(now.month()).date(parseInt(day))

    // If this month's income date has passed, next month
    if (nextDate.isBefore(now) || nextDate.isSame(now, 'day')) {
      nextDate = nextDate.add(1, 'month')
    }

    return nextDate.format('YYYY-MM-DD')
  }

  return ''
}

/**
 * Calculate asset income amount based on calculation type and period
 * @param asset The asset to calculate income for
 * @returns The income amount for one period
 */
export function calculatePerAssetIncome(asset: Asset): number {
  if (!asset.calculation_type || !asset.period) return 0

  if (asset.calculation_type === '按金额计算') {
    // 按每期固定金额计算
    return (asset.income_amount || 0)
  } else if (asset.calculation_type === '按年收益率计算') {
    // 按年收益率计算：根据周期不同，年化收益率需要除以不同的基数
    const rate = asset.annual_yield_rate || 0
    const principal = asset.amount || 0

    if (rate <= 0 || principal <= 0) return 0

    let periodDivisor = 1
    if (asset.period === '日') {
      periodDivisor = 365
    } else if (asset.period === '月') {
      periodDivisor = 12
    } else if (asset.period === '年') {
      periodDivisor = 1
    }

    return principal * rate / periodDivisor
  }

  return 0
}

/**
 * Add a new general asset
 */
export async function addAsset(assetData: AssetInput): Promise<void> {
  const id = dayjs().valueOf().toString()

  // Calculate next income date
  let nextIncomeDate = ''
  if (assetData.period) {
    nextIncomeDate = calculateNextIncomeDate(assetData.period, assetData.income_date || '')
  }

  await db.run(
    'INSERT INTO assets (id, type, name, amount, account_id, period, period_count, income_date, next_income_date, calculation_type, income_amount, annual_yield_rate) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    [
      id,
      assetData.type,
      assetData.name,
      assetData.amount,
      assetData.account_id,
      assetData.period || null,
      assetData.period_count || 0,
      assetData.income_date || null,
      nextIncomeDate || null,
      assetData.calculation_type || null,
      assetData.income_amount || 0,
      assetData.annual_yield_rate || 0
    ]
  )
}

/**
 * Get all assets
 */
export async function getAssets(): Promise<Asset[]> {
  return await db.query('SELECT * FROM assets ORDER BY created_at DESC')
}

/**
 * Get assets by type
 */
export async function getAssetsByType(type: string): Promise<Asset[]> {
  return await db.query('SELECT * FROM assets WHERE type = ? ORDER BY created_at DESC', [type])
}

/**
 * Get active assets (not ended)
 */
export async function getActiveAssets(): Promise<Asset[]> {
  return await db.query('SELECT * FROM assets WHERE ended = 0 ORDER BY created_at DESC')
}

/**
 * Get asset by ID
 */
export async function getAssetById(assetId: string): Promise<Asset | null> {
  const result = await db.query('SELECT * FROM assets WHERE id = ?', [assetId])
  return result.length > 0 ? result[0] : null
}

/**
 * Update asset
 */
export async function updateAsset(assetId: string, data: Partial<Asset>): Promise<void> {
  const fields: string[] = []
  const values: any[] = []

  if (data.name !== undefined) {
    fields.push('name = ?')
    values.push(data.name)
  }
  if (data.amount !== undefined) {
    fields.push('amount = ?')
    values.push(data.amount)
  }
  if (data.account_id !== undefined) {
    fields.push('account_id = ?')
    values.push(data.account_id)
  }
  if (data.period !== undefined) {
    fields.push('period = ?')
    values.push(data.period)
  }
  if (data.period_count !== undefined) {
    fields.push('period_count = ?')
    values.push(data.period_count)
  }
  if (data.income_date !== undefined) {
    fields.push('income_date = ?')
    values.push(data.income_date)
  }
  if (data.calculation_type !== undefined) {
    fields.push('calculation_type = ?')
    values.push(data.calculation_type)
  }
  if (data.income_amount !== undefined) {
    fields.push('income_amount = ?')
    values.push(data.income_amount)
  }
  if (data.annual_yield_rate !== undefined) {
    fields.push('annual_yield_rate = ?')
    values.push(data.annual_yield_rate)
  }
  if (data.ended !== undefined) {
    fields.push('ended = ?')
    values.push(data.ended)
  }

  if (fields.length === 0) return

  fields.push('updated_at = CURRENT_TIMESTAMP')
  values.push(assetId)

  await db.run(
    `UPDATE assets SET ${fields.join(', ')} WHERE id = ?`,
    values
  )
}

/**
 * Delete asset
 */
export async function deleteAsset(assetId: string): Promise<void> {
  await db.run('DELETE FROM assets WHERE id = ?', [assetId])
}

/**
 * Mark asset as ended
 */
export async function endAsset(assetId: string): Promise<void> {
  await db.run(
    'UPDATE assets SET ended = 1, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
    [assetId]
  )
}
