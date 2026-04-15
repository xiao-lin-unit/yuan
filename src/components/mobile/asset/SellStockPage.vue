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
      stockForm.value.current_price = stock.current_price
    }
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
    // 检查股票总数量
    const stockData = await db.query('SELECT * FROM stocks WHERE id = ?', [props.stockId])
    if (stockData.length === 0) {
      alert('股票不存在')
      return
    }
    
    const stock = stockData[0]
    if (stockForm.value.quantity > stock.quantity) {
      alert('卖出数量不能大于股票的总数量')
      return
    }
    
    // 查询未卖出和部分卖出的持有记录，按照时间正序排序（FIFO）
    const holdings = await db.query(
      'SELECT * FROM stock_holdings WHERE stock_id = ? AND sell_status != ? ORDER BY transaction_time ASC',
      [props.stockId, '已卖出']
    )
    
    if (holdings.length === 0) {
      alert('没有可卖出的持有记录')
      return
    }
    
    // 计算所有可卖出的持有记录的总可用数量
    const totalAvailableQuantity = holdings.reduce((total, holding) => total + holding.remaining_quantity, 0)
    if (stockForm.value.quantity > totalAvailableQuantity) {
      alert(`卖出数量不能大于可卖出的总数量（当前可卖出数量：${totalAvailableQuantity}）`)
      return
    }
    
    // 准备事务语句数组
    const statements = []
    let remainingQuantityToSell = stockForm.value.quantity
    const soldHoldIds = []
    
    // 从最早买入的持有记录开始扣除卖出数量（FIFO）
    for (const holding of holdings) {
      if (remainingQuantityToSell <= 0) break
      
      const availableQuantity = holding.remaining_quantity
      const quantityToDeduct = Math.min(availableQuantity, remainingQuantityToSell)
      
      // 更新持有记录
      const newRemainingQuantity = availableQuantity - quantityToDeduct
      let newSellStatus = holding.sell_status
      
      if (newRemainingQuantity === 0) {
        newSellStatus = '已卖出'
      } else if (newRemainingQuantity < availableQuantity) {
        newSellStatus = '部分卖出'
      }
      
      statements.push({
        statement: 'UPDATE stock_holdings SET remaining_quantity = ?, sell_status = ? WHERE id = ?',
        values: [newRemainingQuantity, newSellStatus, holding.id]
      })
      
      soldHoldIds.push(holding.id)
      remainingQuantityToSell -= quantityToDeduct
    }
    
    // 创建股票交易记录（卖出）
    const transactionId = Date.now().toString()
    statements.push({
      statement: 'INSERT INTO stock_transactions (id, stock_id, price, quantity, type, hold_ids, fee, transaction_time, account_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
      values: [transactionId, props.stockId, stockForm.value.current_price, stockForm.value.quantity, '卖出', soldHoldIds.join(','), stockForm.value.fee, stockForm.value.transaction_time, stockForm.value.account_id]
    })
    
    // 更新股票表中的股票持有数量、当前价格和确认收益
    // 确认收益 = (卖出价格 - 持有成本价) * 卖出数量 - 手续费
    const newQuantity = stock.quantity - stockForm.value.quantity
    const confirmedProfit = (stockForm.value.current_price - stock.cost_price) * stockForm.value.quantity - stockForm.value.fee
    const newConfirmedProfit = (stock.confirmed_profit || 0) + confirmedProfit
    
    // 判断股票是否结束（剩余数量为0则标记为已结束）
    const isEnded = newQuantity === 0 ? 1 : 0
    
    statements.push({
      statement: 'UPDATE stocks SET quantity = ?, current_price = ?, confirmed_profit = ?, ended = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
      values: [newQuantity, stockForm.value.current_price, newConfirmedProfit, isEnded, props.stockId]
    })
    
    // 计算卖出实际到账金额
    const netProceeds = (stockForm.value.current_price * stockForm.value.quantity) - stockForm.value.fee
    
    // 获取账户当前余额
    const accountData = await db.query('SELECT balance FROM accounts WHERE id = ?', [stockForm.value.account_id])
    const currentBalance = accountData.length > 0 ? accountData[0].balance : 0
    
    // 增加账户余额
    statements.push({
      statement: 'UPDATE accounts SET balance = balance + ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
      values: [netProceeds, stockForm.value.account_id]
    })
    
    // 创建账户流水记录
    const accountTransactionId = Date.now().toString() + '_acc'
    statements.push({
      statement: 'INSERT INTO account_transactions (id, account_id, type, amount, balance_after, description, transaction_time) VALUES (?, ?, ?, ?, ?, ?, ?)',
      values: [accountTransactionId, stockForm.value.account_id, '收入', netProceeds, currentBalance + netProceeds, `股票卖出：${stock.name}`, stockForm.value.transaction_time]
    })
    
    // 使用事务执行所有操作
    await db.executeTransaction(statements)
    
    emit('navigate', 'asset')
  } catch (error) {
    console.error('股票卖出失败:', error)
    alert('股票卖出失败，请重试')
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
