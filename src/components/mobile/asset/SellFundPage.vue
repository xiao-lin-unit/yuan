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
import { getCurrentDate } from '../../../utils/timezone'
import PageTemplate from '../../common/PageTemplate.vue'
import { sellFund as sellFundService, getAvailableAccounts, getFundById } from '../../../services/asset/fundService'

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
  transaction_time: getCurrentDate(),
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
    accounts.value = await getAvailableAccounts()
  } catch (error) {
    console.error('加载账户数据失败:', error)
  }
}

const loadFundData = async () => {
  try {
    const fund = await getFundById(props.fundId)
    if (fund) {
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
    await sellFundService(props.fundId, {
      nav: fundForm.value.current_nav,
      shares: fundForm.value.shares,
      fee: fundForm.value.fee,
      transaction_time: fundForm.value.transaction_time,
      account_id: fundForm.value.account_id
    })
    
    emit('navigate', 'asset')
  } catch (error: any) {
    console.error('基金卖出失败:', error)
    alert(error.message || '基金卖出失败，请重试')
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