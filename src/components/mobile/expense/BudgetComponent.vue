<template>
  <div class="budget-section">
    <div class="section-header">
      <h3>预算</h3>
      <el-icon class="more-icon"><More /></el-icon>
    </div>
    <div class="budget-details">
      <div class="budget-item">
        <span class="budget-label">剩余:</span>
        <span class="budget-value">¥{{ remainingBudget.toFixed(2) }}</span>
      </div>
      <div class="budget-item">
        <span class="budget-label">总额:</span>
        <span class="budget-value">¥{{ totalBudget.toFixed(2) }}</span>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue';
import { getCurrentDate } from '../../../utils/timezone';
import { More } from '@element-plus/icons-vue';
import db from '../../../database';

// 接收年月参数
const props = defineProps<{
  year: number;
  month: number;
}>();

// 预算数据
const totalBudget = ref(0);
const remainingBudget = ref(0);

// 从数据库中获取指定月份的预算
const loadBudget = async () => {
  try {
    // 连接数据库
    await db.connect();
    
    // 这里应该从预算表中查询指定月份的预算
    // 由于目前还没有预算表，我们暂时使用模拟数据
    // 实际项目中，应该创建预算表并实现相应的查询逻辑
    
    // 模拟数据：每个月的预算为10000
    totalBudget.value = 10000;
    
    // 计算剩余预算（总预算 - 已支出）
    // 这里应该从流水表中查询指定月份的总支出
    const startDate = getCurrentDate().year(props.year).month(props.month - 1).startOf('month').toISOString();
    const endDate = getCurrentDate().year(props.year).month(props.month - 1).endOf('month').toISOString();
    
    const expenseTransactions = await db.query(
      'SELECT SUM(amount) as total FROM transactions WHERE type = ? AND created_at BETWEEN ? AND ?',
      ['账户支出', startDate, endDate]
    );
    
    const totalExpense = expenseTransactions[0]?.total || 0;
    remainingBudget.value = totalBudget.value - totalExpense;
  } catch (error) {
    console.error('加载预算数据失败:', error);
    // 出错时使用默认数据
    totalBudget.value = 10000;
    remainingBudget.value = 10000;
  }
};

// 组件挂载时加载数据
onMounted(() => {
  loadBudget();
});

// 监听年月变化，重新加载数据
watch(() => [props.year, props.month], () => {
  loadBudget();
}, { deep: true });
</script>

<style scoped>
.budget-section {
  background-color: white;
  border-radius: 12px;
  padding: 15px;
  margin: 0 0 20px 0;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.05);
}

.section-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 15px;
}

.section-header h3 {
  font-size: 16px;
  margin: 0;
  color: #303133;
}

.more-icon {
  color: #909399;
  font-size: 18px;
}

.budget-details {
  display: flex;
  justify-content: space-between;
}

.budget-item {
  display: flex;
  align-items: center;
  gap: 10px;
}

.budget-label {
  font-size: 14px;
  color: #606266;
}

.budget-value {
  font-size: 14px;
  color: #303133;
  font-weight: bold;
}
</style>