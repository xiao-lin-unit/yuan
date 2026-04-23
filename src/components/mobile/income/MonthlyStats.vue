<template>
  <div class="monthly-stats">
    <div class="background-image">
      <img src="https://trae-api-cn.mchost.guru/api/ide/v1/text_to_image?prompt=hot air balloons in Cappadocia landscape&image_size=landscape_16_9" alt="背景" />
      <div class="financial-overview">
        <div class="overview-item">
          <div class="overview-label">月收入</div>
          <div class="overview-amount income">¥{{ income.toFixed(2) }}</div>
        </div>
        <div class="overview-details">
          <div class="detail-item">
            <span class="detail-label">月支出</span>
            <span class="detail-value expense">¥{{ expense.toFixed(2) }}</span>
          </div>
          <div class="detail-item">
            <span class="detail-label">本月结余</span>
            <span class="detail-value" :class="{ 'balance-negative': balance < 0, 'balance-positive': balance >= 0 }">¥{{ balance.toFixed(2) }}</span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue';
import dayjs from 'dayjs';
import db from '../../../database';

// 接收年月参数
const props = defineProps<{
  year: number;
  month: number;
}>();

// 定义收支数据
const expense = ref(0);
const income = ref(0);

// 计算本月结余
const balance = computed(() => {
  return income.value - expense.value;
});

// 获取指定月份的开始和结束日期
const getMonthRange = (year: number, month: number) => {
  const start = dayjs().year(year).month(month - 1).startOf('month');
  const end = dayjs().year(year).month(month - 1).endOf('month');
  
  return { start, end };
};

// 从流水表中获取月度收支数据
const loadMonthlyStats = async () => {
  try {
    console.log('开始加载月度收支数据:', props.year, props.month);
    
    // 连接数据库
    await db.connect();
    
    // 获取本月的开始和结束日期
    const { start, end } = getMonthRange(props.year, props.month);
    console.log('月度日期范围:', start.toISOString(), '至', end.toISOString());
    
    // 从流水表中查询类型为账户支出的记录
    const expenseTransactions = await db.query(
      'SELECT SUM(amount) as total FROM transactions WHERE type = ? AND created_at BETWEEN ? AND ?',
      ['账户支出', start.toISOString(), end.toISOString()]
    );
    
    // 从流水表中查询类型为账户收入的记录
    const incomeTransactions = await db.query(
      'SELECT SUM(amount) as total FROM transactions WHERE type = ? AND created_at BETWEEN ? AND ?',
      ['账户收入', start.toISOString(), end.toISOString()]
    );
    
    console.log('支出查询结果:', expenseTransactions);
    console.log('收入查询结果:', incomeTransactions);
    
    // 更新收支数据
    expense.value = expenseTransactions[0]?.total || 0;
    income.value = incomeTransactions[0]?.total || 0;
    
    console.log('更新后的支出:', expense.value);
    console.log('更新后的收入:', income.value);
  } catch (error) {
    console.error('加载月度收支数据失败:', error);
    // 出错时使用默认数据
    expense.value = 0;
    income.value = 0;
  }
};

// 组件挂载时加载数据
onMounted(() => {
  loadMonthlyStats();
});

// 监听年月变化，重新加载数据
watch(() => [props.year, props.month], () => {
  loadMonthlyStats();
}, { deep: true });
</script>

<style scoped>
.monthly-stats {
  margin: 0 0 20px 0;
}

/* 背景图部分 */
.background-image {
  position: relative;
  height: 200px;
  overflow: hidden;
  border-radius: 0 0 20px 20px;
}

.background-image img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.financial-overview {
  position: absolute;
  bottom: 0;
  left: 0;
  right: 0;
  padding: 20px;
  background: linear-gradient(to top, rgba(0, 0, 0, 0.7), transparent);
  color: white;
}

.overview-item {
  margin-bottom: 10px;
}

.overview-label {
  font-size: 14px;
  opacity: 0.9;
  margin-bottom: 5px;
}

.overview-amount {
  font-size: 24px;
  font-weight: bold;
}

.expense {
  color: #67c23a;
}

.overview-details {
  display: flex;
  justify-content: space-between;
  font-size: 12px;
}

.detail-item {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.detail-label {
  opacity: 0.8;
}

.detail-value {
  font-weight: bold;
}

.income {
  color: #f56c6c;
}

.balance-negative {
  color: #67c23a;
}

.balance-positive {
  color: #f56c6c;
}

/* 响应式调整 */
@media (max-width: 375px) {
  .background-image {
    height: 180px;
  }
  
  .overview-amount {
    font-size: 20px;
  }
}

@media (max-width: 320px) {
  .background-image {
    height: 160px;
  }
  
  .overview-amount {
    font-size: 18px;
  }
}
</style>