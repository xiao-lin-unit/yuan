<template>
  <PageTemplate 
    title="基金卖出"
    show-confirm-button
    confirm-text="确认卖出"
    @back="goBack"
    @confirm="sellFund"
  >
    <div class="form-container">
      <el-form :model="fundForm" label-width="100px">
        <el-form-item label="基金名称" required>
          <el-input v-model="fundForm.name" placeholder="请输入基金名称" disabled />
        </el-form-item>
        <el-form-item label="基金代码" required>
          <el-input v-model="fundForm.code" placeholder="请输入基金代码" disabled />
        </el-form-item>
        <el-form-item label="当前净值" required>
          <el-input v-model.number="fundForm.current_nav" placeholder="请输入当前净值" type="number" min="0" step="0.0001" />
        </el-form-item>
        <el-form-item label="卖出份额" required>
          <el-input v-model.number="fundForm.shares" placeholder="请输入卖出份额" type="number" min="0" step="0.0001" />
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
  current_nav: 0,
  shares: 0,
  fee: 0,
  transaction_time: new Date(),
  account_id: ''
})

// 基金数据
const fundData = ref(null)

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
      fundForm.value.current_nav = fund.current_nav
    }
  } catch (error) {
    console.error('加载基金数据失败:', error)
  }
}

const goBack = () => {
  emit('navigate', { key: 'fundDetail', params: { fundId: props.fundId } })
}

const sellFund = async () => {
  // 验证必填字段
  if (!fundForm.value.current_nav || fundForm.value.current_nav <= 0) {
    alert('请输入有效的当前净值')
    return
  }
  if (!fundForm.value.shares || fundForm.value.shares <= 0) {
    alert('请输入有效的卖出份额')
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
    // 检查基金总份额
    const fundData = await db.query('SELECT * FROM funds WHERE id = ?', [props.fundId])
    if (fundData.length === 0) {
      alert('基金不存在')
      return
    }
    
    const fund = fundData[0]
    if (fundForm.value.shares > fund.shares) {
      alert('卖出份额不能大于基金的总份额')
      return
    }
    
    // 查询未卖出和部分卖出且锁定期已过期的持有记录，按照时间正序排序
    const currentDate = new Date().toISOString()
    const holdings = await db.query(
      'SELECT * FROM fund_holdings WHERE fund_id = ? AND sell_status != ? AND lock_end_date <= ? ORDER BY transaction_time ASC',
      [props.fundId, '已卖出', currentDate]
    )
    
    if (holdings.length === 0) {
      alert('没有可卖出的持有记录（所有记录均在锁定期内）')
      return
    }
    
    // 计算所有可卖出的持有记录的总可用份额
    const totalAvailableShares = holdings.reduce((total, holding) => total + holding.remaining_shares, 0)
    if (fundForm.value.shares > totalAvailableShares) {
      alert(`卖出份额不能大于可卖出的总份额（当前可卖出份额：${totalAvailableShares}）`)
      return
    }
    
    // 准备事务语句数组
    const statements = []
    let remainingSharesToSell = fundForm.value.shares
    const soldHoldIds = []
    
    // 从最早买入的持有记录开始扣除卖出份额
    for (const holding of holdings) {
      if (remainingSharesToSell <= 0) break
      
      const availableShares = holding.remaining_shares
      const sharesToDeduct = Math.min(availableShares, remainingSharesToSell)
      
      // 更新持有记录
      const newRemainingShares = availableShares - sharesToDeduct
      let newSellStatus = holding.sell_status
      
      if (newRemainingShares === 0) {
        newSellStatus = '已卖出'
      } else if (newRemainingShares < availableShares) {
        newSellStatus = '部分卖出'
      }
      
      statements.push({
        statement: 'UPDATE fund_holdings SET remaining_shares = ?, sell_status = ? WHERE id = ?',
        values: [newRemainingShares, newSellStatus, holding.id]
      })
      
      soldHoldIds.push(holding.id)
      remainingSharesToSell -= sharesToDeduct
    }
    
    // 创建基金交易记录（卖出）
    const transactionId = Date.now().toString()
    statements.push({
      statement: 'INSERT INTO fund_transactions (id, fund_id, transaction_nav, shares, type, hold_ids, fee, transaction_time, account_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
      values: [transactionId, props.fundId, fundForm.value.current_nav, fundForm.value.shares, '卖出', soldHoldIds.join(','), fundForm.value.fee, fundForm.value.transaction_time, fundForm.value.account_id]
    })
    
    // 更新基金表中的基金持有份额、当前净值和确认收益
    const newShares = fund.shares - fundForm.value.shares
    const newConfirmedProfit = (fund.confirmed_profit || 0) + (fundForm.value.current_nav - fund.cost_nav) * fundForm.value.shares - fundForm.value.fee
    
    // 判断基金是否结束（剩余份额为0则标记为已结束）
    const isEnded = newShares === 0 ? 1 : 0
    
    statements.push({
      statement: 'UPDATE funds SET shares = ?, current_nav = ?, confirmed_profit = ?, ended = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
      values: [newShares, fundForm.value.current_nav, newConfirmedProfit, isEnded, props.fundId]
    })
    
    // 使用事务执行所有操作
    await db.executeTransaction(statements)
    
    emit('navigate', 'asset')
  } catch (error) {
    console.error('基金卖出失败:', error)
    alert('基金卖出失败，请重试')
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