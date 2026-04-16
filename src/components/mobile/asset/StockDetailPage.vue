<template>
  <div class="stock-detail-page">
    <!-- 顶部导航栏 -->
    <div class="stock-detail-header">
      <div class="header-left" @click="goBack">
        <el-icon><ArrowLeft /></el-icon>
      </div>
      <h1 class="header-title">资产详情</h1>
      <div class="header-right"></div>
    </div>
    
    <!-- 股票基本信息 -->
    <div class="stock-basic-info">
      <h2 class="stock-name">{{ stockInfo.name }}</h2>
      <div class="stock-code-risk">
        <span class="stock-code">{{ stockInfo.code }}</span>
      </div>
      <div class="stock-amount">
        <div class="amount-label">成本金额(元)</div>
        <div class="amount-value">¥{{ stockInfo.costAmount.toFixed(2) }}</div>
      </div>
      <div class="stock-returns">
        <div class="return-item">
          <div class="return-label">持有成本</div>
          <div class="return-value">¥{{ stockInfo.costPrice.toFixed(2) }}</div>
        </div>
        <div class="return-item">
          <div class="return-label">当前价格</div>
          <div class="return-value">¥{{ stockInfo.currentPrice.toFixed(2) }}</div>
        </div>
        <div class="return-item">
          <div class="return-label">持有数量</div>
          <div class="return-value">{{ stockInfo.quantity }}</div>
        </div>
      </div>
      <div class="stock-returns">
        <div class="return-item">
          <div class="return-label">确认收益</div>
          <div class="return-value positive">¥{{ stockInfo.confirmedReturn.toFixed(2) }}</div>
        </div>
        <div class="return-item">
          <div class="return-label">持有收益</div>
          <div class="return-value positive">¥{{ stockInfo.holdReturn.toFixed(2) }}</div>
        </div>
        <div class="return-item">
          <div class="return-label">总收益</div>
          <div class="return-value positive">¥{{ stockInfo.totalReturn.toFixed(2) }}</div>
        </div>
      </div>
    </div>
    
    <!-- 股票交易记录明细 -->
    <div class="stock-transactions">
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
                    <span class="item-label">价格</span>
                    <span class="item-value">¥{{ (holding.price || 0).toFixed(2) }}</span>
                  </div>
                  <div class="transaction-item">
                    <span class="item-label">数量</span>
                    <span class="item-value">{{ holding.quantity || 0 }}</span>
                  </div>
                  <div class="transaction-item">
                    <span class="item-label">剩余数量</span>
                    <span class="item-value">{{ holding.remaining_quantity || 0 }}</span>
                  </div>
                  <div class="transaction-item">
                    <span class="item-label">手续费</span>
                    <span class="item-value">¥{{ (holding.fee || 0).toFixed(2) }}</span>
                  </div>
                  <div class="transaction-item">
                    <span class="item-label">状态</span>
                    <span class="item-value">{{ holding.sell_status || '未卖出' }}</span>
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
                    <span class="item-label">交易价格</span>
                    <span class="item-value">¥{{ (transaction.price || 0).toFixed(2) }}</span>
                  </div>
                  <div class="transaction-item">
                    <span class="item-label">交易数量</span>
                    <span class="item-value">{{ transaction.quantity || 0 }}</span>
                  </div>
                  <div class="transaction-item">
                    <span class="item-label">交易金额</span>
                    <span class="item-value">¥{{ ((transaction.price || 0) * (transaction.quantity || 0)).toFixed(2) }}</span>
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
                    <span class="item-label">交易价格</span>
                    <span class="item-value">¥{{ (transaction.price || 0).toFixed(2) }}</span>
                  </div>
                  <div class="transaction-item">
                    <span class="item-label">交易数量</span>
                    <span class="item-value">{{ transaction.quantity || 0 }}</span>
                  </div>
                  <div class="transaction-item">
                    <span class="item-label">交易金额</span>
                    <span class="item-value">¥{{ ((transaction.price || 0) * (transaction.quantity || 0)).toFixed(2) }}</span>
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
import { ArrowLeft, Plus, Minus, Edit } from '@element-plus/icons-vue';
import { ElMessageBox, ElMessage } from 'element-plus';
import FloatingActionMenu from '../../../components/common/FloatingActionMenu.vue';
import {
  getStockDetail,
  getStockHoldings,
  getStockTransactions,
  updateStockPrice
} from '../../../services/asset/stockService';
import type { StockHolding, StockTransaction } from '../../../types/asset/stock';

const props = defineProps({
  stockId: {
    type: String,
    required: true
  }
});

// 跳转到股票买入页面
const navigateToBuyStock = () => {
  emit('navigate', { key: 'buyStock', params: { stockId: props.stockId } });
};

// 跳转到股票卖出页面
const navigateToSellStock = () => {
  emit('navigate', { key: 'sellStock', params: { stockId: props.stockId } });
};

// 修改股票价格
const editStockPrice = async () => {
  try {
    const { value } = await ElMessageBox.prompt(
      '请输入新的股票价格',
      '修改价格',
      {
        confirmButtonText: '确认',
        cancelButtonText: '取消',
        inputPattern: /^\d+(\.\d{1,2})?$/,
        inputErrorMessage: '请输入有效的价格（最多2位小数）',
        inputValue: stockInfo.value.currentPrice.toFixed(2)
      }
    );

    const newPrice = parseFloat(value);
    if (isNaN(newPrice) || newPrice <= 0) {
      ElMessage.error('请输入有效的价格');
      return;
    }

    // 调用服务更新价格
    await updateStockPrice(props.stockId, newPrice);

    // 重新加载详情
    await loadStockDetail();

    ElMessage.success('价格更新成功');
  } catch (error) {
    if (error !== 'cancel') {
      console.error('修改价格失败:', error);
      ElMessage.error('修改价格失败');
    }
  }
};

// 定义按钮列表
const actionButtons = [
  {
    text: '买入',
    icon: Plus,
    action: navigateToBuyStock
  },
  {
    text: '修改价格',
    icon: Edit,
    action: editStockPrice
  },
  {
    text: '卖出',
    icon: Minus,
    action: navigateToSellStock
  }
];

const emit = defineEmits(['navigate']);

const stockInfo = ref({
  name: '',
  code: '',
  costAmount: 0,
  costPrice: 0,
  currentPrice: 0,
  quantity: 0,
  confirmedReturn: 0,
  holdReturn: 0,
  totalReturn: 0
});

// 当前激活的标签
const activeTag = ref('holdings');

// 持有记录数据
const holdings = ref<StockHolding[]>([]);

// 买入记录数据
const buyTransactions = ref<StockTransaction[]>([]);

// 卖出记录数据
const sellTransactions = ref<StockTransaction[]>([]);

const goBack = () => {
  emit('navigate', 'asset');
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

// 加载股票详情数据
const loadStockDetail = async () => {
  console.log('Loading stock detail for:', props.stockId);

  try {
    // 使用服务获取股票详情
    const stock = await getStockDetail(props.stockId);
    console.log('Stock detail loaded:', stock);

    // 计算持有收益
const holdReturn = (stock.currentPrice - stock.costPrice) * stock.quantity;

    stockInfo.value = {
      name: stock.name,
      code: stock.code,
      costAmount: stock.costAmount,
      costPrice: stock.costPrice,
      currentPrice: stock.currentPrice,
      quantity: stock.quantity,
      confirmedReturn: stock.confirmedProfit,
      holdReturn: holdReturn,
      totalReturn: holdReturn + stock.confirmedProfit
    };

    // 加载持有记录
    holdings.value = await getStockHoldings(props.stockId);

    // 加载交易记录
    const transactions = await getStockTransactions(props.stockId);
    buyTransactions.value = transactions.buyTransactions;
    sellTransactions.value = transactions.sellTransactions;

    console.log('Holdings loaded:', holdings.value);
    console.log('Buy transactions loaded:', buyTransactions.value);
    console.log('Sell transactions loaded:', sellTransactions.value);
  } catch (error) {
    console.error('Error loading stock detail:', error);
    // 设置默认値，避免模板渲染错误
    stockInfo.value = {
      name: '未知股票',
      code: '',
      costAmount: 0,
      costPrice: 0,
      currentPrice: 0,
      quantity: 0,
      confirmedReturn: 0,
      holdReturn: 0,
      totalReturn: 0
    };
  }
};

onMounted(() => {
  loadStockDetail();
});
</script>

<style scoped>
.stock-detail-page {
  height: 100%;
  background-color: #f5f7fa;
  display: flex;
  flex-direction: column;
}

/* 顶部导航栏 */
.stock-detail-header {
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

/* 股票基本信息 */
.stock-basic-info {
  padding: 13px 30px;
  background-color: #ffffff;
  margin-bottom: 10px;
}

.stock-name {
  font-size: 18px;
  font-weight: 600;
  color: #333333;
  margin: 0 0 10px 0;
}

.stock-code-risk {
  display: flex;
  align-items: center;
  margin-bottom: 20px;
}

.stock-code {
  font-size: 14px;
  color: #666666;
  margin-right: 10px;
}

.stock-amount {
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

.stock-returns {
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

/* 交易记录明细 */
.stock-transactions {
  padding: 15px;
  background-color: #ffffff;
  margin-bottom: 80px;
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
