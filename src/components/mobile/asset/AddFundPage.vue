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
        <!-- <el-form-item label="交易类型" required>
          <el-select v-model="fundForm.type" placeholder="请选择交易类型">
            <el-option v-for="item in transactionTypes" :key="item.value" :label="item.label" :value="item.value" />
          </el-select>
        </el-form-item> -->
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
import dayjs from 'dayjs'
import PageTemplate from '../../common/PageTemplate.vue'
import { transactionTypes } from '../../../utils/dictionaries'
import { validateFundCode, checkFundExists, addFund as addFundService, checkAccountBalance } from '../../../services/asset/fundService'
import { getNonCreditCardAccounts } from '../../../services/account/accountService'

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
  transaction_time: dayjs(),
  type: '买入',
  account_id: ''
})

onMounted(async () => {
  await loadAccounts()
})

const loadAccounts = async () => {
  try {
    accounts.value = await getNonCreditCardAccounts()
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
  // 基金代码格式验证：6位数字
  if (!validateFundCode(fundForm.value.code)) {
    alert('基金代码必须为6位数字')
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
    const fundExists = await checkFundExists(fundForm.value.code)
    
    if (fundExists.exists) {
      if (!fundExists.ended) {
        alert('已存在该基金，不允许重复添加')
      } else {
        alert('已存在该基金，请到历史记录中查看')
      }
      return
    }
    
    // 检查账户余额
    const totalCost = (fundForm.value.cost_nav * fundForm.value.shares) + fundForm.value.fee
    const balanceCheck = await checkAccountBalance(fundForm.value.account_id, totalCost)
    
    if (!balanceCheck.sufficient) {
      alert(`账户余额不足，需要 ¥${totalCost.toFixed(2)}，当前余额 ¥${balanceCheck.currentBalance.toFixed(2)}`)
      return
    }
    
    // 添加基金
    await addFundService({
      name: fundForm.value.name,
      code: fundForm.value.code,
      cost_nav: fundForm.value.cost_nav,
      shares: fundForm.value.shares,
      fee: fundForm.value.fee,
      has_lock: fundForm.value.has_lock,
      lock_period: fundForm.value.lock_period,
      transaction_time: fundForm.value.transaction_time,
      account_id: fundForm.value.account_id
    })
    
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