<template>
  <PageTemplate 
    title="基金买入"
    show-confirm-button
    confirm-text="确认买入"
    @back="goBack"
    @confirm="buyFund"
  >
    <div class="form-container">
      <el-form :model="fundForm" label-width="100px">
        <el-form-item label="基金名称" required>
          <el-input v-model="fundForm.name" placeholder="请输入基金名称" disabled />
        </el-form-item>
        <el-form-item label="基金代码" required>
          <el-input v-model="fundForm.code" placeholder="请输入基金代码" disabled />
        </el-form-item>
        <el-form-item label="确认净值" required>
          <el-input v-model.number="fundForm.cost_nav" placeholder="请输入确认净值" type="number" min="0" step="0.0001" />
        </el-form-item>
        <el-form-item label="交易份额" required>
          <el-input v-model.number="fundForm.shares" placeholder="请输入交易份额" type="number" min="0" step="0.0001" />
        </el-form-item>
        <el-form-item label="手续费">
          <el-input v-model.number="fundForm.fee" placeholder="请输入手续费" type="number" min="0" step="0.01" />
        </el-form-item>
        <el-form-item label="交易时间" required>
          <el-date-picker v-model="fundForm.transaction_time" type="datetime" placeholder="请选择交易时间" style="width: 100%" />
        </el-form-item>
        <el-form-item label="关联账户" required>
          <el-select v-model="fundForm.account_id" placeholder="请选择关联账户">
            <el-option v-for="account in accounts" :key="account.id" :label="account.name" :value="account.id" />
          </el-select>
        </el-form-item>
      </el-form>
    </div>
  </PageTemplate>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import PageTemplate from '../../common/PageTemplate.vue'
import db from '../../../database/index.js'

const props = defineProps({
  fundId: {
    type: String,
    required: true
  }
})

const emit = defineEmits(['navigate'])

// 账户数据
const accounts = ref([])

// 表单数据
const fundForm = ref({
  id: '',
  name: '',
  code: '',
  cost_nav: 0,
  shares: 0,
  fee: 0,
  has_lock: false,
  lock_period: 0,
  transaction_time: new Date(),
  account_id: ''
})

onMounted(async () => {
  await loadAccounts()
  await loadFundData()
})

const loadAccounts = async () => {
  try {
    const accountData = await db.query('SELECT * FROM accounts WHERE type != ?', ['信用卡'])
    accounts.value = accountData
  } catch (error) {
    console.error('加载账户数据失败:', error)
  }
}

const loadFundData = async () => {
  try {
    const fundData = await db.query('SELECT * FROM funds WHERE id = ?', [props.fundId])
    if (fundData.length > 0) {
      const fund = fundData[0]
      fundForm.value.id = fund.id
      fundForm.value.name = fund.name
      fundForm.value.code = fund.code
      // 保存基金的锁定周期信息
      fundForm.value.has_lock = fund.has_lock || false
      fundForm.value.lock_period = fund.lock_period || 0
    }
  } catch (error) {
    console.error('加载基金数据失败:', error)
  }
}

const goBack = () => {
  emit('navigate', { key: 'fundDetail', params: { fundId: props.fundId } })
}

const buyFund = async () => {
  // 验证必填字段
  if (!fundForm.value.cost_nav || fundForm.value.cost_nav <= 0) {
    alert('请输入有效的确认净值')
    return
  }
  if (!fundForm.value.shares || fundForm.value.shares <= 0) {
    alert('请输入有效的交易份额')
    return
  }
  if (!fundForm.value.transaction_time) {
    alert('请选择交易时间')
    return
  }
  if (!fundForm.value.account_id) {
    alert('请选择关联账户')
    return
  }
  
  try {
    // 计算锁定期限的最后一日
    let lockEndDate = new Date(fundForm.value.transaction_time)
    let lockPeriod = 0
    
    if (fundForm.value.has_lock && fundForm.value.lock_period > 0) {
      lockPeriod = fundForm.value.lock_period
      lockEndDate.setMonth(lockEndDate.getMonth() + lockPeriod)
    }
    
    // 获取当前基金数据
    const fundData = await db.query('SELECT * FROM funds WHERE id = ?', [props.fundId])
    if (fundData.length === 0) {
      alert('基金不存在')
      return
    }
    
    const currentFund = fundData[0]
    
    // 检查账户余额
    const accountData = await db.query('SELECT * FROM accounts WHERE id = ?', [fundForm.value.account_id])
    if (accountData.length === 0) {
      alert('所选账户不存在')
      return
    }
    
    const account = accountData[0]
    const totalCost = (fundForm.value.cost_nav * fundForm.value.shares) + fundForm.value.fee
    
    if (account.balance < totalCost) {
      alert(`账户余额不足，需要 ¥${totalCost.toFixed(2)}，当前余额 ¥${account.balance.toFixed(2)}`)
      return
    }
    
    const total_cost = (currentFund.shares * currentFund.cost_nav) + (fundForm.value.cost_nav * fundForm.value.shares)
    const new_shares = currentFund.shares + fundForm.value.shares
    const new_cost_nav = total_cost / new_shares
    const new_current_nav = fundForm.value.cost_nav
    
    // 检查基金是否已结束，如果已结束则重置为未结束状态
    const wasEnded = currentFund.ended === 1 || currentFund.ended === true
    const new_ended = 0 // 买入后设置为未结束
    
    // 准备事务语句
    const holdingId = Date.now().toString() + '_hold'
    const transactionId = Date.now().toString()
    const accountTransactionId = Date.now().toString() + '_acc'
    
    const statements = [
      // 创建基金持有记录
      {
        statement: 'INSERT INTO fund_holdings (id, fund_id, nav, shares, remaining_shares, fee, lock_period, lock_end_date, transaction_time, account_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        values: [holdingId, props.fundId, fundForm.value.cost_nav, fundForm.value.shares, fundForm.value.shares, fundForm.value.fee, lockPeriod, lockEndDate, fundForm.value.transaction_time, fundForm.value.account_id]
      },
      // 创建基金交易记录（买入）
      {
        statement: 'INSERT INTO fund_transactions (id, fund_id, transaction_nav, shares, type, hold_ids, fee, transaction_time, account_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        values: [transactionId, props.fundId, fundForm.value.cost_nav, fundForm.value.shares, '买入', holdingId, fundForm.value.fee, fundForm.value.transaction_time, fundForm.value.account_id]
      },
      // 更新基金记录（包括重置ended状态为0）
      {
        statement: 'UPDATE funds SET shares = ?, current_nav = ?, cost_nav = ?, total_fee = ?, ended = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
        values: [new_shares, new_current_nav, new_cost_nav, currentFund.total_fee + fundForm.value.fee, new_ended, props.fundId]
      },
      // 扣除账户余额
      {
        statement: 'UPDATE accounts SET balance = balance - ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
        values: [totalCost, fundForm.value.account_id]
      },
      // 创建账户流水记录
      {
        statement: 'INSERT INTO account_transactions (id, account_id, type, amount, balance_after, description, transaction_time) VALUES (?, ?, ?, ?, ?, ?, ?)',
        values: [accountTransactionId, fundForm.value.account_id, '支出', totalCost, account.balance - totalCost, `基金买入：${currentFund.name}`, fundForm.value.transaction_time]
      }
    ]
    
    // 使用事务执行所有操作
    await db.executeTransaction(statements)
    
    emit('navigate', 'asset')
  } catch (error) {
    console.error('基金买入失败:', error)
    alert('基金买入失败，请重试')
  }
}
</script>

<style scoped>
.form-container {
  background-color: white;
  padding: 0;
  box-sizing: border-box;
}

.el-form {
  margin: 0;
  padding: 16px;
}

.el-form-item {
  margin-bottom: 0;
  padding: 16px 0;
  border-bottom: 1px solid #f0f0f0;
  display: flex;
  align-items: center;
}

.el-form-item:last-child {
  border-bottom: none;
}

.el-form-item__label {
  font-size: 14px;
  font-weight: 500;
  color: #333333;
  width: 100px;
  flex-shrink: 0;
  margin-bottom: 0;
}

.el-form-item__content {
  flex: 1;
  margin-left: 16px;
}

.el-input {
  border: none;
  border-radius: 0;
}

.el-input__wrapper {
  border: none;
  box-shadow: none;
  padding: 0;
  height: auto;
  min-height: 32px;
}

.el-input__wrapper:focus-within {
  box-shadow: none;
  border-color: transparent;
}

.el-select {
  border: none;
  border-radius: 0;
  width: 100%;
}

.el-select .el-input__wrapper {
  border: none;
  padding: 0;
  height: auto;
  min-height: 32px;
}

.el-select:focus-within {
  box-shadow: none;
  border-color: transparent;
}

/* 响应式设计 */
@media (max-width: 375px) {
  .el-form {
    padding: 14px;
  }
  
  .el-form-item {
    padding: 14px 0;
  }
  
  .el-form-item__label {
    width: 90px;
    font-size: 13px;
  }
}
</style>