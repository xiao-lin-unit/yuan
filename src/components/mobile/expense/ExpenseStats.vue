<template>
  <div class="expense-stats">
    <!-- 顶部导航栏 -->
    <div class="page-header">
      <el-icon @click="goBack">
        <ArrowLeft />
      </el-icon>
      <div class="date-selector" @click="showDatePicker = !showDatePicker">
        <span>{{ selectedDate }}</span>
        <el-icon class="dropdown-icon"><ArrowDown /></el-icon>
      </div>
      <div class="placeholder"></div>
      <!-- 日期选择器 -->
      <div v-if="showDatePicker" class="date-picker-dropdown">
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
    
    <!-- 每日统计图表 -->
    <div class="daily-stats-section">
      <h3>每日统计</h3>
      <div class="calendar-container">
        <Calendar 
          width="100%"
          :year="selectedYear"
          :month="selectedMonth"
          :expenses="Object.fromEntries(dailyExpenses)"
          @click="handleDateClick"
        />
      </div>

    </div>
    
    <!-- 日统计报表 -->
    <div class="daily-chart-section">
      <h3>日统计报表</h3>
      <div class="line-chart-container">
        <v-chart class="chart" :option="dailyChartOption" autoresize />
      </div>
    </div>
    
    <!-- 分类报表 -->
    <div class="category-report-section">
      <h3>分类报表</h3>
      <div class="pie-chart-container">
        <v-chart class="chart" :option="categoryChartOption" autoresize />
      </div>
    </div>
    
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, watch, onActivated } from 'vue';
import { ArrowLeft, ArrowDown, House, Grid } from '@element-plus/icons-vue';
import { use } from 'echarts/core';
import { CanvasRenderer } from 'echarts/renderers';
import { LineChart, PieChart } from 'echarts/charts';
import { GridComponent, TooltipComponent, LegendComponent, TitleComponent } from 'echarts/components';
import VChart from 'vue-echarts';
import db from '../../../database';
import Calendar from '../../common/calendar/Calendar.vue';
import { CategoryService } from '../../../services/categoryService';

// 注册 ECharts 组件
use([CanvasRenderer, LineChart, PieChart, GridComponent, TooltipComponent, LegendComponent, TitleComponent]);

// 接收年月参数（可选，默认为当前日期）
const props = defineProps<{
  year?: number;
  month?: number;
}>();

const emit = defineEmits(['navigate']);

// 日期选择状态 - 使用传入值或当前年月
const now = new Date();
const selectedYear = ref(props.year ?? now.getFullYear());
const selectedMonth = ref(props.month ?? now.getMonth() + 1);
const showDatePicker = ref(false);

// 生成年份列表
const years = ref([]);
for (let i = 2023; i <= 2029; i++) {
  years.value.push(i);
};

// 计算显示的日期
const selectedDate = computed(() => {
  return `${selectedYear.value}-${String(selectedMonth.value).padStart(2, '0')}`;
});

// ECharts 配置
const dailyChartOption = ref({});
const categoryChartOption = ref({});

// 日历相关状态
const currentDate = ref(new Date());
const startDate = ref(new Date(selectedYear.value, selectedMonth.value - 1, 1));
const endDate = ref(new Date(selectedYear.value, selectedMonth.value, 0));

// 每日支出数据
const dailyExpenses = ref(new Map<string, number>());

// 从数据库中获取每日支出数据
const loadDailyExpenses = async () => {
  try {
    // 连接数据库
    await db.connect();
    
    // 获取本月的开始和结束日期
    const start = new Date(selectedYear.value, selectedMonth.value - 1, 1).toISOString();
    const end = new Date(selectedYear.value, selectedMonth.value, 0, 23, 59, 59).toISOString();
    
    // 从流水表中查询类型为账户支出的记录
    const transactions = await db.query(
      'SELECT DATE(created_at) as date, SUM(amount) as total FROM transactions WHERE type = ? AND created_at BETWEEN ? AND ? GROUP BY DATE(created_at) ORDER BY date',
      ['账户支出', start, end]
    );
    
    // 处理数据
    const expensesMap = new Map<string, number>();
    
    transactions.forEach(transaction => {
      expensesMap.set(transaction.date, transaction.total);
    });
    
    dailyExpenses.value = expensesMap;
    
    // 更新日历的开始和结束日期
    startDate.value = new Date(selectedYear.value, selectedMonth.value - 1, 1);
    endDate.value = new Date(selectedYear.value, selectedMonth.value, 0);
    currentDate.value = new Date(selectedYear.value, selectedMonth.value - 1, 1);
  } catch (error) {
    console.error('加载每日支出数据失败:', error);
  }
};

// 根据日期获取支出金额
const getExpenseByDate = (date: Date): number => {
  const dateStr = date.toISOString().split('T')[0];
  return dailyExpenses.value.get(dateStr) || 0;
};

// 判断是否是当天
const isCurrentDay = (date: Date): boolean => {
  const today = new Date();
  return date.getDate() === today.getDate() && 
         date.getMonth() === today.getMonth() && 
         date.getFullYear() === today.getFullYear();
};

// 处理月份变化
const handleMonthChange = (date: Date) => {
  selectedYear.value = date.getFullYear();
  selectedMonth.value = date.getMonth() + 1;
  loadDailyExpenses();
  loadCategoryExpenses();
};

// 从数据库中获取分类支出数据
const loadCategoryExpenses = async () => {
  try {
    // 连接数据库
    await db.connect();
    
    // 获取本月的开始和结束日期
    const startDate = new Date(selectedYear.value, selectedMonth.value - 1, 1).toISOString();
    const endDate = new Date(selectedYear.value, selectedMonth.value, 0, 23, 59, 59).toISOString();
    
    // 从流水表中查询类型为账户支出的记录，按subType分组
    const transactions = await db.query(
      'SELECT sub_type as category, SUM(amount) as total FROM transactions WHERE type = ? AND created_at BETWEEN ? AND ? GROUP BY sub_type',
      ['账户支出', startDate, endDate]
    );
    
    // 处理数据
    const labels: string[] = [];
    const data: number[] = [];
    
    transactions.forEach(transaction => {
      labels.push(transaction.category);
      data.push(transaction.total);
    });
    
    // 渲染分类报表图表
    renderCategoryChart(labels, data);
  } catch (error) {
    console.error('加载分类支出数据失败:', error);
  }
};

// 从数据库中获取日支出数据
const loadDailyChartData = async () => {
  try {
    // 连接数据库
    await db.connect();
    
    // 获取本月的开始和结束日期
    const startDate = new Date(selectedYear.value, selectedMonth.value - 1, 1).toISOString();
    const endDate = new Date(selectedYear.value, selectedMonth.value, 0, 23, 59, 59).toISOString();
    
    // 从流水表中查询类型为账户支出的记录，按日期分组
    const transactions = await db.query(
      'SELECT DATE(created_at) as date, SUM(amount) as total FROM transactions WHERE type = ? AND created_at BETWEEN ? AND ? GROUP BY DATE(created_at) ORDER BY date',
      ['账户支出', startDate, endDate]
    );
    
    // 生成当月所有日期
    const daysInMonth = new Date(selectedYear.value, selectedMonth.value, 0).getDate();
    const labels: string[] = [];
    const data: number[] = [];
    
    // 初始化数据数组
    for (let i = 1; i <= daysInMonth; i++) {
      const dateStr = `${selectedYear.value}-${String(selectedMonth.value).padStart(2, '0')}-${String(i).padStart(2, '0')}`;
      labels.push(String(i));
      data.push(0);
    }
    
    // 填充有支出的日期数据
    transactions.forEach(transaction => {
      const dateParts = transaction.date.split('-');
      const day = parseInt(dateParts[2]);
      if (day > 0 && day <= daysInMonth) {
        data[day - 1] = transaction.total;
      }
    });
    
    // 渲染日统计报表图表
    renderDailyChart(labels, data);
  } catch (error) {
    console.error('加载日支出数据失败:', error);
  }
};



// 渲染分类报表图表
const renderCategoryChart = async (labels: string[], data: number[]) => {
  // 获取支出分类的翻译
  const expenseCategories = await CategoryService.getCategories('expense');
  const categoryMap = new Map(expenseCategories.map(c => [c.id, c.name]));
  
  // 检查是否有数据
  const hasData = data.length > 0 && data.some(value => value > 0);
  
  let chartData: any[] = [];
  
  if (hasData) {
    // 有数据时，使用实际数据
    const totalExpense = data.reduce((sum, val) => sum + val, 0);
    
    chartData = labels.map((label, index) => {
      const translatedName = categoryMap.get(label) || label;
      const value = data[index];
      const percentage = totalExpense > 0 ? ((value / totalExpense) * 100).toFixed(1) : '0.0';
      return {
        name: translatedName,
        value: value,
        originalLabel: label,
        percentage: percentage
      };
    });
  } else {
    // 没有数据时，将所有分类平均展示
    const equalValue = 100 / expenseCategories.length;
    chartData = expenseCategories.map(category => ({
      name: category.name,
      value: equalValue,
      originalLabel: category.id,
      percentage: (100 / expenseCategories.length).toFixed(1)
    }));
  }
  
  categoryChartOption.value = {
    tooltip: {
      show: true,
      formatter: function(params: any) {
        const data = params.data;
        return `${data.name} ¥${data.value}`;
      },
      fontSize: 12,
    },
    legend: {
      show: false,
      bottom: '5%',
      left: 'center'
    },
    series: [
      {
        type: 'pie',
        radius: ['50%', '70%'],
        avoidLabelOverlap: false, // 必须设为false，防止中心label被挪位
        itemStyle: {
          borderRadius: 3,
          borderColor: '#fff',
          borderWidth: 1
        },
        label: {
          show: true,
          fontSize: 12,
          formatter: function(params: any) {
            const data = params.data;
            return `${data.name} ${data.percentage}%`;
          },
          position: 'outside'
        },
        emphasis: {
          label: {
            show: false
          }
        },
        labelLine: {
          show: true
        },
        data: chartData
      }
    ]
  };
};

// 渲染日统计报表图表
const renderDailyChart = (labels: string[], data: number[]) => {
  // 计算Y轴最大值
  const maxDataValue = Math.max(...data);
  let yMax: number | undefined;
  
  // 只有当所有数据都为0时，设置Y轴最大值为100
  if (maxDataValue === 0) {
    yMax = 100;
  }
  
  dailyChartOption.value = {
    tooltip: {
      trigger: 'axis'
    },
    grid: {
      left: '3%',
      right: '4%',
      bottom: '3%',
      containLabel: true
    },
    xAxis: {
      type: 'category',
      boundaryGap: false,
      data: labels,
      name: '日期'
    },
    yAxis: {
      type: 'value',
      name: '金额',
      max: yMax
    },
    series: [
      {
        type: 'line',
        data: data,
        smooth: true,
        symbol: 'circle',
        symbolSize: 6,
        lineStyle: {
          width: 1,
          color: 'rgba(103, 194, 58, 1)'
        },
        itemStyle: {
          color: 'rgba(103, 194, 58, 1)',
          borderColor: '#fff',
          borderWidth: 1
        },
        areaStyle: {
          color: 'rgba(103, 194, 58, 0.2)'
        }
      }
    ]
  };
};

// 选择年份
const selectYear = (year: number) => {
  selectedYear.value = year;
  loadDailyExpenses();
  loadCategoryExpenses();
  loadDailyChartData();
};

// 选择月份
const selectMonth = (month: number) => {
  selectedMonth.value = month;
  showDatePicker.value = false;
  loadDailyExpenses();
  loadCategoryExpenses();
  loadDailyChartData();
};

// 返回上一页
const goBack = () => {
  emit('navigate', 'expense');
};

// 组件挂载时加载数据
onMounted(() => {
  loadDailyExpenses();
  loadCategoryExpenses();
  loadDailyChartData();
});

// 组件被激活时重新加载数据
onActivated(() => {
  loadDailyExpenses();
  loadCategoryExpenses();
  loadDailyChartData();
});

// 监听年份变化，重新加载数据
watch(selectedYear, () => {
  loadDailyExpenses();
  loadCategoryExpenses();
  loadDailyChartData();
});

// 监听月份变化，重新加载数据
watch(selectedMonth, () => {
  loadDailyExpenses();
  loadCategoryExpenses();
  loadDailyChartData();
});

// 处理日期点击事件
const handleDateClick = (date) => {
  console.log('Date clicked:', date);
  // 可以在这里添加日期点击后的逻辑，例如显示该日期的详细支出信息
};
</script>

<style scoped>
.expense-stats {
  min-height: 100vh;
  background-color: #f5f7fa;
  padding-bottom: 20px;
}

/* 顶部导航栏 */
.page-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 16px;
  background-color: white;
  border-bottom: 1px solid #e0e0e0;
  z-index: 100;
  flex-shrink: 0;
  position: relative;
  margin-bottom: 20px;
}

.page-header :deep(.el-icon) {
  font-size: 20px;
  color: #333333;
  cursor: pointer;
  transition: color 0.2s ease;
}

.page-header :deep(.el-icon):hover {
  color: #409eff;
}

.placeholder {
  width: 24px;
}

.date-selector {
  font-size: 16px;
  font-weight: bold;
  color: #333333;
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

/* 每日统计图表 */
.daily-stats-section {
  background-color: white;
  border-radius: 12px;
  padding: 15px;
  margin: 0 15px 15px 15px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.05);
}

.daily-stats-section h3 {
  font-size: 16px;
  margin: 0 0 15px 0;
  color: #303133;
}

.calendar-container {
  margin: 0;
}

/* 日历样式 */
.calendar-container {
  margin: 0;
  border-radius: 12px;
  overflow: hidden;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.05);
}

/* 日统计报表 */
.daily-chart-section {
  background-color: white;
  border-radius: 12px;
  padding: 15px;
  margin: 0 15px 15px 15px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.05);
}

.daily-chart-section h3 {
  font-size: 16px;
  margin: 0 0 15px 0;
  color: #303133;
}

.line-chart-container {
  height: 250px;
  margin-bottom: 10px;
}

.chart {
  width: 100%;
  height: 100%;
}

/* 月份导航样式 */
.calendar-container :deep(.calendar-header) {
  background-color: white;
  border-bottom: 1px solid #e0e0e0;
  padding: 12px;
}

.calendar-container :deep(.calendar-header .calendar-title) {
  font-size: 16px;
  font-weight: bold;
  color: #303133;
}

.calendar-container :deep(.calendar-header .calendar-btn) {
  color: #409eff;
  font-size: 18px;
}

.calendar-container :deep(.calendar-header .calendar-btn:hover) {
  color: #66b1ff;
}

/* 星期标题样式 */
.calendar-container :deep(.calendar-week) {
  background-color: white;
  border-bottom: 1px solid #e0e0e0;
  padding: 10px 0;
}

.calendar-container :deep(.calendar-week .week-item) {
  font-size: 14px;
  color: #606266;
  text-align: center;
}

/* 日期网格样式 */
.calendar-container :deep(.calendar-grid) {
  background-color: white;
  padding: 10px;
}

.calendar-container :deep(.calendar-grid .calendar-day-item) {
  padding: 4px;
}

/* 日期单元格样式 */
.calendar-day {
  height: 80px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  border-radius: 12px;
  transition: all 0.3s ease;
  position: relative;
  overflow: hidden;
}

.calendar-day:hover {
  background-color: #f5f7fa;
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
}

.calendar-day.has-expense {
  background-color: #ecf5ff;
  border: 1px solid #d9ecff;
}

.calendar-day.current-day {
  background-color: #409eff;
  color: white;
  border: 1px solid #409eff;
  box-shadow: 0 4px 12px rgba(64, 158, 255, 0.4);
}

.day-number {
  font-size: 16px;
  font-weight: bold;
  margin-bottom: 2px;
}

.lunar-day {
  font-size: 10px;
  color: #909399;
  margin-bottom: 2px;
}

.calendar-day.current-day .lunar-day {
  color: rgba(255, 255, 255, 0.8);
}

.festival {
  font-size: 9px;
  color: #f56c6c;
  margin-bottom: 2px;
}

.term {
  font-size: 9px;
  color: #67c23a;
  margin-bottom: 2px;
}

.expense-amount {
  font-size: 12px;
  color: #67c23a;
  font-weight: 500;
  background-color: rgba(255, 255, 255, 0.8);
  padding: 2px 8px;
  border-radius: 10px;
  margin-top: 2px;
}

.calendar-day.current-day .expense-amount {
  color: #409eff;
  background-color: rgba(255, 255, 255, 0.9);
}

/* 周末日期样式 */
.calendar-container :deep(.calendar-day-item.weekend .calendar-day) {
  background-color: #f9fafc;
}

/* 其他月份日期样式 */
.calendar-container :deep(.calendar-day-item.other-month .calendar-day) {
  opacity: 0.5;
}

.chart-tabs {
  display: flex;
  justify-content: center;
  gap: 20px;
}

.tab {
  font-size: 14px;
  color: #606266;
  cursor: pointer;
  padding: 5px 10px;
  border-radius: 4px;
}

.tab.active {
  color: #409eff;
  background-color: #ecf5ff;
}

/* 分类报表 */
.category-report-section {
  background-color: white;
  border-radius: 12px;
  padding: 15px;
  margin: 0 15px 20px 15px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.05);
}

.category-report-section h3 {
  font-size: 16px;
  margin: 0 0 15px 0;
  color: #303133;
}

.pie-chart-container {
  height: 300px;
  margin-bottom: 15px;
  display: flex;
  justify-content: center;
  align-items: center;
}

/* 分类支出列表 */
.category-list-section {
  background-color: white;
  border-radius: 12px;
  padding: 15px;
  margin: 0 15px 20px 15px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.05);
}

.category-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 15px 0;
  border-bottom: 1px solid #f0f0f0;
}

.category-item:last-child {
  border-bottom: none;
}

.category-info {
  display: flex;
  align-items: center;
  gap: 10px;
}

.category-icon {
  font-size: 20px;
  color: #409eff;
}

.category-name {
  font-size: 14px;
  color: #303133;
}

.category-percentage {
  font-size: 12px;
  color: #909399;
}

.category-amount {
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  gap: 2px;
}

.amount-change {
  font-size: 12px;
  color: #67c23a;
}

.amount-total {
  font-size: 14px;
  font-weight: bold;
  color: #303133;
}

/* 响应式调整 */
@media (max-width: 375px) {
  .chart-container {
    height: 180px;
  }
  
  .pie-chart-container {
    height: 250px;
  }
}

@media (max-width: 320px) {
  .chart-container {
    height: 150px;
  }
  
  .pie-chart-container {
    height: 200px;
  }
}
</style>