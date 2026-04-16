<template>
  <div class="account-detail-page">
    <!-- 顶部导航栏 -->
    <div class="account-detail-header">
      <div class="header-left" @click="goBack">
        <el-icon><ArrowLeft /></el-icon>
      </div>
      <h1 class="header-title">账户详情</h1>
      <div class="header-right"></div>
    </div>

    <!-- 账户基本信息 -->
    <div class="account-basic-info">
      <h2 class="account-name">{{ accountInfo.name }}</h2>
      <div class="account-type">{{ accountInfo.type }}</div>

      <!-- 非信用卡显示余额 -->
      <template v-if="accountInfo.type !== '信用卡'">
        <div class="account-amount">
          <div class="amount-label">账户余额(元)</div>
          <div class="amount-value">¥{{ accountInfo.balance.toFixed(2) }}</div>
        </div>
        <div class="account-remark" v-if="accountInfo.remark">
          <div class="remark-label">备注</div>
          <div class="remark-value">{{ accountInfo.remark }}</div>
        </div>
      </template>

      <!-- 信用卡显示额度信息 -->
      <template v-else>
        <div class="account-amount">
          <div class="amount-label">已用额度(元)</div>
          <div class="amount-value" :class="{ 'negative': accountInfo.used_limit > 0 }">
            ¥{{ (accountInfo.used_limit || 0).toFixed(2) }}
          </div>
        </div>
        <div class="account-returns">
          <div class="return-item">
            <div class="return-label">总额度</div>
            <div class="return-value">¥{{ (accountInfo.total_limit || 0).toFixed(2) }}</div>
          </div>
          <div class="return-item">
            <div class="return-label">剩余额度</div>
            <div class="return-value positive">
              ¥{{ ((accountInfo.total_limit || 0) - (accountInfo.used_limit || 0)).toFixed(2) }}
            </div>
          </div>
        </div>
        <div class="account-remark" v-if="accountInfo.remark">
          <div class="remark-label">备注</div>
          <div class="remark-value">{{ accountInfo.remark }}</div>
        </div>
      </template>
    </div>

    <!-- 交易记录明细 -->
    <div class="account-transactions">
      <!-- Tab切换 - 非信用卡账户 -->
      <el-tabs v-if="accountInfo.type !== '信用卡'" v-model="activeTab" class="transaction-tabs" type="card">
        <!-- 入账记录 -->
        <el-tab-pane label="入账记录" name="income">
          <div class="transaction-list">
            <div v-if="incomeTransactions.length === 0" class="no-transactions">
              <el-empty description="暂无入账记录" />
            </div>
            <div v-else>
              <div v-for="transaction in incomeTransactions" :key="transaction.id" class="transaction-card">
                <div class="transaction-header">
                  <div class="transaction-type income">入账</div>
                  <div class="transaction-date">{{ formatDate(transaction.transaction_time) }}</div>
                </div>
                <div class="transaction-content">
                  <div class="transaction-item">
                    <span class="item-label">金额</span>
                    <span class="item-value positive">+¥{{ transaction.amount.toFixed(2) }}</span>
                  </div>
                  <div class="transaction-item">
                    <span class="item-label">余额</span>
                    <span class="item-value">¥{{ transaction.balance_after.toFixed(2) }}</span>
                  </div>
                  <div class="transaction-item" v-if="transaction.description">
                    <span class="item-label">描述</span>
                    <span class="item-value">{{ transaction.description }}</span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </el-tab-pane>

        <!-- 出账记录 -->
        <el-tab-pane label="出账记录" name="expense">
          <div class="transaction-list">
            <div v-if="expenseTransactions.length === 0" class="no-transactions">
              <el-empty description="暂无出账记录" />
            </div>
            <div v-else>
              <div v-for="transaction in expenseTransactions" :key="transaction.id" class="transaction-card">
                <div class="transaction-header">
                  <div class="transaction-type expense">出账</div>
                  <div class="transaction-date">{{ formatDate(transaction.transaction_time) }}</div>
                </div>
                <div class="transaction-content">
                  <div class="transaction-item">
                    <span class="item-label">金额</span>
                    <span class="item-value negative">-¥{{ transaction.amount.toFixed(2) }}</span>
                  </div>
                  <div class="transaction-item">
                    <span class="item-label">余额</span>
                    <span class="item-value">¥{{ transaction.balance_after.toFixed(2) }}</span>
                  </div>
                  <div class="transaction-item" v-if="transaction.description">
                    <span class="item-label">描述</span>
                    <span class="item-value">{{ transaction.description }}</span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </el-tab-pane>
      </el-tabs>

      <!-- Tab切换 - 信用卡账户 -->
      <el-tabs v-else v-model="activeTab" class="transaction-tabs" type="card">
        <!-- 借款记录 (出账记录) -->
        <el-tab-pane label="借款记录" name="borrow">
          <div class="transaction-list">
            <div v-if="borrowTransactions.length === 0" class="no-transactions">
              <el-empty description="暂无借款记录" />
            </div>
            <div v-else>
              <div v-for="transaction in borrowTransactions" :key="transaction.id" class="transaction-card">
                <div class="transaction-header">
                  <div class="transaction-type expense">借款</div>
                  <div class="transaction-date">{{ formatDate(transaction.transaction_time) }}</div>
                </div>
                <div class="transaction-content">
                  <div class="transaction-item">
                    <span class="item-label">金额</span>
                    <span class="item-value negative">-¥{{ transaction.amount.toFixed(2) }}</span>
                  </div>
                  <div class="transaction-item">
                    <span class="item-label">已用额度</span>
                    <span class="item-value">¥{{ transaction.balance_after.toFixed(2) }}</span>
                  </div>
                  <div class="transaction-item" v-if="transaction.description">
                    <span class="item-label">描述</span>
                    <span class="item-value">{{ transaction.description }}</span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </el-tab-pane>

        <!-- 还款记录 (入账记录) -->
        <el-tab-pane label="还款记录" name="repay">
          <div class="transaction-list">
            <div v-if="repayTransactions.length === 0" class="no-transactions">
              <el-empty description="暂无还款记录" />
            </div>
            <div v-else>
              <div v-for="transaction in repayTransactions" :key="transaction.id" class="transaction-card">
                <div class="transaction-header">
                  <div class="transaction-type income">还款</div>
                  <div class="transaction-date">{{ formatDate(transaction.transaction_time) }}</div>
                </div>
                <div class="transaction-content">
                  <div class="transaction-item">
                    <span class="item-label">金额</span>
                    <span class="item-value positive">+¥{{ transaction.amount.toFixed(2) }}</span>
                  </div>
                  <div class="transaction-item">
                    <span class="item-label">已用额度</span>
                    <span class="item-value">¥{{ transaction.balance_after.toFixed(2) }}</span>
                  </div>
                  <div class="transaction-item" v-if="transaction.description">
                    <span class="item-label">描述</span>
                    <span class="item-value">{{ transaction.description }}</span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </el-tab-pane>
      </el-tabs>
    </div>

    <!-- 悬浮操作按钮 -->
    <FloatingActionMenu :buttons="actionButtons" />
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, computed } from 'vue';
import { ArrowLeft, CircleClose, Money, Edit } from '@element-plus/icons-vue';
import { ElMessageBox, ElMessage } from 'element-plus';
import FloatingActionMenu from '../../../components/common/FloatingActionMenu.vue';
import {
  getAccountById,
  getAccountTransactions,
  deactivateAccount,
  deactivateCreditCard
} from '../../../services/account/accountService';
import type { Account, AccountTransaction } from '../../../types/account/account';

const props = defineProps({
  accountId: {
    type: String,
    required: true
  }
});

const emit = defineEmits(['navigate']);

// 账户信息
const accountInfo = ref<Account>({
  id: '',
  name: '',
  type: '',
  balance: 0,
  used_limit: 0,
  total_limit: 0,
  is_liquid: true,
  remark: ''
});

// 当前激活的标签
const activeTab = ref('income');

// 交易记录数据
const allTransactions = ref<AccountTransaction[]>([]);

// 非信用卡交易记录
const incomeTransactions = computed(() => {
  return allTransactions.value.filter(t => t.type === '收入');
});

const expenseTransactions = computed(() => {
  return allTransactions.value.filter(t => t.type === '支出');
});

// 信用卡交易记录（借款=支出，还款=收入）
const borrowTransactions = computed(() => {
  return allTransactions.value.filter(t => t.type === '支出');
});

const repayTransactions = computed(() => {
  return allTransactions.value.filter(t => t.type === '收入');
});

// 返回上一页
const goBack = () => {
  emit('navigate', 'account');
};

// 格式化日期函数
const formatDate = (dateString: string | Date) => {
  const date = new Date(dateString);
  return date.toLocaleString('zh-CN', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit'
  });
};

// 加载账户详情数据
const loadAccountDetail = async () => {
  console.log('Loading account detail for:', props.accountId);

  try {
    const account = await getAccountById(props.accountId);
    if (account) {
      accountInfo.value = account;
    }

    // 加载交易记录
    allTransactions.value = await getAccountTransactions(props.accountId);

    console.log('Account loaded:', accountInfo.value);
    console.log('Transactions loaded:', allTransactions.value);
  } catch (error) {
    console.error('Error loading account detail:', error);
    ElMessage.error('加载账户详情失败');
  }
};

// 停用账户
const handleDeactivate = async () => {
  try {
    await ElMessageBox.confirm(
      '确定要停用该账户吗？停用后账户将不再显示在列表中。',
      '确认停用',
      {
        confirmButtonText: '确认停用',
        cancelButtonText: '取消',
        type: 'warning'
      }
    );

    if (accountInfo.value.type === '信用卡') {
      // 信用卡停用校验
      await deactivateCreditCard(props.accountId);
      ElMessage.success('信用卡已停用');
    } else {
      // 普通账户停用校验
      await deactivateAccount(props.accountId);
      ElMessage.success('账户已停用');
    }

    // 停用成功后返回账户列表
    emit('navigate', 'account');
  } catch (error: any) {
    if (error !== 'cancel') {
      console.error('停用账户失败:', error);
      ElMessage.error(error.message || '停用账户失败');
    }
  }
};

// 跳转还款页面
const navigateToRepay = () => {
  emit('navigate', { key: 'repayCreditCard', params: { accountId: props.accountId } });
};

// 编辑账户信息
const editAccountInfo = () => {
  // 可以扩展为打开编辑对话框
  ElMessage.info('编辑功能开发中...');
};

// 定义按钮列表
const actionButtons = computed(() => {
  const buttons = [
    {
      text: '停用',
      icon: CircleClose,
      action: handleDeactivate
    },
    {
      text: '编辑',
      icon: Edit,
      action: editAccountInfo
    }
  ];

  // 信用卡添加还款按钮
  if (accountInfo.value.type === '信用卡') {
    buttons.unshift({
      text: '还款',
      icon: Money,
      action: navigateToRepay
    });
  }

  return buttons;
});

onMounted(() => {
  loadAccountDetail();
});
</script>

<style scoped>
.account-detail-page {
  height: 100%;
  background-color: #f5f7fa;
  display: flex;
  flex-direction: column;
}

/* 顶部导航栏 */
.account-detail-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 15px;
  background-color: #ffffff;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
}

.header-left,
.header-right {
  width: 40px;
  height: 40px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.header-title {
  font-size: 18px;
  font-weight: 600;
  color: #333333;
  margin: 0;
}

/* 账户基本信息 */
.account-basic-info {
  padding: 20px 30px;
  background-color: #ffffff;
  margin-bottom: 10px;
}

.account-name {
  font-size: 18px;
  font-weight: 600;
  color: #333333;
  margin: 0 0 10px 0;
}

.account-type {
  font-size: 14px;
  color: #666666;
  margin-bottom: 20px;
}

.account-amount {
  text-align: center;
  margin-bottom: 20px;
}

.amount-label {
  font-size: 14px;
  color: #666666;
  margin-bottom: 5px;
}

.amount-value {
  font-size: 32px;
  font-weight: 700;
  color: #333333;
}

.amount-value.negative {
  color: #ff6b6b;
}

.account-returns {
  display: flex;
  justify-content: space-around;
  border-top: 1px solid #f0f0f0;
  padding-top: 15px;
  margin-bottom: 15px;
}

.return-item {
  text-align: center;
}

.return-label {
  font-size: 12px;
  color: #666666;
  margin-bottom: 5px;
}

.return-value {
  font-size: 14px;
  font-weight: 600;
  color: #333333;
}

.return-value.positive {
  color: #67c23a;
}

.return-value.negative {
  color: #ff6b6b;
}

.account-remark {
  border-top: 1px solid #f0f0f0;
  padding-top: 15px;
}

.remark-label {
  font-size: 12px;
  color: #666666;
  margin-bottom: 5px;
}

.remark-value {
  font-size: 14px;
  color: #333333;
}

/* 交易记录明细 */
.account-transactions {
  padding: 15px;
  background-color: #ffffff;
  margin-bottom: 80px;
  flex: 1;
  overflow-y: auto;
}

/* Tab样式 */
.transaction-tabs {
  margin-bottom: 15px;
}

.transaction-tabs :deep(.el-tabs__nav) {
  width: 100%;
  display: flex;
}

.transaction-tabs :deep(.el-tabs__item) {
  flex: 1;
  text-align: center;
}

.no-transactions {
  padding: 20px 0;
  text-align: center;
}

.transaction-list {
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.transaction-card {
  background-color: #f9f9f9;
  border-radius: 8px;
  padding: 15px;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.05);
}

.transaction-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 10px;
  padding-bottom: 10px;
  border-bottom: 1px solid #f0f0f0;
}

.transaction-type {
  padding: 2px 8px;
  border-radius: 10px;
  font-size: 12px;
  font-weight: 600;
}

.transaction-type.income {
  background-color: #e6f7ff;
  color: #1890ff;
}

.transaction-type.expense {
  background-color: #fff1f0;
  color: #ff4d4f;
}

.transaction-date {
  font-size: 12px;
  color: #999999;
}

.transaction-content {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.transaction-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.item-label {
  font-size: 14px;
  color: #666666;
}

.item-value {
  font-size: 14px;
  color: #333333;
  font-weight: 500;
}

.item-value.positive {
  color: #67c23a;
}

.item-value.negative {
  color: #ff6b6b;
}
</style>
