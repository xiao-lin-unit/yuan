<template>
  <div class="account-management">
    <!-- 净资产部分 -->
    <div class="net-worth-section">
      <div class="net-worth-header">
        <span>净资产</span>
        <el-icon class="eye-icon"><View /></el-icon>
      </div>
      <div class="net-worth-amount">{{ formatCurrency(netWorth) }}</div>
      <div class="assets-liabilities">
        <div class="asset-item">
          <div class="asset-label">总资产</div>
          <div class="asset-value">{{ formatCurrency(totalAssets) }}</div>
        </div>
        <div class="asset-item">
          <div class="asset-label">总负债</div>
          <div class="liability-value">{{ formatCurrency(totalLiabilities) }}</div>
        </div>
      </div>
    </div>

    <!-- 资产趋势部分 -->
    <div class="asset-trend-section">
      <div class="section-header">
        <span>资产趋势</span>
        <el-icon class="more-icon"><More /></el-icon>
      </div>
      <div class="trend-bar">
        <div class="trend-progress" :style="{ width: trendPercentage + '%' }"></div>
      </div>
      <div class="trend-stats">
        <span>{{ assetsCount }}项资产 | {{ liabilitiesCount }}项负债</span>
        <span>负债率 {{ debtRatio }}%</span>
      </div>
    </div>

    <!-- 借入借出部分 -->
    <div class="borrow-lend-section">
      <div class="borrow-lend-item">
        <div class="borrow-lend-label">总借入</div>
        <div class="borrow-lend-value">{{ formatCurrency(totalBorrowed) }}</div>
      </div>
      <div class="borrow-lend-item">
        <div class="borrow-lend-label">总借出</div>
        <div class="borrow-lend-value">{{ formatCurrency(totalLent) }}</div>
      </div>
    </div>

    <!-- 信用卡部分 -->
    <div class="credit-card-section">
      <div class="section-header" @click="toggleCreditCard">
        <span>信用卡</span>
        <div class="section-header-right">
          <span class="total-liability">{{ formatCurrency(totalLiabilities) }}</span>
          <el-icon class="arrow-icon" :class="{ 'rotated': !isCreditCardExpanded }"><ArrowDown /></el-icon>
        </div>
      </div>

      <CreditCardItem v-for="card in creditCards" :key="card.id" :card="card" v-if="isCreditCardExpanded" />
    </div>

    <!-- 资金部分 -->
    <div class="fund-section">
      <div class="section-header" @click="toggleFund">
        <span>流动资金</span>
        <div class="section-header-right">
          <span class="total-fund">{{ formatCurrency(totalFunds) }}</span>
          <el-icon class="arrow-icon" :class="{ 'rotated': !isFundExpanded }"><ArrowDown /></el-icon>
        </div>
      </div>
      <FundItem v-for="fund in funds" :key="fund.id" :fund="fund" v-if="isFundExpanded" />
    </div>

    <!-- 其他资金部分 -->
    <div class="fund-section">
      <div class="section-header" @click="toggleOtherFund">
        <span>其他资金</span>
        <div class="section-header-right">
          <span class="total-fund">{{ formatCurrency(totalOtherFunds) }}</span>
          <el-icon class="arrow-icon" :class="{ 'rotated': !isOtherFundExpanded }"><ArrowDown /></el-icon>
        </div>
      </div>
      <FundItem v-for="fund in otherFunds" :key="fund.id" :fund="fund" v-if="isOtherFundExpanded" />
    </div>

    <!-- 浮动操作按钮 -->
    <FloatingActionMenu :buttons="actionButtons" />


    
    <!-- 编辑账户对话框 -->
    <el-dialog v-model="dialogVisible.edit" title="编辑账户" width="500px">
      <el-form :model="accountForm" label-width="80px">
        <el-form-item label="账户名称">
          <el-input v-model="accountForm.name" placeholder="请输入账户名称" />
        </el-form-item>
        <el-form-item label="账户类型">
          <el-select v-model="accountForm.type" placeholder="请选择账户类型">
            <el-option label="现金" value="现金" />
            <el-option label="微信" value="微信" />
            <el-option label="支付宝" value="支付宝" />
            <el-option label="储蓄卡" value="储蓄卡" />
            <el-option label="社保卡" value="社保卡" />
            <el-option label="信用卡" value="信用卡" />
          </el-select>
        </el-form-item>
        <el-form-item label="余额" v-if="accountForm.type !== '信用卡'">
          <el-input v-model.number="accountForm.balance" placeholder="请输入余额" type="number" step="0.01" />
        </el-form-item>
        <el-form-item label="已用额度" v-if="accountForm.type === '信用卡'">
          <el-input v-model.number="accountForm.usedLimit" placeholder="请输入已用额度" type="number" step="0.01" />
        </el-form-item>
        <el-form-item label="总额度" v-if="accountForm.type === '信用卡'">
          <el-input v-model.number="accountForm.totalLimit" placeholder="请输入总额度" type="number" step="0.01" />
        </el-form-item>
        <el-form-item label="流动资金" v-if="accountForm.type !== '信用卡' && accountForm.type !== '社保卡'">
          <el-switch v-model="accountForm.isLiquid" />
        </el-form-item>
        <el-form-item label="备注">
          <el-input v-model="accountForm.remark" placeholder="请输入备注" />
        </el-form-item>
      </el-form>
      <template #footer>
        <span class="dialog-footer">
          <el-button @click="dialogVisible.edit = false">取消</el-button>
          <el-button type="primary" @click="updateAccount">确定</el-button>
        </span>
      </template>
    </el-dialog>
    
    <!-- 余额调整对话框 -->
    <el-dialog v-model="dialogVisible.adjust" title="余额调整" width="500px">
      <el-form :model="adjustForm" label-width="80px">
        <el-form-item label="调整类型">
          <el-select v-model="adjustForm.type" placeholder="请选择调整类型">
            <el-option label="修正错误" value="修正错误" />
            <el-option label="现金赠与" value="现金赠与" />
            <el-option label="资产盘盈" value="资产盘盈" />
          </el-select>
        </el-form-item>
        <el-form-item label="调整金额">
          <el-input v-model.number="adjustForm.amount" placeholder="请输入调整金额" type="number" step="0.01" />
        </el-form-item>
        <el-form-item label="备注">
          <el-input v-model="adjustForm.remark" placeholder="请输入备注" />
        </el-form-item>
      </el-form>
      <template #footer>
        <span class="dialog-footer">
          <el-button @click="dialogVisible.adjust = false">取消</el-button>
          <el-button type="primary" @click="adjustBalance">确定</el-button>
        </span>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, onActivated, computed } from 'vue'
import { useAccountStore } from '../../../stores/account'
import CreditCardItem from './CreditCardItem.vue'
import FundItem from './FundItem.vue'
import FloatingActionMenu from '../../common/FloatingActionMenu.vue'
import { ArrowDown, View, More, Plus, RefreshLeft, DataLine } from '@element-plus/icons-vue'

const emit = defineEmits(['navigate'])

const accountStore = useAccountStore()

const dialogVisible = ref({
  add: false,
  edit: false,
  adjust: false
})

const accountForm = ref({
  id: '',
  name: '',
  type: '',
  balance: 0,
  usedLimit: 0,
  totalLimit: 0,
  isLiquid: true,
  remark: ''
})

const adjustForm = ref({
  accountId: '',
  type: '',
  amount: 0,
  remark: ''
})

// 计算数据
const totalAssets = computed(() => {
  return accountStore.accounts.reduce((total, account) => {
    if (account.balance > 0 && account.is_liquid !== 0 && account.is_liquid !== false) return total + account.balance
    return total
  }, 0)
})

const totalLiabilities = computed(() => {
  return accountStore.accounts.reduce((total, account) => {
    if (account.type === '信用卡') {
      return total + (account.used_limit || 0)
    } else if (account.balance < 0) {
      return total + Math.abs(account.balance)
    }
    return total
  }, 0)
})

const netWorth = computed(() => {
  return totalAssets.value - totalLiabilities.value
})

const assetsCount = computed(() => {
  return accountStore.accounts.filter(account => account.balance > 0).length
})

const liabilitiesCount = computed(() => {
  return accountStore.accounts.filter(account => account.type === '信用卡' || account.balance < 0).length
})

const debtRatio = computed(() => {
  if (totalAssets.value === 0) return 0
  return ((totalLiabilities.value / totalAssets.value) * 100).toFixed(2)
})

const trendPercentage = computed(() => {
  if (totalAssets.value === 0) return 0
  return (totalLiabilities.value / totalAssets.value) * 100
})

const totalBorrowed = ref(0)
const totalLent = ref(40000)

// 从accounts中计算信用卡和资金数据
const creditCards = computed(() => {
  return accountStore.accounts
    .filter(account => account.type === '信用卡')
    .map(account => ({
      id: account.id,
      name: account.name,
      usedLimit: account.used_limit || 0,
      totalLimit: account.total_limit || 0
    }))
})

const funds = computed(() => {
  return accountStore.accounts
    .filter(account => account.type !== '信用卡' && (account.is_liquid === 1 || account.is_liquid === true || account.is_liquid === undefined || account.is_liquid === null))
    .map(account => ({
      id: account.id,
      name: account.name,
      balance: account.balance
    }))
})

const otherFunds = computed(() => {
  return accountStore.accounts
    .filter(account => account.type !== '信用卡' && (account.is_liquid === 0 || account.is_liquid === false))
    .map(account => ({
      id: account.id,
      name: account.name,
      balance: account.balance
    }))
})

// 计算总资金
const totalFunds = computed(() => {
  return funds.value.reduce((total, fund) => total + fund.balance, 0)
})

const totalOtherFunds = computed(() => {
  return otherFunds.value.reduce((total, fund) => total + fund.balance, 0)
})

// 展开/收起状态
const isCreditCardExpanded = ref(true)
const isFundExpanded = ref(true)
const isOtherFundExpanded = ref(true)

// 切换展开/收起状态
const toggleCreditCard = () => {
  isCreditCardExpanded.value = !isCreditCardExpanded.value
}

const toggleFund = () => {
  isFundExpanded.value = !isFundExpanded.value
}

const toggleOtherFund = () => {
  isOtherFundExpanded.value = !isOtherFundExpanded.value
}

const openAddAccountDialog = () => {
  emit('navigate', 'addAccount')
}

const openTransferDialog = () => {
  // 这里可以添加打开内部转账对话框的逻辑
  console.log('打开内部转账对话框')
}

const openDatabaseViewer = () => {
  emit('navigate', 'databaseViewer')
}

// 定义按钮列表
const actionButtons = [
  {
    text: '新增账户',
    icon: Plus,
    action: openAddAccountDialog
  },
  {
    text: '内部转账',
    icon: RefreshLeft,
    action: openTransferDialog
  },
  {
    text: '数据库查看',
    icon: DataLine,
    action: openDatabaseViewer
  }
];

// 格式化货币
const formatCurrency = (value: number = 0) => {
  return '¥' + value.toLocaleString('zh-CN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
}

onMounted(() => {
  accountStore.loadAccounts()
})

onActivated(() => {
  accountStore.loadAccounts()
})

const openEditAccountDialog = (account: any) => {
  accountForm.value = { 
    ...account,
    usedLimit: account.used_limit || 0,
    totalLimit: account.total_limit || 0,
    isLiquid: account.is_liquid === 1 || account.is_liquid === true
  }
  dialogVisible.value.edit = true
}

const openBalanceAdjustDialog = (account: any) => {
  adjustForm.value = {
    accountId: account.id,
    type: '',
    amount: 0,
    remark: ''
  }
  dialogVisible.value.adjust = true
}



const updateAccount = () => {
  accountStore.updateAccount(accountForm.value)
  dialogVisible.value.edit = false
}

const deleteAccount = (id: string) => {
  accountStore.deleteAccount(id)
}

const adjustBalance = () => {
  accountStore.adjustBalance(adjustForm.value)
  dialogVisible.value.adjust = false
}
</script>

<style scoped>
.account-management {
  padding: 2px;
  position: relative;
  min-height: 100vh;
  background-color: #f5f7fa;
}

/* 净资产部分 */
.net-worth-section {
  background-color: white;
  border-radius: 12px;
  padding: 20px;
  margin-bottom: 20px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.05);
}

.net-worth-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 15px;
}

.net-worth-header span {
  font-size: 16px;
  color: #666666;
}

.eye-icon {
  color: #999999;
  font-size: 18px;
}

.net-worth-amount {
  font-size: 28px;
  font-weight: bold;
  color: #333333;
  margin-bottom: 15px;
  text-align: center;
}

.assets-liabilities {
  display: flex;
  justify-content: space-around;
  padding-top: 15px;
  border-top: 1px solid #f0f0f0;
}

.asset-item {
  text-align: center;
}

.asset-label {
  font-size: 14px;
  color: #666666;
  margin-bottom: 5px;
}

.asset-value {
  font-size: 16px;
  font-weight: bold;
  color: #333333;
}

.liability-value {
  font-size: 16px;
  font-weight: bold;
  color: #67c23a;
}

/* 资产趋势部分 */
.asset-trend-section {
  background-color: white;
  border-radius: 12px;
  padding: 15px;
  margin-bottom: 20px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.05);
}

.section-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 15px;
  cursor: pointer;
  user-select: none;
}

.section-header span {
  font-size: 14px;
  font-weight: bold;
  color: #333333;
}

.section-header-right {
  display: flex;
  align-items: center;
}

.arrow-icon {
  transition: transform 0.3s ease;
}

.arrow-icon.rotated {
  transform: rotate(180deg);
}

.total-liability {
  font-size: 12px;
  color: #67c23a;
  margin-right: 10px;
}

.total-fund {
  font-size: 12px;
  color: #333333;
  margin-right: 10px;
}

.more-icon, .arrow-icon {
  color: #999999;
  font-size: 18px;
}

.trend-bar {
  height: 4px;
  background-color: #f0f0f0;
  border-radius: 2px;
  overflow: hidden;
  margin-bottom: 10px;
}

.trend-progress {
  height: 100%;
  background-color: #67c23a;
  border-radius: 2px;
}

.trend-stats {
  display: flex;
  justify-content: space-between;
  font-size: 14px;
  color: #666666;
  margin-bottom: 10px;
}

/* 借入借出部分 */
.borrow-lend-section {
  display: flex;
  gap: 15px;
  margin-bottom: 20px;
}

.borrow-lend-item {
  flex: 1;
  background-color: white;
  border-radius: 12px;
  padding: 15px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.05);
}

.borrow-lend-icon {
  width: 40px;
  height: 40px;
  border-radius: 50%;
  background-color: #ecf5ff;
  display: flex;
  align-items: center;
  justify-content: center;
  margin-bottom: 12px;
  color: #409eff;
}

.borrow-lend-label {
  font-size: 14px;
  color: #666666;
  margin-bottom: 5px;
}

.borrow-lend-value {
  font-size: 16px;
  font-weight: bold;
  color: #333333;
}

/* 信用卡部分 */
.credit-card-section {
  background-color: white;
  border-radius: 12px;
  padding: 15px;
  margin-bottom: 20px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.05);
}

/* 资金部分 */
.fund-section {
  background-color: white;
  border-radius: 12px;
  padding: 15px;
  margin-bottom: 20px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.05);
}



/* 对话框样式 */
.dialog-footer {
  width: 100%;
  display: flex;
  justify-content: flex-end;
}

/* 响应式设计 */
@media (max-width: 768px) {
  .account-management-mobile {
    padding: 5px;
  }
  
  .net-worth-section {
    padding: 15px;
  }
  
  .net-worth-amount {
    font-size: 24px;
  }
  
  .borrow-lend-section {
    gap: 10px;
  }
  
  .borrow-lend-item {
    padding: 12px;
  }
  
  .credit-card-section,
  .fund-section {
    padding: 12px;
  }
  
  .floating-action-button {
    bottom: 70px;
    right: 15px;
    width: 50px;
    height: 50px;
  }
  
  .floating-action-button deep(el-icon) {
    font-size: 20px;
  }
}

@media (max-width: 320px) {
  .net-worth-amount {
    font-size: 20px;
  }
  
  .card-name,
  .fund-name {
    font-size: 14px;
  }
  
  .card-balance,
  .fund-balance {
    font-size: 14px;
  }
}
</style>