<template>
  <div class="expense-page">
    <!-- 顶部导航栏 -->
    <TopNav />
    
    <!-- 月统计 -->
    <MonthlyStats />
    
    <!-- 预算 -->
    <BudgetComponent />
    
    <!-- 本周收支 -->
    <WeeklyFinance />
    
    <!-- 支出记录 -->
    <ExpenseRecords />
    
    <!-- 浮动添加按钮 -->
    <div class="floating-add-button" @click="navigateToAddExpense">
      <el-icon><Plus /></el-icon>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue';
import { Plus } from '@element-plus/icons-vue';
import TopNav from './TopNav.vue';
import MonthlyStats from './MonthlyStats.vue';
import BudgetComponent from './BudgetComponent.vue';
import WeeklyFinance from './WeeklyFinance.vue';
import ExpenseRecords from './ExpenseRecords.vue';

const emit = defineEmits(['navigate']);

// 可以添加支出数据和相关方法
const expenses = ref([]);
const budget = ref({});

// 可以添加获取支出数据的方法
const loadExpenses = () => {
  // 这里可以从API或本地存储获取支出数据
};

// 导航到新增支出页面
const navigateToAddExpense = () => {
  emit('navigate', 'addExpense');
};
</script>

<style scoped>
.expense-page {
  min-height: 100vh;
  background-color: #f5f7fa;
  position: relative;
}

/* 浮动添加按钮 */
.floating-add-button {
  position: fixed;
  bottom: 80px;
  right: 20px;
  width: 56px;
  height: 56px;
  border-radius: 50%;
  background-color: #409eff;
  color: white;
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: 0 4px 12px rgba(64, 158, 255, 0.5);
  cursor: pointer;
  z-index: 100;
  transition: all 0.3s ease;
}

.floating-add-button:hover {
  transform: scale(1.1);
  box-shadow: 0 6px 16px rgba(64, 158, 255, 0.6);
}

.floating-add-button :deep(el-icon) {
  font-size: 24px;
}

/* 响应式调整 */
@media (max-width: 375px) {
  .floating-add-button {
    bottom: 70px;
    right: 15px;
    width: 50px;
    height: 50px;
  }
  
  .floating-add-button :deep(el-icon) {
    font-size: 20px;
  }
}
</style>