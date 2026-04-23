<template>
  <div class="add-income-page">
    <!-- 顶部导航栏 -->
    <PageHeader title="收入" @back="goBack" />
    
    
    <!-- 中间内容区域 -->
    <div class="content-section">
      <!-- 分类选择 -->
      <div class="category-section">
        <div class="category-grid">
          <CategoryItem 
            v-for="category in categories" 
            :key="category.id" 
            :category="category"
            :is-selected="selectedCategoryId === category.id"
            @select="selectCategory"
          />
        </div>
      </div>
      
      <!-- 日期时间选择弹窗 -->
      <div v-if="showDateTimeSelector" class="date-time-selector-overlay" @click="showDateTimeSelector = false">
        <div class="date-time-selector-dialog" @click.stop>
          <div class="dialog-header">
            <div class="dialog-title">选择日期时间</div>
            <el-icon @click="showDateTimeSelector = false"><Close /></el-icon>
          </div>
          <div class="dialog-body">
            <div class="date-time-picker">
              <input 
                type="datetime-local" 
                v-model="selectedDateTime" 
                class="datetime-input"
                @change="updateDateTime"
              />
            </div>
            <div class="dialog-actions">
              <button class="cancel-btn" @click="showDateTimeSelector = false">取消</button>
              <button class="confirm-btn" @click="confirmDateTime">确定</button>
            </div>
          </div>
        </div>
      </div>
      
      <!-- 账户选择弹窗 -->
      <div v-if="showAccountSelector" class="account-selector-overlay" @click="showAccountSelector = false">
        <div class="account-selector-dialog" @click.stop>
          <div class="dialog-header">
            <div class="dialog-title">选择账户</div>
            <el-icon @click="showAccountSelector = false"><Close /></el-icon>
          </div>
          <div class="dialog-body">
            <div 
              v-for="account in accounts" 
              :key="account.id" 
              class="account-item"
              @click="selectAccount(account)"
            >
              <div class="account-name">{{ account.name }}</div>
              <div class="account-balance">余额: ¥{{ account.balance }}</div>
            </div>
            <div v-if="accounts.length === 0" class="no-accounts">
              暂无账户，请先添加账户
            </div>
          </div>
        </div>
      </div>
    </div>
    
    <!-- 底部固定区域 -->
    <div class="bottom-fixed-section">
      <!-- 支付方式和日期 -->
      <div class="payment-section">
        <div class="payment-item account-selector" @click="openAccountSelector">{{ selectedAccount }}</div>
        <div class="payment-item date-time-selector" @click="showDateTimeSelector = true">{{ formattedDateTime }}</div>
      </div>
      
      <!-- 备注和金额行 -->
      <div class="remark-amount-row">
        <div class="remark-section">
          <input class="remark-input" contenteditable="true" placeholder="请输入备注" v-model="remark" />
        </div>
        <div class="amount-section">
          <input 
            type="text" 
            v-model="amount" 
            class="amount-input" 
            placeholder="0.0"
            inputmode="decimal"
            pattern="[0-9]*"
            readonly
          />
          <div class="currency">CNY</div>
        </div>
      </div>
      
      <!-- 数字键盘 -->
      <NumberKeypad 
        @number-click="addNumber"
        @delete="deleteNumber"
        @save="saveIncome"
      />
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, onActivated, computed } from 'vue'
import { Close } from '@element-plus/icons-vue'
import PageHeader from '../../common/PageHeader.vue'
import NumberKeypad from '../../common/NumberKeypad.vue'
import CategoryItem from '../../common/CategoryItem.vue'
import type { Category } from '../../../data/categories'
import { useAccountStore } from '../../../stores/account'
import db from '../../../database'
import { incomeCategories } from '../../../data/categories'
import { createCreditTransaction } from '../../../services/account/accountService'
import { getCurrentISOString, formatForDB } from '../../../utils/timezone'

const emit = defineEmits(['navigate'])

// 金额
const amount = ref('')
const remark = ref('')

// 计算器状态
const calculator = ref({
  display: '',      // 当前显示的内容（表达式）
  currentInput: '', // 当前输入的数字
  previousInput: '',// 上一个输入的数字
  operator: '',     // 当前操作符
  isResult: false   // 是否显示结果
})

// 账户选择
const showAccountSelector = ref(false)
const selectedAccount = ref('账户')

// 账户store
const accountStore = useAccountStore()

// 获取选中的分类信息
const selectedCategory = computed(() => {
  return categories.value.find(c => c.id === selectedCategoryId.value)
})

// 从store获取账户列表（收入只允许流入流动储蓄账户和信用卡）
const accounts = computed(() => {
  return accountStore.accounts.filter(account => {
    // 流动资金账户始终允许（收入流入）
    if (account.is_liquid) return true
    // 信用卡允许（还款）
    if (account.type === '信用卡') return true
    
    return false
  })
})

// 打开账户选择抽屉
const openAccountSelector = async () => {
  // 加载账户数据
  await loadAccounts()
  showAccountSelector.value = true
}

// 选择账户
const selectAccount = (account: { name: string }) => {
  selectedAccount.value = account.name
  showAccountSelector.value = false
}

// 日期时间选择
const showDateTimeSelector = ref(false)
const selectedDateTime = ref(getCurrentISOString().slice(0, 16)) // 默认当前时间(UTC+8)
const formattedDateTime = ref('')

// 初始化日期时间格式
const initDateTime = () => {
  updateDateTime()
}

// 更新日期时间格式
const updateDateTime = () => {
  const date = new Date(selectedDateTime.value)
  const now = new Date(getCurrentISOString())
  const isToday = date.toDateString() === now.toDateString()
  
  if (isToday) {
    formattedDateTime.value = `今天 ${date.getHours().toString().padStart(2, '0')}:${date.getMinutes().toString().padStart(2, '0')}`
  } else {
    formattedDateTime.value = `${date.getMonth() + 1}月${date.getDate()}日 ${date.getHours().toString().padStart(2, '0')}:${date.getMinutes().toString().padStart(2, '0')}`
  }
}

// 确认日期时间
const confirmDateTime = () => {
  updateDateTime()
  showDateTimeSelector.value = false
}

// 分类数据
const categories = ref<Category[]>([])

// 选中的分类ID
const selectedCategoryId = ref<string>('')

// 选择分类
const selectCategory = (id: string) => {
  selectedCategoryId.value = id
}

// 加载分类数据
const loadCategories = async () => {
  try {
    // 获取收入分类
    categories.value = incomeCategories
  } catch (error) {
    console.error('Error loading categories:', error)
  }
}

// 初始化
initDateTime()

// 组件挂载时加载分类数据和账户数据
onMounted(() => {
  loadCategories()
  loadAccounts()
})

// 组件被激活时重新加载数据（例如从其他页面返回时）
onActivated(() => {
  loadCategories()
  loadAccounts()
})

// 加载账户数据
const loadAccounts = async () => {
  try {
    await accountStore.loadAccounts()
  } catch (error) {
    console.error('Error loading accounts:', error)
  }
}

// 添加数字
const addNumber = (num: string) => {
  if (num === 'AC') {
    // 重置计算器
    calculator.value = {
      display: '',
      currentInput: '',
      previousInput: '',
      operator: '',
      isResult: false
    }
    amount.value = ''
    return
  }
  
  // 处理操作符 + 和 -
  if (num === '+' || num === '-') {
    // 如果当前输入为空且没有操作符，且点击的是"-"，则作为负号处理
    if (num === '-' && calculator.value.currentInput === '' && !calculator.value.operator) {
      calculator.value.currentInput = '-'
      updateDisplay()
      return
    }
    
    // 如果已有操作符且已有当前输入，先计算
    if (calculator.value.operator && calculator.value.currentInput) {
      calculate()
    }
    
    // 设置操作符
    calculator.value.operator = num
    calculator.value.previousInput = calculator.value.currentInput || calculator.value.display
    calculator.value.currentInput = ''
    updateDisplay()
    return
  }
  
  // 处理小数点
  if (num === '.') {
    if (calculator.value.currentInput.includes('.')) {
      return
    }
    if (calculator.value.currentInput === '') {
      calculator.value.currentInput = '0.'
    } else {
      calculator.value.currentInput += '.'
    }
    updateDisplay()
    return
  }
  
  // 如果是显示结果后输入数字，重新开始
  if (calculator.value.isResult) {
    calculator.value.currentInput = num
    calculator.value.isResult = false
  } else {
    // 追加数字
    calculator.value.currentInput += num
  }
  updateDisplay()
}

// 更新显示
const updateDisplay = () => {
  if (calculator.value.operator) {
    amount.value = `${calculator.value.previousInput} ${calculator.value.operator} ${calculator.value.currentInput}`
  } else {
    amount.value = calculator.value.currentInput
  }
}

// 计算结果
const calculate = () => {
  if (!calculator.value.operator || !calculator.value.previousInput || !calculator.value.currentInput) {
    return
  }
  
  const prev = parseFloat(calculator.value.previousInput)
  const current = parseFloat(calculator.value.currentInput)
  let result = 0
  
  switch (calculator.value.operator) {
    case '+':
      result = prev + current
      break
    case '-':
      result = prev - current
      break
  }
  
  // 格式化结果，最多保留2位小数
  calculator.value.display = result.toFixed(2).replace(/\.?0+$/, '')
  calculator.value.currentInput = calculator.value.display
  calculator.value.previousInput = ''
  calculator.value.operator = ''
  calculator.value.isResult = true
  amount.value = calculator.value.display
}

// 删除数字
const deleteNumber = () => {
  if (calculator.value.isResult) {
    // 如果是结果状态，清空所有
    calculator.value = {
      display: '',
      currentInput: '',
      previousInput: '',
      operator: '',
      isResult: false
    }
    amount.value = ''
    return
  }
  
  if (calculator.value.currentInput.length > 0) {
    calculator.value.currentInput = calculator.value.currentInput.slice(0, -1)
    updateDisplay()
  } else if (calculator.value.operator) {
    calculator.value.operator = ''
    calculator.value.currentInput = calculator.value.previousInput
    calculator.value.previousInput = ''
    updateDisplay()
  }
}

// 保存收入
const saveIncome = async () => {
  if (selectedAccount.value === '账户') {
    alert('请选择账户')
    return
  }
  if (!selectedCategoryId.value) {
    alert('请选择收入类型')
    return
  }
  if (!amount.value) {
    alert('请输入金额')
    return
  }

  if (calculator.value.operator && calculator.value.currentInput) {
    calculate()
  }

  const finalAmount = calculator.value.display || calculator.value.currentInput || amount.value
  const amountNumber = parseFloat(finalAmount)

  if (isNaN(amountNumber) || amountNumber <= 0) {
    alert('请输入有效的金额')
    return
  }

  const selectedAccountObj = accountStore.accounts.find(account => account.name === selectedAccount.value)
  if (!selectedAccountObj) {
    alert('选中的账户不存在')
    return
  }

  try {
    await db.connect()

    const transactionId = Date.now().toString()
    const relatedId = transactionId
    
    // 使用账户入账接口 - 自动处理余额更新
    const creditResult = await createCreditTransaction(
      selectedAccountObj.id,
      amountNumber,
      `收入：${selectedCategory.value?.name || ' '}${remark.value ? '：' + remark.value : ''}`,
      transactionId,
      new Date(selectedDateTime.value)
    )
    
    const statements = []
    
    // 添加账户入账相关的SQL语句
    statements.push(...creditResult.statements)
    
    // 添加收入流水记录
    const record = {
      statement: `INSERT INTO transactions 
         (id, type, sub_type, amount, account_id, related_id, balance_after, remark, created_at) 
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      values: [
          transactionId,
          '账户收入',
          selectedCategoryId.value,
          amountNumber,
          selectedAccountObj.id,
          relatedId,
          creditResult.balanceAfter,
          remark.value,
          formatForDB(selectedDateTime.value)
        ]
    }
    statements.push(record)

    // ==============================================
    // 这里是 Capacitor SQLite 正确事务写法
    // ==============================================
    await db.executeTransaction(statements)

    // 执行到这里 = 事务已自动提交 
    await accountStore.loadAccounts()
    console.log('保存收入成功（事务安全）')

  } catch (error: any) {
    // 执行到这里 = 事务已自动回滚 
    console.error('保存失败，已自动回滚:', error)
    alert(error.message || '保存失败，请重试')
    return
  }

  // 重置
  calculator.value = {
    display: '',
    currentInput: '',
    previousInput: '',
    operator: '',
    isResult: false
  }
  amount.value = ''

  emit('navigate', 'income')
}

// 返回
const goBack = () => {
  emit('navigate', 'income')
}
</script>

<style scoped>
.add-income-page {
  height: 100%;
  width: 100%;
  display: flex;
  flex-direction: column;
  background-color: #f5f7fa;
  position: relative;
  overflow: hidden;
  box-sizing: border-box;
}

/* 中间内容区域 */
.content-section {
  flex: 1;
  overflow-y: auto;
  overflow-x: hidden;
  margin-bottom: 0;
  position: relative;
}

/* 底部固定区域 */
.bottom-fixed-section {
  background-color: white;
  border-top: 1px solid #e0e0e0;
  z-index: 99;
  box-sizing: border-box;
  flex-shrink: 0;
}

/* 隐藏滚动条但保留滚动功能 */
.content-section::-webkit-scrollbar {
  display: none;
}

.content-section {
  -ms-overflow-style: none;
  scrollbar-width: none;
}

/* 中间内容区域 */
.category-section {
  padding: 20px 0;
  background-color: white;
  margin-bottom: 0;
}

.category-grid {
  display: grid;
  grid-template-columns: repeat(5, 1fr);
  gap: 12px;
}

/* 备注和金额行 */
.remark-amount-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 8px 14px;
  border-bottom: 1px solid #f0f0f0;
}

/* 备注输入 */
.remark-section {
  flex: 1;
  margin-right: 16px;
}

.remark-input {
  font-size: 14px;
  color: #333333;
  min-height: 20px;
  outline: none;
  padding: 4px 0;
  border: none;

}

.remark-input[contenteditable]:empty:before {
  content: attr(placeholder);
  color: #aca7a7;
  pointer-events: none;
}

.remark-input::placeholder {
  color: #aca7a7;
}

/* 金额显示 */
.amount-section {
  display: flex;
  align-items: baseline;
  gap: 8px;
  white-space: nowrap;
}

.amount-input {
  font-size: 24px;
  font-weight: bold;
  color: #333333;
  border: none;
  outline: none;
  text-align: right;
  width: 120px;
  background: transparent;
}

.amount-input::placeholder {
  color: #999999;
  font-weight: normal;
}

.amount-input::-webkit-outer-spin-button,
.amount-input::-webkit-inner-spin-button {
  -webkit-appearance: none;
  margin: 0;
}

.amount-input[type=number] {
  -moz-appearance: textfield;
}

.currency {
  font-size: 14px;
  color: #666666;
}

/* 支付方式和日期 */
.payment-section {
  display: flex;
  padding: 8px 14px;
  justify-content: space-between;
  border-bottom: 1px solid #f0f0f0;
}

.payment-item {
  font-size: 14px;
  color: #333333;
  white-space: nowrap;
}

/* 账户选择器样式 */
.account-selector {
  color: #333333;
  font-weight: 500;
  cursor: pointer;
}

/* 账户选择抽屉 */
.account-selector-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background-color: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: flex-end;
  justify-content: center;
  z-index: 1000;
  animation: fadeIn 0.3s ease;
}

.account-selector-dialog {
  background-color: white;
  border-radius: 16px 16px 0 0;
  width: 100%;
  max-height: 40vh;
  overflow: hidden;
  animation: slideUp 0.3s ease;
}

/* 动画效果 */
@keyframes fadeIn {
  from { opacity: 0; }
  to { opacity: 1; }
}

@keyframes slideUp {
  from { transform: translateY(100%); }
  to { transform: translateY(0); }
}

.dialog-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 16px;
  border-bottom: 1px solid #f0f0f0;
}

.dialog-title {
  font-size: 16px;
  font-weight: 600;
  color: #333333;
}

.dialog-body {
  max-height: 300px;
  overflow-y: auto;
}

.account-item {
  padding: 16px;
  border-bottom: 1px solid #f0f0f0;
  cursor: pointer;
  transition: background-color 0.2s ease;
}

.account-item:hover {
  background-color: #f5f5f5;
}

.account-name {
  font-size: 16px;
  font-weight: 500;
  color: #333333;
  margin-bottom: 4px;
}

.account-balance {
  font-size: 14px;
  color: #666666;
}

.no-accounts {
  padding: 40px 16px;
  text-align: center;
  color: #999999;
  font-size: 14px;
}

.dialog-header :deep(el-icon) {
  font-size: 20px;
  color: #666666;
  cursor: pointer;
}

/* 日期时间选择器样式 */
.date-time-selector {
  color: #333333;
  font-weight: 500;
  cursor: pointer;
}

/* 日期时间选择抽屉 */
.date-time-selector-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background-color: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: flex-end;
  justify-content: center;
  z-index: 1000;
  animation: fadeIn 0.3s ease;
}

.date-time-selector-dialog {
  background-color: white;
  border-radius: 16px 16px 0 0;
  width: 100%;
  max-height: 40vh;
  overflow: hidden;
  animation: slideUp 0.3s ease;
}

.date-time-picker {
  padding: 20px;
}

.datetime-input {
  width: 100%;
  padding: 12px;
  border: 1px solid #e0e0e0;
  border-radius: 8px;
  font-size: 16px;
  box-sizing: border-box;
}

.dialog-actions {
  display: flex;
  justify-content: flex-end;
  padding: 16px;
  border-top: 1px solid #f0f0f0;
  gap: 12px;
}

.cancel-btn {
  padding: 8px 16px;
  border: 1px solid #e0e0e0;
  border-radius: 6px;
  background-color: white;
  color: #666666;
  font-size: 14px;
  cursor: pointer;
  transition: all 0.2s ease;
}

.cancel-btn:hover {
  background-color: #f5f5f5;
}

.confirm-btn {
  padding: 8px 16px;
  border: none;
  border-radius: 6px;
  background-color: #f56c6c;
  color: white;
  font-size: 14px;
  cursor: pointer;
  transition: all 0.2s ease;
}

.confirm-btn:hover {
  background-color: #e64c4c;
}

/* 响应式设计 */
@media (max-width: 375px) {
  .category-grid {
    gap: 12px;
  }
  
  .category-icon {
    width: 40px;
    height: 40px;
    font-size: 16px;
  }
  
  .category-name {
    font-size: 10px;
  }
  
  .amount-input {
    font-size: 20px;
  }
  
  .keypad-item {
    height: 50px;
    font-size: 18px;
  }
}

@media (max-width: 320px) {
  .category-grid {
    gap: 10px;
  }
  
  .category-icon {
    width: 36px;
    height: 36px;
    font-size: 14px;
  }
  
  .category-name {
    font-size: 9px;
  }
  
  .amount-input {
    font-size: 18px;
  }
  
  .keypad-item {
    height: 44px;
    font-size: 16px;
  }
}
</style>
