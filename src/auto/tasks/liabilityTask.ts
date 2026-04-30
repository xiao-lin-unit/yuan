import { registerTask } from '../index'
import db from '../../database'
import { makeRepayment, getEarliestPendingRepayment } from '../../services/liability/liabilityService'


registerTask('liabilityAutoRepayment', async () => {
    await db.connect()

    const liabilities = await db.query(
      'SELECT * FROM liabilities WHERE status = ? AND is_interest = 1 AND repayment_method != ?',
      ['未结清', '随借随还']
    )

    for (const liability of liabilities) {
        try {
            while (true) {
                const pending = await getEarliestPendingRepayment(liability.id)
                if (!pending) break

                await makeRepayment({
                  liabilityId: liability.id,
                  amount: pending.total_amount,
                  type: '正常还款',
                  remark: '系统自动还款'
                })
            }
        } catch (e) {
            // Skip this liability on error, continue with the next one
            console.error(`Auto repayment failed for liability ${liability.id}:`, e)
        }
    }
})
