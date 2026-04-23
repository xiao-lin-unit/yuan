<template>
  <div class="top-nav">
    <div class="date-selector" @click="showDatePicker = !showDatePicker">
      <span>{{ selectedDate }}</span>
      <el-icon class="dropdown-icon"><ArrowDown /></el-icon>
    </div>
    <div class="top-icons">
      <el-icon class="nav-icon" @click="navigateToStats"><DataAnalysis /></el-icon>
    </div>
    
    <!-- 日期选择器 -->
    <div v-if="showDatePicker" class="date-picker-dropdown">
      <!-- <div class="picker-header">
        <div class="picker-title">显示方式</div>
        <div class="picker-option">按月</div>
      </div>
      <div class="picker-header">
        <div class="picker-title">月份起始日</div>
        <div class="picker-option">01</div>
      </div> -->
      <div class="picker-content">
        <div class="year-list">
          <div 
            v-for="year in years" 
            :key="year"
            class="year-item"
            :class="{ active: selectedYear === year }"
            @click="selectYear(year)"
          >
            {{ year }}年
          </div>
        </div>
        <div class="month-grid">
          <div 
            v-for="month in 12" 
            :key="month"
            class="month-item"
            :class="{ active: selectedMonth === month }"
            @click="selectMonth(month)"
          >
            {{ month }}月
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue';
import { DataAnalysis, ArrowDown } from '@element-plus/icons-vue';
import dayjs from 'dayjs';

// 日期选择状态 - 默认为当前年月
const showDatePicker = ref(false);
const now = dayjs();
const selectedYear = ref(now.year());
const selectedMonth = ref(now.month() + 1);

// 定义属性
const props = defineProps<{
  statsTarget?: string;
}>();

// 定义事件
const emit = defineEmits(['dateChange', 'navigate']);

// 生成年份列表
const years = ref([]);
for (let i = 2023; i <= 2029; i++) {
  years.value.push(i);
}

// 计算显示的日期
const selectedDate = computed(() => {
  return `${selectedYear.value}-${String(selectedMonth.value).padStart(2, '0')}`;
});

// 选择年份
const selectYear = (year: number) => {
  selectedYear.value = year;
  emit('dateChange', { year, month: selectedMonth.value });
};

// 选择月份
const selectMonth = (month: number) => {
  selectedMonth.value = month;
  showDatePicker.value = false;
  emit('dateChange', { year: selectedYear.value, month });
};

// 导航到统计页面
const navigateToStats = () => {
  const target = props.statsTarget || 'expenseStats';
  emit('navigate', { key: target, param: { year: selectedYear.value, month: selectedMonth.value } });
};
</script>

<style scoped>
.top-nav {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 15px;
  background-color: white;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
  position: relative;
}

.date-selector {
  font-size: 16px;
  font-weight: bold;
  color: #303133;
  display: flex;
  align-items: center;
  gap: 5px;
  cursor: pointer;
  padding: 5px 10px;
  border-radius: 4px;
  background-color: white;
}

.dropdown-icon {
  font-size: 14px;
  color: #606266;
}

.top-icons {
  display: flex;
  gap: 15px;
}

.nav-icon {
  font-size: 18px;
  color: #606266;
}

/* 日期选择器 */
.date-picker-dropdown {
  position: absolute;
  top: 100%;
  left: 0;
  right: 0;
  background-color: white;
  box-shadow: none;
  border-radius: 0 0 8px 8px;
  z-index: 1000;
  padding: 10px;
  border-top: 1px solid #f0f0f0;
}

.picker-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 10px 0;
  border-bottom: 1px solid #f0f0f0;
}

.picker-title {
  font-size: 14px;
  color: #606266;
}

.picker-option {
  font-size: 14px;
  color: #409eff;
  display: flex;
  align-items: center;
  gap: 5px;
}

.picker-content {
  display: flex;
  padding: 10px 0;
}

.year-list {
  width: 30%;
  border-right: 1px solid #f0f0f0;
}

.year-item {
  padding: 10px;
  text-align: center;
  cursor: pointer;
  font-size: 14px;
  color: #606266;
}

.year-item.active {
  background-color: #ecf5ff;
  color: #409eff;
  font-weight: bold;
}

.month-grid {
  width: 70%;
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 10px;
  padding-left: 10px;
}

.month-item {
  padding: 10px;
  text-align: center;
  cursor: pointer;
  font-size: 14px;
  color: #606266;
  border-radius: 4px;
}

.month-item.active {
  background-color: #ecf5ff;
  color: #409eff;
  font-weight: bold;
}
</style>