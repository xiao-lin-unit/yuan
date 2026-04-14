<template>
  <div class="asset-page">
    <!-- 资产卡片容器 -->
    <div class="asset-cards-container">
      <div v-if="generalAssets.length === 0 && stocks.length === 0 && funds.length === 0" class="no-assets">
        <el-empty description="暂无资产" />
      </div>
      <template v-else>
        <!-- 通用资产 -->
        <AssetCard 
          v-for="asset in generalAssets" 
          :key="asset.id"
          :title="asset.name"
          :amount="asset.amount"
          :secondary-amount="asset.monthlyIncome || 0"
          :icon="asset.icon"
          :color="asset.color"
          :assetId="asset.id"
          @click="viewAssetDetail"
        />
        
        <!-- 股票资产 -->
        <AssetCard 
          v-for="stock in stocks" 
          :key="stock.id"
          :title="stock.name"
          :amount="stock.costPrice * stock.quantity"
          :secondary-amount="stock.costPrice"
          :icon="stock.icon"
          :color="stock.color"
          :assetId="stock.id"
          @click="viewAssetDetail"
        />
        
        <!-- 基金资产 -->
        <AssetCard 
          v-for="fund in funds" 
          :key="fund.id"
          :title="fund.name"
          :amount="fund.cost_nav * fund.shares"
          :secondary-amount="fund.cost_nav"
          :icon="fund.icon"
          :color="fund.color"
          :assetId="fund.id"
          @click="viewFundDetail(fund.id)"
        />
      </template>
    </div>
    
    <!-- 浮动操作按钮 -->
    <div class="floating-action-menu">
      <div class="floating-action-button" @click="toggleMoreMenu">
        <el-icon style="color: white;"><More /></el-icon>
      </div>
      <div class="floating-menu" v-if="isMoreMenuExpanded">
        <div class="floating-menu-item" @click="navigateToAddAsset">
          <el-icon style="color: white;"><Goods /></el-icon>
          <span>新增通用资产</span>
        </div>
        <div class="floating-menu-item" @click="navigateToAddStock">
          <el-icon style="color: white;"><TrendCharts /></el-icon>
          <span>新增股票</span>
        </div>
        <div class="floating-menu-item" @click="navigateToAddFund">
          <el-icon style="color: white;"><DataAnalysis /></el-icon>
          <span>新增基金</span>
        </div>
      </div>
    </div>
    

  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { Setting, Plus, More, Goods, TrendCharts, DataAnalysis } from '@element-plus/icons-vue';
import AssetCard from './AssetCard.vue';
import db from '../../../database/index.js';

const emit = defineEmits(['navigate']);

// 资产数据
const generalAssets = ref([]);
const stocks = ref([]);
const funds = ref([]);

// 账户数据
const accounts = ref([]);

// 对话框状态
const dialogVisible = ref({
  addAsset: false,
  addStock: false,
  addFund: false
});

// 浮动菜单状态
const isMoreMenuExpanded = ref(false);

// 切换菜单展开状态
const toggleMoreMenu = () => {
  isMoreMenuExpanded.value = !isMoreMenuExpanded.value;
};

// 表单数据
const assetForm = ref({
  id: '',
  name: '',
  type: '',
  amount: 0,
  account_id: '',
  period: '' // 周期：年、月、空（不选择）
});

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
});

const fundForm = ref({
  id: '',
  name: '',
  code: '',
  nav: 0,
  shares: 0,
  fee: 0,
  has_lock: false,
  transaction_time: new Date(),
  type: '买入',
  account_id: ''
});

onMounted(async () => {
  await loadAssetData();
});

const loadAssetData = async () => {
  try {
    // 从数据库加载资产数据和账户数据
    const [assets, stockData, fundData, accountData] = await Promise.all([
      db.query('SELECT * FROM assets'),
      db.query('SELECT * FROM stocks'),
      db.query('SELECT * FROM funds'),
      db.query('SELECT * FROM accounts')
    ]);
    
    // 处理通用资产数据
    generalAssets.value = assets.map(asset => ({
      ...asset,
      icon: '💼',
      color: '#52c41a'
    }));
    
    // 处理股票数据
    stocks.value = stockData.map(stock => ({
      ...stock,
      icon: '📈',
      color: '#faad14'
    }));
    
    // 处理基金数据
    funds.value = fundData.map(fund => ({
      ...fund,
      icon: '📊',
      color: '#722ed1'
    }));
    
    // 处理账户数据
    accounts.value = accountData;
  } catch (error) {
    console.error('加载资产数据失败:', error);
    // 加载失败时使用模拟数据
    loadMockData();
  }
};

const loadMockData = () => {
  // 模拟数据
  stocks.value = [
   
  ];
  
  // 模拟账户数据（包括公积金账户）
  accounts.value = [
    
  ];
};





const viewAssetDetail = (assetId) => {
    console.log('查看资产详情:', assetId);
    // 这里可以跳转到资产详情页面
  };
  
  const viewFundDetail = (fundId) => {
    console.log('查看基金详情:', fundId);
    emit('navigate', { key: 'fundDetail', params: { fundId } });
  };

// 导航到新增通用资产页面
const navigateToAddAsset = () => {
  emit('navigate', { key: 'addAsset' });
  isMoreMenuExpanded.value = false;
};

// 导航到新增股票交易页面
const navigateToAddStock = () => {
  emit('navigate', { key: 'addStock' });
  isMoreMenuExpanded.value = false;
};

// 导航到新增基金交易页面
const navigateToAddFund = () => {
  emit('navigate', { key: 'addFund' });
  isMoreMenuExpanded.value = false;
};
</script>

<style scoped>
.asset-page {
  padding: 0;
  background-color: #f5f7fa;
  overflow-y: auto;
  overflow-x: hidden;
  height: 100%;
  min-height: 100%;
}

/* 隐藏滚动条但保留滚动功能 */
.asset-page::-webkit-scrollbar {
  display: none;
}

.asset-page {
  -ms-overflow-style: none;
  scrollbar-width: none;
}



.asset-cards-container {
  padding: 0 0 10px 0;
  display: grid;
  grid-template-columns: 1fr;
  gap: 10px;
}

.no-assets {
  grid-column: 1 / -1;
  display: flex;
  justify-content: center;
  align-items: center;
  min-height: 77vh;
  background-color: #ffffff;
  border-radius: 8px;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
}



/* 浮动操作菜单 */
.floating-action-menu {
  position: fixed;
  bottom: 80px;
  right: 20px;
  z-index: 1000;
}

.floating-action-button {
  width: 48px;
  height: 48px;
  border-radius: 50%;
  background-color: #409eff;
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: 0 4px 12px rgba(64, 158, 255, 0.5);
  cursor: pointer;
  transition: all 0.3s ease;
}

.floating-action-button:hover {
  transform: scale(1.1);
  box-shadow: 0 6px 16px rgba(64, 158, 255, 0.5);
}

.floating-action-button :deep(el-icon) {
  font-size: 24px;
  color: white;
}

.floating-menu {
  position: absolute;
  bottom: 66px;
  right: 0;
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  gap: 10px;
  animation: fadeIn 0.3s ease;
}

@keyframes fadeIn {
  from {
    opacity: 0;
    transform: translateY(10px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

.floating-menu-item {
  width: 48px;
  height: 48px;
  border-radius: 50%;
  background-color: #409eff;
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: 0 4px 12px rgba(64, 158, 255, 0.5);
  cursor: pointer;
  transition: all 0.3s ease;
  position: relative;
}

.floating-menu-item:hover {
  transform: scale(1.1);
  box-shadow: 0 6px 16px rgba(64, 158, 255, 0.5);
}

.floating-menu-item :deep(el-icon) {
  font-size: 20px;
  color: white;
}

.floating-menu-item span {
  position: absolute;
  right: 56px;
  background-color: rgba(0, 0, 0, 0.7);
  color: white;
  padding: 4px 8px;
  border-radius: 4px;
  font-size: 12px;
  white-space: nowrap;
  opacity: 0;
  transform: translateX(10px);
  transition: all 0.2s ease;
  pointer-events: none;
}

.floating-menu-item:hover span {
  opacity: 1;
  transform: translateX(0);
}

/* 响应式调整 */
@media (min-width: 768px) {
  .asset-cards-container {
    grid-template-columns: repeat(2, 1fr);
  }
}

@media (min-width: 1024px) {
  .asset-cards-container {
    grid-template-columns: repeat(3, 1fr);
  }
}
</style>