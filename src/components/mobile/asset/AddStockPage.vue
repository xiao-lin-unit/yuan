<template>
  <PageTemplate 
    title="新增股票"
    show-confirm-button
    confirm-text="确认添加"
    @back="goBack"
    @confirm="addStock"
  >
    <div class="form-container">
      <el-form :model="stockForm" label-width="100px">
        <el-form-item label="股票名称" required>
          <el-input v-model="stockForm.name" placeholder="请输入股票名称" />
        </el-form-item>
        <el-form-item label="股票代码" required>
          <el-input v-model="stockForm.code" placeholder="请输入股票代码" />
        </el-form-item>
        <!-- <el-form-item label="类型" required>
          <el-select v-model="stockForm.type" placeholder="请选择交易类型">
            <el-option label="买入" value="买入" />
            <el-option label="卖出" value="卖出" />
          </el-select>
        </el-form-item> -->
        <el-form-item label="价格" required>
          <el-input v-model.number="stockForm.price" placeholder="请输入价格" type="number" min="0" step="0.01" />
        </el-form-item>
        <el-form-item label="股数" required>
          <el-input v-model.number="stockForm.quantity" placeholder="请输入股数" type="number" min="1" step="1" />
        </el-form-item>
        <el-form-item label="手续费">
          <el-input v-model.number="stockForm.fee" placeholder="请输入手续费" type="number" min="0" step="0.01" />
        </el-form-item>
        <el-form-item label="时间" required>
          <el-date-picker v-model="stockForm.transaction_time" type="datetime" placeholder="请选择时间" style="width: 100%" />
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
import db from '../../../database/index.js'

const emit = defineEmits(['navigate'])

// 账户数据
const accounts = ref([])

// 表单数据
const stockForm = ref({
  id: '',
  name: '',
  code: '',
  price: 0,
  quantity: 0,
  fee: 0,
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

const addStock = async () => {
  // 验证必填字段
  if (!stockForm.value.name) {
    alert('请输入股票名称')
    return
  }
  if (!stockForm.value.code) {
    alert('请输入股票代码')
    return
  }
  if (!stockForm.value.type) {
    alert('请选择交易类型')
    return
  }
  if (!stockForm.value.price || stockForm.value.price <= 0) {
    alert('请输入有效的交易价格')
    return
  }
  if (!stockForm.value.quantity || stockForm.value.quantity <= 0) {
    alert('请输入有效的交易股数')
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
    // 检查是否已存在相同股票（通过股票代码）
    const existingStocks = await db.query('SELECT * FROM stocks WHERE code = ?', [stockForm.value.code])
    
    if (existingStocks.length > 0) {
      // 股票代码已存在，提示用户
      alert('该股票代码已存在，不允许重复添加')
      return
    }
    
    // 不存在，创建新股票记录
    const stockId = Date.now().toString()
    await db.run(
      'INSERT INTO stocks (id, name, code, quantity, current_price, cost_price, first_buy_date, account_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      [stockId, stockForm.value.name, stockForm.value.code, 0, stockForm.value.price, 0, stockForm.value.transaction_time, stockForm.value.account_id]
    )
    
    // 创建股票交易记录
    const transactionId = Date.now().toString()
    await db.run(
      'INSERT INTO stock_transactions (id, stock_id, type, price, quantity, fee, transaction_time, account_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      [transactionId, stockId, stockForm.value.type, stockForm.value.price, stockForm.value.quantity, stockForm.value.fee, stockForm.value.transaction_time, stockForm.value.account_id]
    )
    
    // 新增股票时，更新股票表的持有股数和成本价
    // 成本价格计算公式为：（当前价格*购买股数+费用）/ 购买股数
    if (stockForm.value.type === '买入') {
      const newQuantity = stockForm.value.quantity
      const newCostPrice = (stockForm.value.price * stockForm.value.quantity + stockForm.value.fee) / stockForm.value.quantity
      
      // 更新股票记录
      await db.run(
        'UPDATE stocks SET quantity = ?, current_price = ?, cost_price = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
        [newQuantity, stockForm.value.price, newCostPrice, stockId]
      )
    }
    
    /*
    // 现有的更新股票表的持有股数和成本价的逻辑，后续在做股票二次买入时计算使用
    const stockData = await db.query('SELECT * FROM stocks WHERE id = ?', [stockId])
    if (stockData.length > 0) {
      const currentStock = stockData[0]
      let newQuantity = currentStock.quantity
      let newCostPrice = currentStock.cost_price
      
      if (stockForm.value.type === '买入') {
        // 买入：更新股数和成本价
        const totalCost = (currentStock.quantity * currentStock.cost_price) + (stockForm.value.price * stockForm.value.quantity) + stockForm.value.fee
        newQuantity = currentStock.quantity + stockForm.value.quantity
        newCostPrice = totalCost / newQuantity
      } else if (stockForm.value.type === '卖出') {
        // 卖出：只更新股数，成本价不变
        newQuantity = currentStock.quantity - stockForm.value.quantity
        if (newQuantity < 0) {
          alert('卖出股数不能超过当前持有股数')
          return
        }
      }
      
      // 更新股票记录
      await db.run(
        'UPDATE stocks SET quantity = ?, cost_price = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
        [newQuantity, newCostPrice, stockId]
      )
    }
    */
    
    emit('navigate', 'asset')
  } catch (error) {
    console.error('新增股票失败:', error)
    alert('新增股票失败，请重试')
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