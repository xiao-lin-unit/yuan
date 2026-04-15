<template>
  <div class="fund-detail-page">
    <!-- 顶部导航栏 -->
    <div class="fund-detail-header">
      <div class="header-left" @click="goBack">
        <el-icon><ArrowLeft /></el-icon>
      </div>
      <h1 class="header-title">资产详情</h1>
      <div class="header-right"></div>
    </div>
    
    <!-- 基金基本信息 -->
    <div class="fund-basic-info">
      <h2 class="fund-name">{{ fundInfo.name }}</h2>
      <div class="fund-code-risk">
        <span class="fund-code">{{ fundInfo.code }}</span>
        <!-- <span class="fund-risk">中高风险</span> -->
      </div>
      <div class="fund-amount">
        <div class="amount-label">成本金额(元)</div>
        <div class="amount-value">¥{{ fundInfo.costAmount.toFixed(2) }}</div>
      </div>
      <div class="fund-amount">
        <div class="amount-label">成本费用(元)</div>
        <div class="amount-value">¥{{ fundInfo.costFee.toFixed(2) }}</div>
      </div>
      <div class="fund-returns">
        <div class="return-item">
          <div class="return-label">持有成本</div>
          <div class="return-value">¥{{ fundInfo.costNav.toFixed(4) }}</div>
        </div>
        <div class="return-item">
          <div class="return-label">当前净值</div>
          <div class="return-value">¥{{ fundInfo.currentNav.toFixed(4) }}</div>
        </div>
        <div class="return-item">
          <div class="return-label">持有份额</div>
          <div class="return-value">{{ fundInfo.shares.toFixed(2) }}</div>
        </div>
      </div>
      <div class="fund-returns">
        <div class="return-item">
          <div class="return-label">确认收益</div>
          <div class="return-value positive">+¥{{ fundInfo.confirmedReturn.toFixed(2) }}</div>
        </div>
        <div class="return-item">
          <div class="return-label">持有收益</div>
          <div class="return-value positive">+¥{{ fundInfo.holdReturn.toFixed(2) }}</div>
        </div>
        <div class="return-item">
          <div class="return-label">总收益</div>
          <div class="return-value positive">+¥{{ fundInfo.totalReturn.toFixed(2) }}</div>
        </div>
      </div>
    </div>
    
    <!-- 基金交易记录明细 -->
    <div class="fund-transactions">
      <!-- <h3 class="section-title">交易记录明细</h3> -->
      
      <!-- Tab切换 -->
      <el-tabs v-model="activeTag" class="transaction-tabs" type="card">
        <!-- 持有记录 -->
        <el-tab-pane label="持有记录" name="holdings">
          <div class="transaction-list">
            <div v-if="holdings.length === 0" class="no-transactions">
              <el-empty description="暂无持有记录" />
            </div>
            <div v-else>
              <div v-for="holding in holdings" :key="holding.id" class="transaction-card">
                <div class="transaction-header">
                  <div class="transaction-type buy">持有</div>
                  <div class="transaction-date">{{ formatDate(holding.transaction_time) }}</div>
                </div>
                <div class="transaction-content">
                  <div class="transaction-item">
                    <span class="item-label">净值</span>
                    <span class="item-value">¥{{ (holding.nav || 0).toFixed(4) }}</span>
                  </div>
                  <div class="transaction-item">
                    <span class="item-label">份额</span>
                    <span class="item-value">{{ (holding.shares || 0).toFixed(4) }}</span>
                  </div>
                  <div class="transaction-item">
                    <span class="item-label">剩余份额</span>
                    <span class="item-value">{{ (holding.remaining_shares || 0).toFixed(4) }}</span>
                  </div>
                  <div class="transaction-item">
                    <span class="item-label">手续费</span>
                    <span class="item-value">¥{{ (holding.fee || 0).toFixed(2) }}</span>
                  </div>
                  <div class="transaction-item">
                    <span class="item-label">状态</span>
                    <span class="item-value">{{ holding.sell_status || '未卖出' }}</span>
                  </div>
                  <div v-if="holding.lock_period" class="transaction-item">
                    <span class="item-label">锁定期限</span>
                    <span class="item-value">{{ holding.lock_period }}个月</span>
                  </div>
                  <div v-if="holding.lock_end_date" class="transaction-item">
                    <span class="item-label">锁定结束日期</span>
                    <span class="item-value">{{ formatDate(holding.lock_end_date) }}</span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </el-tab-pane>
        
        <!-- 买入记录 -->
        <el-tab-pane label="买入记录" name="buy">
          <div class="transaction-list">
            <div v-if="buyTransactions.length === 0" class="no-transactions">
              <el-empty description="暂无买入记录" />
            </div>
            <div v-else>
              <div v-for="transaction in buyTransactions" :key="transaction.id" class="transaction-card">
                <div class="transaction-header">
                  <div class="transaction-type buy">买入</div>
                  <div class="transaction-date">{{ formatDate(transaction.transaction_time) }}</div>
                </div>
                <div class="transaction-content">
                  <div class="transaction-item">
                    <span class="item-label">交易净值</span>
                    <span class="item-value">¥{{ (transaction.transaction_nav || 0).toFixed(4) }}</span>
                  </div>
                  <div class="transaction-item">
                    <span class="item-label">交易份额</span>
                    <span class="item-value">{{ (transaction.shares || 0).toFixed(4) }}</span>
                  </div>
                  <div class="transaction-item">
                    <span class="item-label">交易金额</span>
                    <span class="item-value">¥{{ ((transaction.transaction_nav || 0) * (transaction.shares || 0)).toFixed(2) }}</span>
                  </div>
                  <div class="transaction-item">
                    <span class="item-label">手续费</span>
                    <span class="item-value">¥{{ (transaction.fee || 0).toFixed(2) }}</span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </el-tab-pane>
        
        <!-- 卖出记录 -->
        <el-tab-pane label="卖出记录" name="sell">
          <div class="transaction-list">
            <div v-if="sellTransactions.length === 0" class="no-transactions">
              <el-empty description="暂无卖出记录" />
            </div>
            <div v-else>
              <div v-for="transaction in sellTransactions" :key="transaction.id" class="transaction-card">
                <div class="transaction-header">
                  <div class="transaction-type sell">卖出</div>
                  <div class="transaction-date">{{ formatDate(transaction.transaction_time) }}</div>
                </div>
                <div class="transaction-content">
                  <div class="transaction-item">
                    <span class="item-label">交易净值</span>
                    <span class="item-value">¥{{ (transaction.transaction_nav || 0).toFixed(4) }}</span>
                  </div>
                  <div class="transaction-item">
                    <span class="item-label">交易份额</span>
                    <span class="item-value">{{ (transaction.shares || 0).toFixed(4) }}</span>
                  </div>
                  <div class="transaction-item">
                    <span class="item-label">交易金额</span>
                    <span class="item-value">¥{{ ((transaction.transaction_nav || 0) * (transaction.shares || 0)).toFixed(2) }}</span>
                  </div>
                  <div class="transaction-item">
                    <span class="item-label">手续费</span>
                    <span class="item-value">¥{{ (transaction.fee || 0).toFixed(2) }}</span>
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
import { ref, onMounted } from 'vue';
import { ArrowLeft, Plus, Minus, More, Switch, Edit } from '@element-plus/icons-vue';
import { ElMessageBox, ElMessage } from 'element-plus';
import FloatingActionMenu from '../../../components/common/FloatingActionMenu.vue';
import db from '../../../database/index.js';

const props = defineProps({
  fundId: {
    type: String,
    required: true
  }
});

// 跳转到基金二次买入页面
const navigateToBuyFund = () => {
  emit('navigate', { key: 'buyFund', params: { fundId: props.fundId } });
};

// 跳转到基金转换页面
const navigateToConvertFund = () => {
  // 这里可以实现基金转换的逻辑
  console.log('转换基金');
};

// 跳转到基金卖出页面
const navigateToSellFund = () => {
  emit('navigate', { key: 'sellFund', params: { fundId: props.fundId } });
};

// 修改基金净值
const editFundNav = async () => {
  try {
    const { value } = await ElMessageBox.prompt(
      '请输入新的基金净值',
      '修改净值',
      {
        confirmButtonText: '确认',
        cancelButtonText: '取消',
        inputPattern: /^\d+(\.\d{1,4})?$/,
        inputErrorMessage: '请输入有效的净值（最多4位小数）',
        inputValue: fundInfo.value.currentNav.toFixed(4)
      }
    );
    
    const newNav = parseFloat(value);
    if (isNaN(newNav) || newNav <= 0) {
      ElMessage.error('请输入有效的净值');
      return;
    }
    
    // 更新数据库
    await db.run(
      'UPDATE funds SET current_nav = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
      [newNav, props.fundId]
    );
    
    // 更新本地显示
    fundInfo.value.currentNav = newNav;
    
    // 重新计算收益
    await loadFundDetail();
    
    ElMessage.success('净值更新成功');
  } catch (error) {
    if (error !== 'cancel') {
      console.error('修改净值失败:', error);
      ElMessage.error('修改净值失败');
    }
  }
};

// 定义按钮列表
const actionButtons = [
  {
    text: '买入',
    icon: Plus,
    action: navigateToBuyFund
  },
  {
    text: '修改净值',
    icon: Edit,
    action: editFundNav
  },
  // {
  //   text: '转换',
  //   icon: Switch,
  //   action: navigateToConvertFund
  // },
  {
    text: '卖出',
    icon: Minus,
    action: navigateToSellFund
  }
];

const emit = defineEmits(['navigate']);

const fundInfo = ref({
  name: '兴全趋势投资混合(LOF)',
  code: '163402',
  costAmount: 36.13,
  costFee: 0.00,
  costNav: 1.54,
  currentNav: 1.68,
  shares: 21.98,
  confirmedReturn: 10.50,
  holdReturn: 3.23,
  totalReturn: 13.73
});

// 当前激活的标签
const activeTag = ref('holdings');

// 持有记录数据
const holdings = ref([]);

// 买入记录数据
const buyTransactions = ref([]);

// 卖出记录数据
const sellTransactions = ref([]);

const goBack = () => {
  emit('navigate', 'asset');
};

// 格式化日期函数
const formatDate = (dateString) => {
  const date = new Date(dateString);
  return date.toLocaleString('zh-CN', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit'
  });
};

// 加载基金详情数据
const loadFundDetail = async () => {
  console.log('Loading fund detail for:', props.fundId);
  
  try {
    // 连接数据库
    await db.connect();
    
    // 查询基金基本信息
    const fundData = await db.query('SELECT * FROM funds WHERE id = ?', [props.fundId]);
    console.log('Fund data:', JSON.stringify(fundData));
    if (fundData.length > 0) {
      const fund = fundData[0];
      
      // 防御性检查，确保所有必要字段都存在
      const shares = fund.shares;
      const current_nav = fund.current_nav;
      const cost_nav = fund.cost_nav;
      const total_fee = fund.total_fee || 0;
      
      // 计算持有金额
      const costAmount = shares * cost_nav;
      const holdReturn = (current_nav - cost_nav) * shares; // 持有收益 = （当前净值-持有成本净值）* 持有份额
      const confirmedReturn = fund.confirmed_profit || 0; // 确认收益默认为0，只有卖出时才计算
      const totalReturn = holdReturn + confirmedReturn; // 总收益 = 持有收益 + 确认收益
      
      // 更新基金信息
      fundInfo.value = {
        name: fund.name || '未知基金',
        code: fund.code || '',
        costAmount: costAmount,
        costFee: total_fee,
        costNav: cost_nav,
        currentNav: current_nav,
        shares: shares,
        confirmedReturn: confirmedReturn, // 确认收益默认为0，只有卖出时才计算
        holdReturn: holdReturn, // 持有收益 = （当前净值-持有成本净值）* 持有份额
        totalReturn: totalReturn // 总收益 = 持有收益 + 确认收益
      };
      
      console.log('Fund detail loaded:', fundInfo.value);
      
      // 加载持有记录
      await loadHoldings();
      
      // 加载交易记录
      await loadTransactions();
    } else {
      console.error('Fund not found:', props.fundId);
      // 设置默认值，避免模板渲染错误
      fundInfo.value = {
        name: '未知基金',
        code: '',
        costAmount: 0,
        costFee: 0,
        costNav: 0,
        currentNav: 0,
        shares: 0,
        confirmedReturn: 0,
        holdReturn: 0,
        totalReturn: 0
      };
    }
  } catch (error) {
    console.error('Error loading fund detail:', error);
  }
};

// 加载持有记录
const loadHoldings = async () => {
  try {
    // 查询持有记录，按时间倒序
    const holdingData = await db.query(
      'SELECT * FROM fund_holdings WHERE fund_id = ? ORDER BY transaction_time DESC', 
      [props.fundId]
    );
    
    holdings.value = holdingData.map(holding => ({
      ...holding,
      nav: holding.nav || 0,
      shares: holding.shares || 0,
      remaining_shares: holding.remaining_shares || 0,
      fee: holding.fee || 0,
      sell_status: holding.sell_status || '未卖出',
      transaction_time: holding.transaction_time || new Date()
    }));
    
    console.log('Holdings loaded:', holdings.value);
  } catch (error) {
    console.error('Error loading holdings:', error);
  }
};

// 加载交易记录
const loadTransactions = async () => {
  try {
    // 查询交易记录，按时间倒序
    const transactionData = await db.query(
      'SELECT * FROM fund_transactions WHERE fund_id = ? ORDER BY transaction_time DESC', 
      [props.fundId]
    );
    
    // 分离买入和卖出记录
    buyTransactions.value = transactionData
      .filter(transaction => transaction.type === '买入')
      .map(transaction => ({
        ...transaction,
        transaction_nav: transaction.transaction_nav || 0,
        shares: transaction.shares || 0,
        fee: transaction.fee || 0,
        transaction_time: transaction.transaction_time || new Date()
      }));
    
    sellTransactions.value = transactionData
      .filter(transaction => transaction.type === '卖出')
      .map(transaction => ({
        ...transaction,
        transaction_nav: transaction.transaction_nav || 0,
        shares: transaction.shares || 0,
        fee: transaction.fee || 0,
        transaction_time: transaction.transaction_time || new Date()
      }));
    
    console.log('Buy transactions loaded:', buyTransactions.value);
    console.log('Sell transactions loaded:', sellTransactions.value);
  } catch (error) {
    console.error('Error loading transactions:', error);
  }
};

onMounted(() => {
  loadFundDetail();
});
</script>

<style scoped>
.fund-detail-page {
  height: 100%;
  background-color: #f5f7fa;
  display: flex;
  flex-direction: column;
}

/* 顶部导航栏 */
.fund-detail-header {
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

/* 基金基本信息 */
.fund-basic-info {
  padding: 13px 30px;
  background-color: #ffffff;
  margin-bottom: 10px;
}

.fund-name {
  font-size: 18px;
  font-weight: 600;
  color: #333333;
  margin: 0 0 10px 0;
}

.fund-code-risk {
  display: flex;
  align-items: center;
  margin-bottom: 20px;
}

.fund-code {
  font-size: 14px;
  color: #666666;
  margin-right: 10px;
}

.fund-risk {
  font-size: 12px;
  color: #ff6b6b;
  background-color: #fff5f5;
  padding: 2px 8px;
  border-radius: 10px;
}

.fund-amount {
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

.fund-returns {
  display: flex;
  justify-content: space-around;
  border-top: 1px solid #f0f0f0;
  padding-top: 15px;
  margin-bottom: 8px;
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
}

.return-value.positive {
  color: #67c23a;
}

.return-value.negative {
  color: #ff6b6b;
}

/* 功能按钮 */
.fund-functions {
  display: flex;
  justify-content: space-around;
  padding: 15px;
  background-color: #ffffff;
  margin-bottom: 10px;
}

.function-item {
  display: flex;
  flex-direction: column;
  align-items: center;
  cursor: pointer;
}

.function-item :deep(el-icon) {
  font-size: 20px;
  color: #409eff;
  margin-bottom: 5px;
}

.function-item span {
  font-size: 12px;
  color: #666666;
}

/* 累计盈亏和业绩走势 */
.fund-trend {
  background-color: #ffffff;
  margin-bottom: 10px;
  padding: 15px;
}

.trend-tabs {
  display: flex;
  border-bottom: 1px solid #f0f0f0;
  margin-bottom: 15px;
}

.tab-item {
  flex: 1;
  text-align: center;
  padding: 10px 0;
  font-size: 14px;
  color: #666666;
  cursor: pointer;
}

.tab-item.active {
  color: #409eff;
  border-bottom: 2px solid #409eff;
}

.trend-content {
  padding: 10px 0;
}

.total-return {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20px;
}

.total-return-label {
  font-size: 14px;
  color: #666666;
}

.total-return-value {
  font-size: 16px;
  font-weight: 600;
  color: #67c23a;
}

.trend-chart {
  height: 200px;
  position: relative;
}

.chart-placeholder {
  width: 100%;
  height: 100%;
  position: relative;
}

.chart-line {
  position: absolute;
  bottom: 30px;
  left: 0;
  right: 0;
  height: 2px;
  background: linear-gradient(to right, #333 0%, #333 20%, #333 40%, #333 60%, #333 80%, #333 100%);
  transform: scaleY(0.5);
  transform-origin: bottom;
}

.chart-dot {
  position: absolute;
  bottom: 29px;
  right: 20px;
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background-color: #333;
}

.chart-value {
  position: absolute;
  bottom: 40px;
  right: 10px;
  font-size: 12px;
  color: #333;
  background-color: rgba(255, 255, 255, 0.8);
  padding: 2px 6px;
  border-radius: 4px;
}

.chart-labels {
  position: absolute;
  bottom: 0;
  left: 0;
  right: 0;
  display: flex;
  justify-content: space-between;
  font-size: 10px;
  color: #999;
}

/* 投资计划 */
.investment-plan {
  background-color: #ffffff;
  margin-bottom: 80px;
  padding: 15px;
}

.plan-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 15px;
}

.plan-header h3 {
  font-size: 16px;
  font-weight: 600;
  color: #333333;
  margin: 0;
}

.plan-setting {
  font-size: 14px;
  color: #409eff;
  display: flex;
  align-items: center;
  cursor: pointer;
}

.plan-setting :deep(el-icon) {
  font-size: 14px;
  margin-left: 5px;
}

.plan-content {
  padding: 20px 0;
  text-align: center;
  background-color: #f9f9f9;
  border-radius: 8px;
}

.plan-placeholder {
  display: flex;
  flex-direction: column;
  align-items: center;
  color: #999999;
}

.plan-icon {
  font-size: 40px;
  margin-bottom: 10px;
  opacity: 0.5;
}



.action-btn.primary {
  background-color: #409eff;
  border-color: #409eff;
  color: #ffffff;
}

.action-btn.secondary {
  background-color: #f0f0f0;
  border-color: #f0f0f0;
  color: #333333;
}

/* 交易记录明细 */
.fund-transactions {
  padding: 15px;
  background-color: #ffffff;
  margin-bottom: 80px;
}

.section-title {
  font-size: 16px;
  font-weight: 600;
  color: #333333;
  margin: 0 0 15px 0;
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

.transaction-type.buy {
  background-color: #e6f7ff;
  color: #1890ff;
}

.transaction-type.sell {
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
</style>