<template>
  <div class="app mobile-layout">
    <!-- 顶部软件图标 -->
    <AppHeader @toggle-menu="toggleMenu" />
    
    <!-- 中间内容区域 -->
    <AppContent :currentComponent="currentComponent" @navigate="navigateTo" />
    
    <!-- 底部功能导航 -->
    <AppFooter @navigate="navigateTo" />
    
    <!-- 侧边菜单 -->
    <SideMenu :visible="menuVisible" @close="closeMenu" @navigate="navigateTo" />
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'

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

const activeMenu = ref('account')
const menuVisible = ref<boolean>(false)

// 组件映射
  const currentComponent = computed(() => {
    const componentMap: Record<string, any> = {
      account: MobileAccountManagement,
      addAccount: AddAccountPage,
      expense: ExpensePage, // 映射到支出页面组件
      income: MobileAccountManagement, // 暂时映射到账户管理组件，后续可创建专门的收入组件
      asset: AssetManagement,
      liability: LiabilityManagement,
      dashboard: FinancialDashboard,
      goal: FinancialGoal,
      sandbox: FinancialSandbox,
      knowledge: FinancialKnowledge,
      more: MoreFeatures // 映射到更多功能组件
    }
    return componentMap[activeMenu.value] || MobileAccountManagement
  })

const navigateTo = (key: string) => {
  activeMenu.value = key
}

// 切换菜单显示/隐藏
const toggleMenu = () => {
  menuVisible.value = !menuVisible.value
}

// 关闭菜单
const closeMenu = () => {
  menuVisible.value = false
}
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
}
</style>