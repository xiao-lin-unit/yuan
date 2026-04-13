<template>
  <PageTemplate 
    title="新增基金"
    show-confirm-button
    confirm-text="确认添加"
    @back="goBack"
    @confirm="addFund"
  >
    <div class="form-container">
      <el-form :model="fundForm" label-width="100px">
        <el-form-item label="基金名称" required>
          <el-input v-model="fundForm.name" placeholder="请输入基金名称" />
        </el-form-item>
        <el-form-item label="基金代码" required>
          <el-input v-model="fundForm.code" placeholder="请输入基金代码" />
        </el-form-item>
        <el-form-item label="交易类型" required>
          <el-select v-model="fundForm.type" placeholder="请选择交易类型">
            <el-option label="买入" value="买入" />
            <el-option label="卖出" value="卖出" />
          </el-select>
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
        <el-form-item label="锁定期">
          <el-switch v-model="fundForm.has_lock" />
        </el-form-item>
        <el-form-item label="锁定周期" v-if="fundForm.has_lock">
          <el-input v-model.number="fundForm.lock_period" placeholder="请输入锁定周期（月）" type="number" min="1" step="1" />
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
  type: '买入',
  account_id: ''
})

onMounted(async () => {
  await loadAccounts()
})

const loadAccounts = async () => {
  try {
    const accountData = await db.query('SELECT * FROM accounts WHERE type != ?', ['信用卡'])
    accounts.value = accountData
  } catch (error) {
    console.error('加载账户数据失败:', error)
  }
}

const goBack = () => {
  emit('navigate', 'asset')
}

const addFund = async () => {
  // 验证必填字段
  if (!fundForm.value.name) {
    alert('请输入基金名称')
    return
  }
  if (!fundForm.value.code) {
    alert('请输入基金代码')
    return
  }
  if (!fundForm.value.type) {
    alert('请选择交易类型')
    return
  }
  if (!fundForm.value.cost_nav || fundForm.value.cost_nav <= 0) {
    alert('请输入有效的确认净值')
    return
  }
  if (!fundForm.value.shares || fundForm.value.shares <= 0) {
    alert('请输入有效的交易份额')
    return
  }
  if (fundForm.value.has_lock && (!fundForm.value.lock_period || fundForm.value.lock_period <= 0)) {
    alert('请输入有效的锁定周期')
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
    // 检查是否已存在相同基金（通过基金代码）
    const existingFunds = await db.query('SELECT * FROM funds WHERE code = ?', [fundForm.value.code])
    
    if (existingFunds.length > 0) {
      // 基金代码已存在，提示用户
      alert('该基金代码已存在，不允许重复添加')
      return
    }
    
    // 不存在，创建新基金记录
    const fundId = Date.now().toString()
    await db.run(
      'INSERT INTO funds (id, name, code, shares, current_nav, cost_nav, first_buy_date, has_lock, lock_period, account_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [fundId, fundForm.value.name, fundForm.value.code, fundForm.value.shares, fundForm.value.cost_nav, fundForm.value.cost_nav, fundForm.value.transaction_time, fundForm.value.has_lock, fundForm.value.lock_period, fundForm.value.account_id]
    )
    
    // 计算锁定期限的最后一日
    let lockEndDate = null
    if (fundForm.value.has_lock && fundForm.value.lock_period > 0) {
      lockEndDate = new Date(fundForm.value.transaction_time)
      lockEndDate.setMonth(lockEndDate.getMonth() + fundForm.value.lock_period)
    }
    
    // 创建基金交易记录
    const transactionId = Date.now().toString()
    await db.run(
      'INSERT INTO fund_transactions (id, fund_id, type, transaction_nav, shares, fee, has_lock, lock_period, lock_end_date, transaction_time, account_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [transactionId, fundId, fundForm.value.type, fundForm.value.cost_nav, fundForm.value.shares, fundForm.value.fee, fundForm.value.has_lock, fundForm.value.lock_period, lockEndDate, fundForm.value.transaction_time, fundForm.value.account_id]
    )
    
    // 新增基金时，基金表成本净值和当前净值为本次新增的基金的成本净值
    // if (fundForm.value.type === '买入') {
    //   const newShares = fundForm.value.shares
    //   // 成本净值计算公式：（当前净值*购买份额+费用）/ 购买份额
    //   const newCostNav = (fundForm.value.cost_nav * fundForm.value.shares + fundForm.value.fee) / fundForm.value.shares
      
    //   // 更新基金记录
    //   await db.run(
    //     'UPDATE funds SET shares = ?, current_nav = ?, cost_nav = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
    //     [newShares, newCostNav, newCostNav, fundId]
    //   )
    // }
    
    /*
    // 现有的更新基金表的持有份额和成本净值的逻辑，后续在做基金二次买入时计算使用
    const fundData = await db.query('SELECT * FROM funds WHERE id = ?', [fundId])
    if (fundData.length > 0) {
      const currentFund = fundData[0]
      let newShares = currentFund.shares
      let newCostNav = currentFund.cost_nav
      
      if (fundForm.value.type === '买入') {
        // 买入：更新份额和成本净值
        const totalCost = (currentFund.shares * currentFund.cost_nav) + (fundForm.value.current_nav * fundForm.value.shares) + fundForm.value.fee
        newShares = currentFund.shares + fundForm.value.shares
        newCostNav = totalCost / newShares
      } else if (fundForm.value.type === '卖出') {
        // 卖出：只更新份额，成本净值不变
        newShares = currentFund.shares - fundForm.value.shares
        if (newShares < 0) {
          alert('卖出份额不能超过当前持有份额')
          return
        }
      }
      
      // 更新基金记录
      await db.run(
        'UPDATE funds SET shares = ?, cost_nav = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
        [newShares, newCostNav, fundId]
      )
    }
    */
    
    emit('navigate', 'asset')
  } catch (error) {
    console.error('新增基金失败:', error)
    alert('新增基金失败，请重试')
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