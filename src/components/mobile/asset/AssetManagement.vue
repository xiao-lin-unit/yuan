<template>
  <div class="asset-page">
    <!-- 顶部导航栏 -->
    <div class="top-nav-bar">
      <el-select v-model="selectedAssetType" class="type-selector" placeholder="选择类型">
        <el-option
          v-for="item in assetTypeOptions"
          :key="item.value"
          :label="item.label"
          :value="item.value"
        />
      </el-select>
      <div class="top-icons">
        <el-input
          v-if="isSearchExpanded"
          v-model="searchKeyword"
          class="search-input"
          placeholder="请输入名称"
          clearable
          @blur="onSearchBlur"
        />
        <el-icon class="nav-icon" @click="toggleSearch"><Search /></el-icon>
      </div>
    </div>

    <StatOverview v-if="!showEndedAssets"
      :background="image"
      :main="[{title: '资产金额', value: '￥' + totalAssetAmount.toFixed(2), color: undefined}]"
      :details="[{title: '资产数量', value: totalAssetCount, color: undefined}]"
    />

    <!-- 资产卡片容器 -->
    <div class="asset-cards-container" :style="{ 'margin-top': !showEndedAssets ? '0' : '20px' }">
      <div v-if="(selectedAssetType === '普通资产' && filteredGeneralAssets.length === 0) ||
                  (selectedAssetType === '股票' && filteredStocks.length === 0) ||
                  (selectedAssetType === '基金' && filteredFunds.length === 0)" class="no-assets">
        <el-empty :description="showEndedAssets ? '暂无历史资产' : '暂无资产'" />
      </div>
      <template v-else>
        <!-- 普通 -->
        <template v-if="selectedAssetType === '普通资产'">
          <AssetCard
            v-for="asset in filteredGeneralAssets"
            :key="asset.id"
            :title="asset.name"
            :amount="asset.amount"
            :icon="asset.icon"
            :color="asset.color"
            :assetId="asset.id"
            :code="asset.type"
            @click="viewAssetDetail"
          />
        </template>

        <!-- 股票资产 -->
        <template v-if="selectedAssetType === '股票'">
          <AssetCard
            v-for="stock in filteredStocks"
            :key="stock.id"
            :title="stock.name"
            :amount="stock.cost_price * stock.quantity"
            :icon="stock.icon"
            :color="stock.color"
            :assetId="stock.id"
            :code="stock.code"
            @click="viewStockDetail(stock.id)"
          />
        </template>

        <!-- 基金资产 -->
        <template v-if="selectedAssetType === '基金'">
          <AssetCard
            v-for="fund in filteredFunds"
            :key="fund.id"
            :title="fund.name"
            :amount="fund.cost_nav * fund.shares"
            :icon="fund.icon"
            :color="fund.color"
            :assetId="fund.id"
            :code="fund.code"
            @click="viewFundDetail(fund.id)"
          />
        </template>
      </template>
    </div>

    <!-- 切换当前/历史资产按钮 -->
    <div class="toggle-assets-button" @click="toggleAssetsView">
      <el-icon style="color: white;"><Switch /></el-icon>
      <span class="toggle-text">{{ showEndedAssets ? '当前资产' : '历史资产' }}</span>
    </div>
    <!-- <FloatingSwitchButton :active="showEndedAssets" active-text="当前资产" inactive-text="历史资产" /> -->
    
    <FloatingActionMenu :buttons="actionButtons" />    

  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, computed } from 'vue';
import dayjs from 'dayjs';
import { More, Goods, TrendCharts, DataAnalysis, Switch, Search } from '@element-plus/icons-vue';
import AssetCard from './AssetCard.vue';
import StatOverview from '../../../components/common/StatOverview.vue';
import { getAllStocks } from '../../../services/asset/stockService';
import { getAllFunds } from '../../../services/asset/fundService';
import { getAssets } from '../../../services/asset/assetService';
import { getAccounts } from '../../../services/account/accountService';
import type { Account } from '../../../types/account/account';
import image from '@/assets/img/m2.jpg';
import FloatingActionMenu from '../../common/FloatingActionMenu.vue';
// import FloatingSwitchButton from '../../common/FloatingSwitchButton.vue';

const emit = defineEmits(['navigate']);

// 资产数据
const generalAssets = ref<any[]>([]);
const stocks = ref<any[]>([]);
const funds = ref<any[]>([]);

// 账户数据
const accounts = ref<Account[]>([]);

// 对话框状态
const dialogVisible = ref({
  addAsset: false,
  addStock: false,
  addFund: false
});

// 浮动菜单状态
const isMoreMenuExpanded = ref(false);

// 是否显示已结束资产
const showEndedAssets = ref(false);

// 选择的资产类型
const selectedAssetType = ref<'普通资产' | '股票' | '基金'>('普通资产');
const assetTypeOptions = [
  { label: '普通资产', value: '普通资产' },
  { label: '股票', value: '股票' },
  { label: '基金', value: '基金' }
];

// 搜索
const isSearchExpanded = ref(false);
const searchKeyword = ref('');

const toggleSearch = () => {
  isSearchExpanded.value = !isSearchExpanded.value;
};

const onSearchBlur = () => {
  if (!searchKeyword.value.trim()) {
    isSearchExpanded.value = false;
  }
};

// 切换当前/历史资产视图
const toggleAssetsView = () => {
  showEndedAssets.value = !showEndedAssets.value;
};

// 计算属性：根据ended状态和搜索关键词过滤资产
const filteredGeneralAssets = computed(() => {
  let list = generalAssets.value.filter(asset => {
    const isEnded = asset.status === '结束';
    return showEndedAssets.value ? isEnded : !isEnded;
  });
  if (searchKeyword.value.trim()) {
    list = list.filter(asset => asset.name.includes(searchKeyword.value.trim()));
  }
  return list;
});

const filteredStocks = computed(() => {
  let list = stocks.value.filter(stock => {
    const isEnded = stock.ended === 1;
    return showEndedAssets.value ? isEnded : !isEnded;
  });
  if (searchKeyword.value.trim()) {
    list = list.filter(stock => stock.name.includes(searchKeyword.value.trim()));
  }
  return list;
});

const filteredFunds = computed(() => {
  let list = funds.value.filter(fund => {
    const isEnded = fund.ended === 1;
    return showEndedAssets.value ? isEnded : !isEnded;
  });
  if (searchKeyword.value.trim()) {
    list = list.filter(fund => fund.name.includes(searchKeyword.value.trim()));
  }
  return list;
});

const totalAssetAmount = computed(() => {
  if (selectedAssetType.value === '普通资产') {
    return filteredGeneralAssets.value.reduce((sum, a) => sum + (a.amount || 0), 0);
  } else if (selectedAssetType.value === '股票') {
    return filteredStocks.value.reduce((sum, s) => sum + (s.cost_price * s.quantity || 0), 0);
  } else {
    return filteredFunds.value.reduce((sum, f) => sum + (f.cost_nav * f.shares || 0), 0);
  }
});

const totalAssetCount = computed(() => {
  if (selectedAssetType.value === '普通资产') return filteredGeneralAssets.value.length;
  if (selectedAssetType.value === '股票') return filteredStocks.value.length;
  return filteredFunds.value.length;
});

const actionButtons = computed(() => {
  if (selectedAssetType.value === '普通资产') {
    return [{
      text: '新增普通资产',
      icon: Goods,
      action: navigateToAddAsset
    }];
  } else if (selectedAssetType.value === '股票') {
    return [{
      text: '新增股票',
      icon: TrendCharts,
      action: navigateToAddStock
    }];
  } else {
    return [{
      text: '新增基金',
      icon: DataAnalysis,
      action: navigateToAddFund
    }];
  }
});

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
  transaction_time: dayjs(),
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
  transaction_time: dayjs(),
  type: '买入',
  account_id: ''
});

onMounted(async () => {
  await loadAssetData();
});

const loadAssetData = async () => {
  try {
    // 使用服务加载资产数据和账户数据
    const [assets, stockData, fundData, accountData] = await Promise.all([
      getAssets(),
      getAllStocks(),
      getAllFunds(),
      getAccounts()
    ]);

    // 处理普通资产数据
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
    {
      id: '1',
      name: '股票1',
      code: '000001',
      price: 10,
      quantity: 100,
      fee: 0,
      transaction_time: dayjs(),
      type: '买入',
      account_id: '1'
    },
    {
      id: '2',
      name: '股票2',
      code: '000002',
      price: 20,
      quantity: 200,
      fee: 0,
      transaction_time: dayjs(),
      type: '卖出',
      account_id: '1'
    }
  
  ];
  
  // 模拟账户数据（包括公积金账户）
  accounts.value = [
    {
      id: '1',
      name: '公积金账户',
      type: '公积金',
      balance: 10000
    },
    {
      id: '2',
      name: '储蓄账户',
      type: '储蓄',
      balance: 5000
    }
  ];
};





const viewAssetDetail = (assetId: string) => {
    console.log('查看资产详情:', assetId);
    emit('navigate', { key: 'assetDetail', params: { assetId } });
  };
  
  const viewStockDetail = (stockId: string) => {
    console.log('查看股票详情:', stockId);
    emit('navigate', { key: 'stockDetail', params: { stockId } });
  };
  
  const viewFundDetail = (fundId: string) => {
    console.log('查看基金详情:', fundId);
    emit('navigate', { key: 'fundDetail', params: { fundId } });
  };

// 导航到新增普通资产页面
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

/* 顶部导航栏 */
.top-nav-bar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  height: 50px;
  padding: 0 15px;
  background-color: white;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
}

.type-selector {
  width: 100px;
}

.type-selector :deep(.el-select__wrapper) {
  box-shadow: none !important;
  background: transparent;
  border: none !important;
}

.type-selector :deep(.el-select__wrapper:hover) {
  box-shadow: none !important;
  border: none !important;
}

.type-selector :deep(.el-select__wrapper.is-focus) {
  box-shadow: none !important;
  border: none !important;
}

.type-selector :deep(.el-select .el-select.is-focus .el-select__wrapper) {
  box-shadow: none !important;
  border: none !important;
}

.top-icons {
  display: flex;
  align-items: center;
  gap: 8px;
}

.nav-icon {
  font-size: 18px;
  color: #606266;
  cursor: pointer;
}

.search-input {
  width: 140px;
}

.search-input :deep(.el-input__inner) {
  height: 32px;
}



.asset-cards-container {
  padding: 0 16px 10px;
  display: grid;
  grid-template-columns: 1fr;
  gap: 10px;
}

.no-assets {
  grid-column: 1 / -1;
  display: flex;
  justify-content: center;
  align-items: center;
  min-height: 50vh;
  background-color: #ffffff;
  border-radius: 8px;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
}



/* 切换资产按钮 */
.toggle-assets-button {
  position: fixed;
  bottom: 80px;
  left: 20px;
  z-index: 1000;
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 12px 16px;
  background-color: #67c23a;
  border-radius: 24px;
  box-shadow: 0 4px 12px rgba(103, 194, 58, 0.5);
  cursor: pointer;
  transition: all 0.3s ease;
}

.toggle-assets-button:hover {
  transform: scale(1.05);
  box-shadow: 0 6px 16px rgba(103, 194, 58, 0.5);
}

.toggle-text {
  color: white;
  font-size: 14px;
  font-weight: 500;
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