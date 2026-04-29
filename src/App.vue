<template>
  <div class="app mobile-layout">
    <!-- 顶部软件图标 -->
    <AppHeader @toggle-menu="toggleMenu" />
    
    <!-- 中间内容区域 -->
    <AppContent class="content-wrapper"
      :currentComponent="currentComponent" 
      @navigate="navigateTo"
      :componentProps="componentProps"
    />
    
    <!-- 底部功能导航 -->
    <AppFooter class="footer" @navigate="navigateTo" />
    
    <!-- 侧边菜单 -->
    <SideMenu :visible="menuVisible" @close="closeMenu" @navigate="navigateTo" />
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { Capacitor } from '@capacitor/core'
import { Keyboard } from '@capacitor/keyboard'
import { appNavigateTo, appCurrentComponent, appComponentProps } from './main.ts'
import { useThemeStore } from './stores/theme'


// 导入组件
import AppHeader from './components/common/AppHeader.vue'
import AppContent from './components/common/AppContent.vue'
import AppFooter from './components/common/AppFooter.vue'
import SideMenu from './components/common/SideMenu.vue'

// 导入功能组件
import MobileAccountManagement from './components/mobile/account/AccountManagement.vue'
import AssetManagement from './components/mobile/asset/AssetManagement.vue'
import LiabilityManagement from './components/mobile/liability/LiabilityManagement.vue'
import AddLiabilityPage from './components/mobile/liability/AddLiabilityPage.vue'
import LiabilityDetailPage from './components/mobile/liability/LiabilityDetailPage.vue'
import FinancialDashboard from './components/mobile/dashboard/FinancialDashboard.vue'
import FinancialGoal from './components/mobile/goal/FinancialGoal.vue'
import FinancialSandbox from './components/mobile/sandbox/FinancialSandbox.vue'
import KnowledgeHome from './components/mobile/knowledge/KnowledgeHome.vue'
import KnowledgeCategory from './components/mobile/knowledge/KnowledgeCategory.vue'
import KnowledgeArticle from './components/mobile/knowledge/KnowledgeArticle.vue'
import KnowledgeProfile from './components/mobile/knowledge/KnowledgeProfile.vue'
import SandboxSimulationPage from './components/mobile/sandbox/SandboxSimulationPage.vue'
import SandboxHistory from './components/mobile/sandbox/SandboxHistory.vue'
import SandboxResultDetail from './components/mobile/sandbox/SandboxResultDetail.vue'
import MoreFeatures from './components/mobile/more/MoreFeatures.vue'
import ExpensePage from './components/mobile/expense/ExpensePage.vue'
import IncomePage from './components/mobile/income/IncomePage.vue'
import AddAccountPage from './components/mobile/account/AddAccountPage.vue'
import AccountDetailPage from './components/mobile/account/AccountDetailPage.vue'
import RepayCreditCardPage from './components/mobile/account/RepayCreditCardPage.vue'
import AddExpensePage from './components/mobile/expense/AddExpensePage.vue'
import AddIncomePage from './components/mobile/income/AddIncomePage.vue'
import ExpenseStats from './components/mobile/expense/ExpenseStats.vue'
import IncomeStats from './components/mobile/income/IncomeStats.vue'
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

// Initialize theme store (applies CSS variables to DOM)
const themeStore = useThemeStore()

// 导航参数
const navParams = ref<any>({});

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
      incomeStats: IncomeStats, // 映射到收入统计页面组件
      income: IncomePage, // 映射到收入页面组件
      addIncome: AddIncomePage, // 映射到新增收入页面组件
      asset: AssetManagement, // 映射到资产页面组件
      addAsset: AddAssetPage, // 映射到新增普通资产页面组件
      addStock: AddStockPage, // 映射到新增股票交易页面组件
      addFund: AddFundPage, // 映射到新增基金交易页面组件
      fundDetail: FundDetailPage, // 映射到基金详情页面组件
      buyFund: BuyFundPage, // 映射到基金二次买入页面组件
      sellFund: SellFundPage, // 映射到基金卖出页面组件
      stockDetail: StockDetailPage, // 映射到股票详情页面组件
      buyStock: BuyStockPage, // 映射到股票买入页面组件
      sellStock: SellStockPage, // 映射到股票卖出页面组件
      assetDetail: AssetDetailPage, // 映射到普通资产详情页面组件
      liability: LiabilityManagement,
      addLiability: AddLiabilityPage,
      liabilityDetail: LiabilityDetailPage,
      dashboard: FinancialDashboard,
      goal: FinancialGoal,
      sandbox: FinancialSandbox,
      sandboxSimulation: SandboxSimulationPage,
      sandboxHistory: SandboxHistory,
      sandboxResultDetail: SandboxResultDetail,
      knowledge: KnowledgeHome,
      knowledgeCategory: KnowledgeCategory,
      knowledgeArticle: KnowledgeArticle,
      knowledgeProfile: KnowledgeProfile,
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
    props.year = navParams.value.year;
    props.month = navParams.value.month;
  }

  // 为收入相关组件传递年月参数
  if (activeMenu.value === 'income' || activeMenu.value === 'incomeStats') {
    props.year = navParams.value.year;
    props.month = navParams.value.month;
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

  // 为普通资产详情页面传递assetId参数
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

  // 为负债详情页面传递liabilityId参数
  if (activeMenu.value === 'liabilityDetail' && navParams.value.liabilityId) {
    props.liabilityId = navParams.value.liabilityId;
  }

  // 为沙盘推演页面传递sceneType参数
  if (activeMenu.value === 'sandboxSimulation' && navParams.value.sceneType) {
    props.sceneType = navParams.value.sceneType;
  }

  // 为沙盘结果详情页面传递historyId参数
  if (activeMenu.value === 'sandboxResultDetail' && navParams.value.historyId) {
    props.historyId = navParams.value.historyId
  }
  
  // 为知识分类页面传递categoryId参数
  if (activeMenu.value === 'knowledgeCategory' && navParams.value.categoryId) {
    props.categoryId = navParams.value.categoryId
  }
  
  // 为知识文章页面传递articleId参数
  if (activeMenu.value === 'knowledgeArticle' && navParams.value.articleId) {
    props.articleId = navParams.value.articleId
  }
  
  return props;
});

const navigateTo = (key: string | { key: string, params?: any }, params?: any) => {
  const menu = appNavigateTo(key, params)
  console.log('Navigate to:', menu.key, 'with params:', menu.params);
  activeMenu.value = menu.key;
  // 存储导航参数
  navParams.value = menu.params;
  console.log('Navigate to:', activeMenu.value, 'with params:', navParams.value);
}

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
    // 设置键盘配置 - 使用 none 模式防止页面上移
    // 这是关键设置，防止键盘弹出时页面被压缩
    Keyboard.setResizeMode({
      mode: 'none' as any
    })
    
    // 仅监听键盘事件用于日志记录，不操作DOM避免影响输入焦点
    Keyboard.addListener('keyboardWillShow', (info) => {
      console.log('键盘将显示，高度:', info.keyboardHeight)
    })
    
    Keyboard.addListener('keyboardDidShow', () => {
      console.log('键盘已显示')
    })
    
    Keyboard.addListener('keyboardWillHide', () => {
      console.log('键盘将隐藏')
    })
    
    Keyboard.addListener('keyboardDidHide', () => {
      console.log('键盘已隐藏')
    })
  }
})
</script>

<style scoped>
/* Default CSS variables for theme (fallback values) */
:global(:root) {
  --app-primary-color: #409EFF;
  --app-primary-rgb: 64, 158, 255;
}

/* 关键：固定整个容器，键盘永远无法顶起页面 */
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

/* 键盘打开时的样式 - 使用 fixed 定位防止页面上移 */
:global(body.keyboard-open) .app {
  /* 保持固定高度，不受键盘影响 */
  height: 100vh;
}

/* 确保底部导航栏始终显示 */
.footer {
  display: flex;
}
</style>