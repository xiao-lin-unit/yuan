<template>
  <PageTemplate 
    title="股票卖出"
    show-confirm-button
    confirm-text="确认卖出"
    @back="goBack"
    @confirm="sellStock"
  >
    <div class="form-container">
      <el-form :model="stockForm" label-width="100px">
        <el-form-item label="股票名称" required>
          <el-input v-model="stockForm.name" placeholder="请输入股票名称" disabled />
        </el-form-item>
        <el-form-item label="股票代码" required>
          <el-input v-model="stockForm.code" placeholder="请输入股票代码" disabled />
        </el-form-item>
        <el-form-item label="当前价格" required>
          <el-input v-model.number="stockForm.current_price" placeholder="请输入当前价格" type="number" min="0" step="0.01" />
        </el-form-item>
        <el-form-item label="卖出数量" required>
          <el-input v-model.number="stockForm.quantity" placeholder="请输入卖出数量" type="number" min="0" step="1" />
        </el-form-item>
        <el-form-item label="手续费">
          <el-input v-model.number="stockForm.fee" placeholder="请输入手续费" type="number" min="0" step="0.01" />
        </el-form-item>
        <el-form-item label="交易时间" required>
          <el-date-picker v-model="stockForm.transaction_time" type="datetime" placeholder="请选择交易时间" style="width: 100%" />
        </el-form-item>
        <el-form-item label="关联账户" required>
          <el-select v-model="stockForm.account_id" placeholder="请选择关联账户">
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
import {
  sellStock as sellStockService,
  getAvailableAccounts,
  getStockDetail
} from '../../../services/asset/stockService'

const props = defineProps({
  stockId: {
    type: String,
    required: true
  }
})

const emit = defineEmits(['navigate'])

// 账户数据
const accounts = ref<Array<{ id: string; name: string; balance: number }>>([])

// 表单数据
const stockForm = ref({
  name: '',
  code: '',
  current_price: 0,
  quantity: 0,
  fee: 0,
  transaction_time: new Date(),
  account_id: ''
})

onMounted(async () => {
  await loadAccounts()
  await loadStockData()
})

const loadAccounts = async () => {
  try {
    accounts.value = await getAvailableAccounts()
  } catch (error) {
    console.error('加载账户数据失败:', error)
  }
}

const loadStockData = async () => {
  try {
    const stock = await getStockDetail(props.stockId)
    stockForm.value.name = stock.name
    stockForm.value.code = stock.code
    stockForm.value.current_price = stock.currentPrice
  } catch (error) {
    console.error('加载股票数据失败:', error)
  }
}

const goBack = () => {
  emit('navigate', { key: 'stockDetail', params: { stockId: props.stockId } })
}

const sellStock = async () => {
  // 验证必填字段
  if (!stockForm.value.current_price || stockForm.value.current_price <= 0) {
    alert('请输入有效的当前价格')
    return
  }
  if (!stockForm.value.quantity || stockForm.value.quantity <= 0) {
    alert('请输入有效的卖出数量')
    return
  }
  if (!stockForm.value.transaction_time) {
    alert('请选择交易时间')
    return
  }
  if (!stockForm.value.account_id) {
    alert('请选择关联账户')
    return
  }

  try {
    // 调用服务卖出股票
    await sellStockService(props.stockId, {
      price: stockForm.value.current_price,
      quantity: stockForm.value.quantity,
      fee: stockForm.value.fee,
      transaction_time: stockForm.value.transaction_time,
      account_id: stockForm.value.account_id
    })

    emit('navigate', 'asset')
  } catch (error) {
    console.error('股票卖出失败:', error)
    alert(error instanceof Error ? error.message : '股票卖出失败，请重试')
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
