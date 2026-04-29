<template>
  <div class="expense-page">
    <!-- 顶部导航栏 -->
    <TopNav stats-target="expenseStats" @dateChange="handleDateChange" @navigate="handleNavigate" />
    
    <!-- 月统计 -->
    <MonthlyStats :year="selectedYear" :month="selectedMonth" />
    
    <!-- 预算 -->
    <!-- <BudgetComponent :year="selectedYear" :month="selectedMonth" /> -->
    
    <!-- 本周支出 -->
    <WeeklyExperse v-if="isCurrentMonth" />
    
    <!-- 支出记录 -->
    <ExpenseRecords :year="selectedYear" :month="selectedMonth" />
    
    <!-- 浮动添加按钮 -->
    <FloatingActionMenu :buttons="actionButtons" />
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue';
import { Plus } from '@element-plus/icons-vue';
import TopNav from '../../common/TopNav.vue';
import MonthlyStats from './MonthlyStats.vue';
import WeeklyExperse from './WeeklyExperse.vue';
import ExpenseRecords from './ExpenseRecords.vue';
import FloatingActionMenu from '../../common/FloatingActionMenu.vue';
import { getCurrentDate } from '../../utils/timezone';

const emit = defineEmits(['navigate']);

// 日期选择状态 - 默认为当前年月
const now = getCurrentDate();
const selectedYear = ref(now.year());
const selectedMonth = ref(now.month() + 1);

// 计算是否是当前月份
const isCurrentMonth = computed(() => {
  const now = getCurrentDate();
  return selectedYear.value === now.year() && selectedMonth.value === now.month() + 1;
});

// 处理日期变化
const handleDateChange = (date: { year: number; month: number }) => {
  selectedYear.value = date.year;
  selectedMonth.value = date.month;
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