<template>
  <PageTemplate 
    title="股票买入"
    show-confirm-button
    confirm-text="确认买入"
    @back="goBack"
    @confirm="buyStock"
  >
    <div class="form-container">
      <el-form :model="stockForm" label-width="100px">
        <el-form-item label="股票名称" required>
          <el-input v-model="stockForm.name" placeholder="请输入股票名称" disabled />
        </el-form-item>
        <el-form-item label="股票代码" required>
          <el-input v-model="stockForm.code" placeholder="请输入股票代码" disabled />
        </el-form-item>
        <el-form-item label="买入价格" required>
          <el-input v-model.number="stockForm.price" placeholder="请输入买入价格" type="number" min="0" step="0.01" />
        </el-form-item>
        <el-form-item label="买入数量" required>
          <el-input v-model.number="stockForm.quantity" placeholder="请输入买入数量" type="number" min="0" step="1" />
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
import db from '../../../database/index.js'

const props = defineProps({
  stockId: {
    type: String,
    required: true
  }
})

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
  account_id: ''
})

onMounted(async () => {
  await loadAccounts()
  await loadStockData()
})

const loadAccounts = async () => {
  try {
    const accountData = await db.query('SELECT * FROM accounts WHERE type != ?', ['信用卡'])
    accounts.value = accountData
  } catch (error) {
    console.error('加载账户数据失败:', error)
  }
}

const loadStockData = async () => {
  try {
    const stockData = await db.query('SELECT * FROM stocks WHERE id = ?', [props.stockId])
    if (stockData.length > 0) {
      const stock = stockData[0]
      stockForm.value.id = stock.id
      stockForm.value.name = stock.name
      stockForm.value.code = stock.code
    }
  } catch (error) {
    console.error('加载股票数据失败:', error)
  }
}

const goBack = () => {
  emit('navigate', { key: 'stockDetail', params: { stockId: props.stockId } })
}

const buyStock = async () => {
  // 验证必填字段
  if (!stockForm.value.price || stockForm.value.price <= 0) {
    alert('请输入有效的买入价格')
    return
  }
  if (!stockForm.value.quantity || stockForm.value.quantity <= 0) {
    alert('请输入有效的买入数量')
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
    // 获取当前股票数据
    const stockData = await db.query('SELECT * FROM stocks WHERE id = ?', [props.stockId])
    if (stockData.length === 0) {
      alert('股票不存在')
      return
    }
    
    const currentStock = stockData[0]
    
    // 检查账户余额
    const accountData = await db.query('SELECT * FROM accounts WHERE id = ?', [stockForm.value.account_id])
    if (accountData.length === 0) {
      alert('所选账户不存在')
      return
    }
    
    const account = accountData[0]
    const totalCost = (stockForm.value.price * stockForm.value.quantity) + stockForm.value.fee
    
    if (account.balance < totalCost) {
      alert(`账户余额不足，需要 ¥${totalCost.toFixed(2)}，当前余额 ¥${account.balance.toFixed(2)}`)
      return
    }
    
    // 计算新的成本价格（加权平均）= ((持有成本价 * 持有数量) + (本次买入价格 * 本次买入数量) + 本次买入手续费) / (持有数量 + 本次买入数量)
    const total_cost = (currentStock.quantity * currentStock.cost_price) + (stockForm.value.price * stockForm.value.quantity) + stockForm.value.fee
    const new_quantity = currentStock.quantity + stockForm.value.quantity
    const new_cost_price = total_cost / new_quantity
    const new_current_price = stockForm.value.price
    
    // 检查股票是否已结束，如果已结束则重置为未结束状态
    const new_ended = 0 // 买入后设置为未结束
    
    // 准备事务语句
    const holdingId = Date.now().toString() + '_hold'
    const transactionId = Date.now().toString()
    const accountTransactionId = Date.now().toString() + '_acc'
    
    const statements = [
      // 创建股票持有记录
      {
        statement: 'INSERT INTO stock_holdings (id, stock_id, price, quantity, remaining_quantity, fee, transaction_time, account_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        values: [holdingId, props.stockId, stockForm.value.price, stockForm.value.quantity, stockForm.value.quantity, stockForm.value.fee, stockForm.value.transaction_time, stockForm.value.account_id]
      },
      // 创建股票交易记录（买入）
      {
        statement: 'INSERT INTO stock_transactions (id, stock_id, price, quantity, type, hold_ids, fee, transaction_time, account_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        values: [transactionId, props.stockId, stockForm.value.price, stockForm.value.quantity, '买入', holdingId, stockForm.value.fee, stockForm.value.transaction_time, stockForm.value.account_id]
      },
      // 更新股票记录（包括重置ended状态为0）
      {
        statement: 'UPDATE stocks SET quantity = ?, current_price = ?, cost_price = ?, ended = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
        values: [new_quantity, new_current_price, new_cost_price, new_ended, props.stockId]
      },
      // 扣除账户余额
      {
        statement: 'UPDATE accounts SET balance = balance - ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
        values: [totalCost, stockForm.value.account_id]
      },
      // 创建账户流水记录
      {
        statement: 'INSERT INTO account_transactions (id, account_id, type, amount, balance_after, description, transaction_time) VALUES (?, ?, ?, ?, ?, ?, ?)',
        values: [accountTransactionId, stockForm.value.account_id, '支出', totalCost, account.balance - totalCost, `股票买入：${currentStock.name}`, stockForm.value.transaction_time]
      }
    ]
    
    // 使用事务执行所有操作
    await db.executeTransaction(statements)
    
    emit('navigate', 'asset')
  } catch (error) {
    console.error('股票买入失败:', error)
    alert('股票买入失败，请重试')
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
