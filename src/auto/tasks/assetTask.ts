import { registerTask } from '../index'
import db from '../../database'
import { getCurrentDate, getDate } from '../../utils/timezone'
import { calculatePerAssetIncome, recordAssetIncome } from '../../services/asset/assetService'
import { getAccountById } from '../../services/account/accountService'

/**
 * Increment a date by one income period.
 * Unlike calculateNextIncomeDate() which always returns the next future date from NOW,
 * this function increments from the given date, which is essential for processing
 * multiple missed periods correctly.
 * Returns null for unknown periods to prevent infinite loops.
 */
function addPeriod(dateStr: string, period: string): string | null {
  const d = getDate(dateStr)
  if (period === '日') return d.add(1, 'day').format('YYYY-MM-DD')
  if (period === '月') return d.add(1, 'month').format('YYYY-MM-DD')
  if (period === '年') return d.add(1, 'year').format('YYYY-MM-DD')
  return null
}

registerTask('assetAutoIncome', async () => {
    await db.connect()
    const now = getCurrentDate()
    const today = now.format('YYYY-MM-DD')
    const assets = await db.query(
      'SELECT * FROM assets WHERE type = ? AND status = ? AND calculation_type != ? AND next_income_date <= ?',
      ['普通资产', '开启', '无', today]
    )

    for (const asset of assets) {
        try {
            const statements: { statement: string; values: any[] }[] = []
            let totalIncome = 0
            let currentIncomeDate = asset.next_income_date
            let amount = asset.amount || 0

            // Pre-load account info for transaction records
            let accountBalance: number | null = null
            if (!asset.account_id) continue;
            const account = await getAccountById(asset.account_id)
            if (!account || account.status === '停用') continue;
            accountBalance = account.balance || 0
            
            // Process each missed income period from next_income_date up to today
            while (getDate(currentIncomeDate).isBefore(now) || getDate(currentIncomeDate).isSame(now, 'day')) {
                const income = calculatePerAssetIncome({...asset, amount})
                if (income <= 0) break

                // Record income with the ACTUAL income date (not today)
                statements.push(await recordAssetIncome(asset.id, income, currentIncomeDate))

                totalIncome += income
                amount += income
                // If asset has a linked active account, credit the income with a transaction record
                const txId = (getCurrentDate().valueOf() + statements.length).toString()
                statements.push({
                    statement: `INSERT INTO account_transactions (id, account_id, type, amount, balance_after, description, transaction_time)
                                VALUES (?, ?, ?, ?, ?, ?, ?)`,
                    values: [
                        txId,
                        asset.account_id,
                        '收入',
                        income,
                        accountBalance + totalIncome,
                        `资产收益：${asset.name}`,
                        now.toISOString()
                    ]
                })

                // Advance to the next income period
                const nextDate = addPeriod(currentIncomeDate, asset.period)
                if (!nextDate) break  // Unknown period — stop to prevent infinite loop
                currentIncomeDate = nextDate
            }
            
            statements.push({
                statement: 'UPDATE accounts SET balance = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
                values: [accountBalance + totalIncome, asset.account_id]
            })

            if (totalIncome > 0) {
                // Update asset: set next_income_date and add total income to amount
                statements.push({
                    statement: 'UPDATE assets SET next_income_date = ?, amount = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
                    values: [currentIncomeDate, amount, asset.id]
                })

                // Execute all statements in a single transaction
                await db.executeTransaction(statements)
            }
        } catch (e) {
            console.error(`Auto income failed for asset ${asset.id}:`, e)
        }
    }
})
