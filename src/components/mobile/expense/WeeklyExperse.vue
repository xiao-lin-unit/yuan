<template>
  <div class="weekly-finance-section">
    <div class="section-header">
      <h3>本周支出</h3>
    </div>
    <div class="weekly-total">总计: ¥{{ totalExpense.toFixed(2) }}</div>
    <div class="finance-chart">
      <div class="chart-container">
        <div v-for="(day, index) in weeklyData" :key="index" class="chart-bar">
          <div class="bar-value">{{ formatAmount(day.amount) }}</div>
          <div class="bar-container">
            <div class="bar" :style="{ height: getBarHeight(day.amount) }"></div>
          </div>
          <div class="bar-label">{{ day.label }}</div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import dayjs from 'dayjs';
import db from '../../../database';

interface DayData {
  date: dayjs.Dayjs;
  label: string;
  amount: number;
}

const weeklyData = ref<DayData[]>([]);

// 计算本周总支出
const totalExpense = computed(() => {
  return weeklyData.value.reduce((total, day) => total + day.amount, 0);
});

// 计算本周最大支出（用于图表高度）
const maxExpense = computed(() => {
  return Math.max(...weeklyData.value.map(day => day.amount), 1); // 确保至少为1，避免除以0
});

// 格式化金额
const formatAmount = (amount: number): string => {
  if (amount >= 1000) {
    return (amount / 1000).toFixed(2) + 'K';
  }
  return amount.toFixed(1);
};

// 计算柱状图高度
const getBarHeight = (amount: number): string => {
  const height = (amount / maxExpense.value) * 90; // 最大高度为90%
  return `${height}%`;
};

// 获取本周的开始和结束日期
const getWeekRange = (): { start: dayjs.Dayjs; end: dayjs.Dayjs } => {
  const now = dayjs();
  const dayOfWeek = now.day(); // 0-6，0表示周日

  // 计算本周一的日期（如果今天是周日，则上周日为一周的开始）
  const start = now.subtract(dayOfWeek === 0 ? 6 : dayOfWeek - 1, 'day').startOf('day');

  // 计算本周日的日期
  const end = start.add(6, 'day').endOf('day');

  return { start, end };
};

// 从流水记录中获取本周支出数据
const loadWeeklyExpenses = async () => {
  try {
    console.log('开始加载本周支出数据');
    
    // 连接数据库
    await db.connect();
    
    // 获取本周的开始和结束日期
    const { start, end } = getWeekRange();
    
    // 从流水表中查询类型为账户支出的记录
    const transactions = await db.query(
      'SELECT t.* FROM transactions t WHERE t.type = ? AND t.created_at BETWEEN ? AND ?',
      ['账户支出', start.toISOString(), end.toISOString()]
    );
    
    // 按日期分组统计支出
    const dailyExpenses = new Map<string, number>();
    
    transactions.forEach(transaction => {
      console.log('处理流水记录:', transaction);
      if (transaction.created_at) {
        const date = dayjs(transaction.created_at);
        const dateStr = date.format('YYYY-MM-DD'); // YYYY-MM-DD格式
        
        if (dailyExpenses.has(dateStr)) {
          dailyExpenses.set(dateStr, dailyExpenses.get(dateStr)! + (transaction.amount || 0));
        } else {
          dailyExpenses.set(dateStr, transaction.amount || 0);
        }
      }
    });
    
    console.log('按日期分组的支出:', Object.fromEntries(dailyExpenses));
    
    // 生成本周的日期数据
    const days: DayData[] = [];
    const dayLabels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    
    for (let i = 0; i < 7; i++) {
      const date = start.add(i, 'day');
      const dateStr = date.format('YYYY-MM-DD');

      days.push({
        date,
        label: dayLabels[i],
        amount: dailyExpenses.get(dateStr) || 0
      });
    }
    
    console.log('生成的周数据:', days);
    weeklyData.value = days;
  } catch (error) {
    console.error('加载本周支出数据失败:', error);
    // 出错时使用默认数据
    weeklyData.value = [
      { date: dayjs(), label: '周一', amount: 0 },
      { date: dayjs(), label: '周二', amount: 0 },
      { date: dayjs(), label: '周三', amount: 0 },
      { date: dayjs(), label: '周四', amount: 0 },
      { date: dayjs(), label: '周五', amount: 0 },
      { date: dayjs(), label: '周六', amount: 0 },
      { date: dayjs(), label: '周日', amount: 0 }
    ];
  }
};

// 组件挂载时加载数据
onMounted(() => {
  loadWeeklyExpenses();
});
</script>

<style scoped>
.weekly-finance-section {
  background-color: white;
  border-radius: 12px;
  padding: 15px;
  margin: 0 0 20px 0;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.05);
}

.section-header {
  display: flex;
  align-items: center;
  margin-bottom: 15px;
}

.section-header h3 {
  font-size: 16px;
  margin: 0;
  color: #303133;
}

.weekly-total {
  font-size: 14px;
  color: #606266;
  margin-bottom: 15px;
}

.finance-chart {
  margin-top: 20px;
}

.chart-container {
  display: flex;
  justify-content: space-around;
  align-items: flex-end;
  height: 180px;
}

.chart-bar {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 5px;
  width: 30px;
  position: relative;
  height: 100%;
}

.chart-bar .bar-container {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: flex-end;
  width: 8px;
}

.chart-bar .bar {
  width: 8px;
  background-color: #67c23a;
  border-radius: 4px 4px 0 0;
}

.bar-value {
  font-size: 10px;
  color: #606266;
  text-align: center;
  margin-bottom: 5px;
}

.bar-label {
  font-size: 10px;
  color: #909399;
  text-align: center;
  margin-top: 5px;
}

/* 响应式调整 */
@media (max-width: 375px) {
  .chart-container {
    height: 140px;
  }
}

@media (max-width: 320px) {
  .chart-container {
    height: 120px;
  }
}
</style>