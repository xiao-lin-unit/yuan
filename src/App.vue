<template>
  <div class="app mobile-layout">
    <!-- 顶部软件图标 -->
    <AppHeader @toggle-menu="toggleMenu" />
    
    <!-- 中间内容区域 -->
    <AppContent 
      :currentComponent="currentComponent" 
      @navigate="navigateTo"
      @dateChange="handleDateChange"
      :componentProps="componentProps"
    />
    
    <!-- 底部功能导航 -->
    <AppFooter @navigate="navigateTo" />
    
    <!-- 侧边菜单 -->
    <SideMenu :visible="menuVisible" @close="closeMenu" @navigate="navigateTo" />
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { Capacitor } from '@capacitor/core'
import { Keyboard } from '@capacitor/keyboard'

// 导入组件
import AppHeader from './components/common/AppHeader.vue'
import AppContent from './components/common/AppContent.vue'
import AppFooter from './components/common/AppFooter.vue'
import SideMenu from './components/common/SideMenu.vue'

// 导入功能组件
import MobileAccountManagement from './components/mobile/account/AccountManagement.vue'
import AssetManagement from './components/mobile/asset/AssetManagement.vue'
import LiabilityManagement from './components/mobile/liability/LiabilityManagement.vue'
import FinancialDashboard from './components/mobile/financial/FinancialDashboard.vue'
import FinancialGoal from './components/mobile/financial/FinancialGoal.vue'
import FinancialSandbox from './components/mobile/financial/FinancialSandbox.vue'
import FinancialKnowledge from './components/mobile/financial/FinancialKnowledge.vue'
import MoreFeatures from './components/mobile/more/MoreFeatures.vue'
import ExpensePage from './components/mobile/expense/ExpensePage.vue'
import AddAccountPage from './components/mobile/account/AddAccountPage.vue'
import AccountDetailPage from './components/mobile/account/AccountDetailPage.vue'
import RepayCreditCardPage from './components/mobile/account/RepayCreditCardPage.vue'
import AddExpensePage from './components/mobile/expense/AddExpensePage.vue'
import ExpenseStats from './components/mobile/expense/ExpenseStats.vue'
import DatabaseViewer from './components/mobile/DatabaseViewer.vue'
import AddAssetPage from './components/mobile/asset/AddAssetPage.vue'
import AddStockPage from './components/mobile/asset/AddStockPage.vue'
import AddFundPage from './components/mobile/asset/AddFundPage.vue'
import FundDetailPage from './components/mobile/asset/FundDetailPage.vue'
import BuyFundPage from './components/mobile/asset/BuyFundPage.vue'
import SellFundPage from './components/mobile/asset/SellFundPage.vue'
import StockDetailPage from './components/mobile/asset/StockDetailPage.vue'
import BuyStockPage from './components/mobile/asset/BuyStockPage.vue'
import SellStockPage from './components/mobile/asset/SellStockPage.vue'
import AssetDetailPage from './components/mobile/asset/AssetDetailPage.vue'

const activeMenu = ref('expense')
const menuVisible = ref<boolean>(false)

// 导航参数
const navParams = ref<any>({});

// 日期选择状态
const selectedYear = ref(2026);
const selectedMonth = ref(3);

// 组件映射
  const currentComponent = computed(() => {
    const componentMap: Record<string, any> = {
      account: MobileAccountManagement,
      addAccount: AddAccountPage,
      accountDetail: AccountDetailPage,
      repayCreditCard: RepayCreditCardPage,
      expense: ExpensePage, // 映射到支出页面组件
      addExpense: AddExpensePage, // 映射到新增支出页面组件
      expenseStats: ExpenseStats, // 映射到支出统计页面组件
      income: MobileAccountManagement, // 暂时映射到账户管理组件，后续可创建专门的收入组件
      asset: AssetManagement, // 映射到资产页面组件
      addAsset: AddAssetPage, // 映射到新增通用资产页面组件
      addStock: AddStockPage, // 映射到新增股票交易页面组件
      addFund: AddFundPage, // 映射到新增基金交易页面组件
      fundDetail: FundDetailPage, // 映射到基金详情页面组件
      buyFund: BuyFundPage, // 映射到基金二次买入页面组件
      sellFund: SellFundPage, // 映射到基金卖出页面组件
      stockDetail: StockDetailPage, // 映射到股票详情页面组件
      buyStock: BuyStockPage, // 映射到股票买入页面组件
      sellStock: SellStockPage, // 映射到股票卖出页面组件
      assetDetail: AssetDetailPage, // 映射到通用资产详情页面组件
      liability: LiabilityManagement,
      dashboard: FinancialDashboard,
      goal: FinancialGoal,
      sandbox: FinancialSandbox,
      knowledge: FinancialKnowledge,
      more: MoreFeatures, // 映射到更多功能组件
      databaseViewer: DatabaseViewer // 数据库查看页面
    }
    return componentMap[activeMenu.value] || MobileAccountManagement
  })

// 组件属性
const componentProps = computed(() => {
  const props: Record<string, any> = {};
  
  // 为支出相关组件传递年月参数
  if (activeMenu.value === 'expense' || activeMenu.value === 'expenseStats') {
    props.year = selectedYear.value;
    props.month = selectedMonth.value;
  }
  
  // 为基金详情页面传递fundId参数
  if (activeMenu.value === 'fundDetail' && navParams.value.fundId) {
    props.fundId = navParams.value.fundId;
  }
  
  // 为基金二次买入页面传递fundId参数
  if (activeMenu.value === 'buyFund' && navParams.value.fundId) {
    props.fundId = navParams.value.fundId;
  }
  
  // 为基金卖出页面传递fundId参数
  if (activeMenu.value === 'sellFund' && navParams.value.fundId) {
    props.fundId = navParams.value.fundId;
  }
  
  // 为股票详情页面传递stockId参数
  if (activeMenu.value === 'stockDetail' && navParams.value.stockId) {
    props.stockId = navParams.value.stockId;
  }
  
  // 为股票买入页面传递stockId参数
  if (activeMenu.value === 'buyStock' && navParams.value.stockId) {
    props.stockId = navParams.value.stockId;
  }
  
  // 为股票卖出页面传递stockId参数
  if (activeMenu.value === 'sellStock' && navParams.value.stockId) {
    props.stockId = navParams.value.stockId;
  }

  // 为通用资产详情页面传递assetId参数
  if (activeMenu.value === 'assetDetail' && navParams.value.assetId) {
    props.assetId = navParams.value.assetId;
  }

  // 为账户详情页面传递accountId参数
  if (activeMenu.value === 'accountDetail' && navParams.value.accountId) {
    props.accountId = navParams.value.accountId;
  }

  // 为信用卡还款页面传递accountId参数
  if (activeMenu.value === 'repayCreditCard' && navParams.value.accountId) {
    props.accountId = navParams.value.accountId;
  }
  
  return props;
});

const navigateTo = (key: string | { key: string, params?: any }, params?: any) => {
  let navKey: string;
  let navParamsObj: any = {};
  
  if (typeof key === 'object' && key.key) {
    // 新格式：{ key: 'fundDetail', params: { fundId } }
    navKey = key.key;
    navParamsObj = key.params || {};
  } else {
    // 旧格式：'addAsset', params
    navKey = key as string;
    navParamsObj = params || {};
  }
  
  activeMenu.value = navKey;
  // 存储导航参数
  navParams.value = navParamsObj;
  console.log('Navigate to:', navKey, 'with params:', navParamsObj);
}

// 处理日期变化
const handleDateChange = (date: { year: number; month: number }) => {
  selectedYear.value = date.year;
  selectedMonth.value = date.month;
};

// 切换菜单显示/隐藏
const toggleMenu = () => {
  menuVisible.value = !menuVisible.value
}

// 关闭菜单
const closeMenu = () => {
  menuVisible.value = false
}

// 初始化Keyboard插件
onMounted(() => {
  if (Capacitor.isNativePlatform()) {
    // 设置键盘配置
    Keyboard.setResizeMode({
      mode: 'none'
    })
    
    // 监听键盘事件
    Keyboard.addListener('keyboardWillShow', (info) => {
      console.log('键盘将显示，高度:', info.keyboardHeight)
    })
    
    Keyboard.addListener('keyboardWillHide', () => {
      console.log('键盘将隐藏')
    })
  }
})
</script>

<style scoped>
/* 全局样式，防止body和html出现滚动条 */
:global(body),
:global(html) {
  margin: 0;
  padding: 0;
  overflow: hidden;
  height: 100%;
  width: 100%;
}

.app {
  height: 100vh;
  width: 100vw;
  display: flex;
  flex-direction: column;
  background-color: #f5f7fa;
  overflow: hidden;
  box-sizing: border-box;
}
</style>