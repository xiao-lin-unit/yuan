import { createApp } from 'vue'
import { createPinia } from 'pinia'
import ElementPlus from 'element-plus'
import 'element-plus/dist/index.css'
import App from './App.vue'
import dayjs from 'dayjs'
import utc from 'dayjs/plugin/utc'
import timezone from 'dayjs/plugin/timezone'
import { runAutoTasks } from './auto'
import './auto/tasks'

dayjs.extend(utc)
dayjs.extend(timezone)

// 设置全局默认东八区
dayjs.tz.setDefault('Asia/Shanghai')

// 导入功能组件
import MobileAccountManagement from './components/mobile/account/AccountManagement.vue'
import AssetManagement from './components/mobile/asset/AssetManagement.vue'
import LiabilityManagement from './components/mobile/liability/LiabilityManagement.vue'
import FinancialDashboard from './components/mobile/dashboard/FinancialDashboard.vue'
import FinancialGoal from './components/mobile/goal/FinancialGoal.vue'
import FinancialSandbox from './components/mobile/sandbox/FinancialSandbox.vue'
import FinancialKnowledge from './components/mobile/knowledge/FinancialKnowledge.vue'
import SandboxSimulationPage from './components/mobile/sandbox/SandboxSimulationPage.vue'
import SandboxHistory from './components/mobile/sandbox/SandboxHistory.vue'
import SandboxResultDetail from './components/mobile/sandbox/SandboxResultDetail.vue'
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

// 初始化Capacitor
import { Capacitor } from '@capacitor/core'
if (Capacitor.isNativePlatform()) {
  console.log('Running on native platform')
}

const app = createApp(App)
app.use(createPinia())
app.use(ElementPlus)
app.mount('#app')

// 启动自动任务
runAutoTasks()

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
      dashboard: FinancialDashboard,
      goal: FinancialGoal,
      sandbox: FinancialSandbox,
      sandboxSimulation: SandboxSimulationPage,
      sandboxHistory: SandboxHistory,
      sandboxResultDetail: SandboxResultDetail,
      knowledge: FinancialKnowledge,
      more: MoreFeatures, // 映射到更多功能组件
      databaseViewer: DatabaseViewer // 数据库查看页面
    }


const appNavigateTo = (key: string | { key: string, params?: any }, params?: any) => {
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
  
  return { key: navKey, params: navParamsObj }
}

const appCurrentComponent = (key: string) => {
  console.log('Getting component for key:', JSON.stringify(componentMap));
  return componentMap[key] || ExpensePage;
}

const appComponentProps = ({key, params}: {key: string, params: any}) => {
  const props: Record<string, any> = {};

  // 为支出相关组件传递年月参数
  if (key === 'expense' || key === 'expenseStats') {
    props.year = params.year;
    props.month = params.month;
  }

  // 为基金详情页面传递fundId参数
  if (key === 'fundDetail' && params.fundId) {
    props.fundId = params.fundId;
  }

  // 为基金二次买入页面传递fundId参数
  if (key === 'buyFund' && params.fundId) {
    props.fundId = params.fundId;
  }

  // 为基金卖出页面传递fundId参数
  if (key === 'sellFund' && params.fundId) {
    props.fundId = params.fundId;
  }

  // 为股票详情页面传递stockId参数
  if (key === 'stockDetail' && params.stockId) {
    props.stockId = params.stockId;
  }

  // 为股票买入页面传递stockId参数
  if (key && params.stockId) {
    props.stockId = params.stockId;
  }

  // 为股票卖出页面传递stockId参数
  if (key && params.stockId) {
    props.stockId = params.stockId;
  }

  // 为普通资产详情页面传递assetId参数
  if (key && params.assetId) {
    props.assetId = params.assetId;
  }

  // 为账户详情页面传递accountId参数
  if (key && params.accountId) {
    props.accountId = params.accountId;
  }

  // 为信用卡还款页面传递accountId参数
  if (key && params.accountId) {
    props.accountId = params.accountId;
  }

  // 为沙盘推演页面传递sceneType参数
  if (key === 'sandboxSimulation' && params.sceneType) {
    props.sceneType = params.sceneType;
  }

  // 为沙盘结果详情页面传递historyId参数
  if (key === 'sandboxResultDetail' && params.historyId) {
    props.historyId = params.historyId;
  }

  return props;
};

export { appNavigateTo, appComponentProps, appCurrentComponent }
