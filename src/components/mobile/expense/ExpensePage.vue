<template>
  <div class="expense-page">
    <!-- 顶部导航栏 -->
    <TopNav @dateChange="handleDateChange" @navigate="handleNavigate" />
    
    <!-- 月统计 -->
    <MonthlyStats :year="selectedYear" :month="selectedMonth" />
    
    <!-- 预算 -->
    <!-- <BudgetComponent :year="selectedYear" :month="selectedMonth" /> -->
    
    <!-- 本周收支 -->
    <WeeklyFinance v-if="isCurrentMonth" />
    
    <!-- 支出记录 -->
    <ExpenseRecords :year="selectedYear" :month="selectedMonth" />
    
    <!-- 浮动添加按钮 -->
    <FloatingActionMenu :buttons="actionButtons" />
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue';
import { Plus } from '@element-plus/icons-vue';
import TopNav from './TopNav.vue';
import MonthlyStats from './MonthlyStats.vue';
import BudgetComponent from './BudgetComponent.vue';
import WeeklyFinance from './WeeklyFinance.vue';
import ExpenseRecords from './ExpenseRecords.vue';
import FloatingActionMenu from '../../common/FloatingActionMenu.vue';

const emit = defineEmits(['navigate']);

// 日期选择状态
const selectedYear = ref(2026);
const selectedMonth = ref(3);

// 计算是否是当前月份
const isCurrentMonth = computed(() => {
  const now = new Date();
  return selectedYear.value === now.getFullYear() && selectedMonth.value === now.getMonth() + 1;
});

// 处理日期变化
const handleDateChange = (date: { year: number; month: number }) => {
  selectedYear.value = date.year;
  selectedMonth.value = date.month;
};

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

// 定义按钮列表
const actionButtons = [
  {
    text: '新增支出',
    icon: Plus,
    action: navigateToAddExpense
  }
];

// 处理导航事件
const handleNavigate = (key: string) => {
  emit('navigate', key);
};
</script>

<style scoped>
.expense-page {
  min-height: 100vh;
  background-color: #f5f7fa;
  position: relative;
}


</style>