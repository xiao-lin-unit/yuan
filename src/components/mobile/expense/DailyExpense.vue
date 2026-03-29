<template>
  <div class="daily-expense">
    <div class="date-header">
      <span class="date">{{ date }}</span>
      <span class="total-expense">支: ¥{{ totalExpense.toFixed(2) }}</span>
    </div>
    <div v-if="expenses.length > 0" class="expense-list">
      <div v-for="(expense, index) in expenses" :key="index" class="expense-item">
        <div class="expense-info">
          <div class="expense-category">{{ expense.category }}</div>
          <div v-if="expense.note" class="expense-note">{{ expense.note }}</div>
        </div>
        <div class="expense-details">
          <span class="expense-amount">-¥{{ expense.amount.toFixed(2) }}</span>
          <span class="expense-method">{{ expense.method }}</span>
        </div>
      </div>
    </div>
    <div v-else class="no-expense">
      <!-- 无支出时不显示任何记录 -->
    </div>
  </div>
</template>

<script setup lang="ts">
defineProps({
  date: {
    type: String,
    required: true
  },
  totalExpense: {
    type: Number,
    default: 0
  },
  expenses: {
    type: Array,
    default: () => []
  }
});
</script>

<style scoped>
.daily-expense {
  background-color: white;
  border-radius: 12px;
  padding: 12px 15px;
  margin: 0 0 20px 0;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.05);
}

.date-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding-bottom: 8px;
  border-bottom: 1px solid #f0f0f0;
  margin-bottom: 8px;
}

.expense-list {
  margin-top: 8px;
}

.date {
  font-size: 14px;
  color: #606266;
  font-weight: 500;
}

.total-expense {
  font-size: 14px;
  font-weight: bold;
  color: #67c23a;
}

.expense-list {
  margin-top: 10px;
}

.expense-item {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  padding: 8px 0;
  border-bottom: 1px solid #f0f0f0;
}

.expense-item:last-child {
  border-bottom: none;
}

.expense-info {
  flex: 1;
}

.expense-category {
  font-size: 14px;
  color: #303133;
  position: relative;
  padding-left: 12px;
  margin-bottom: 2px;
}

.expense-note {
  font-size: 12px;
  color: #909399;
  padding-left: 12px;
  margin-top: 1px;
}

.expense-category::before {
  content: '•';
  position: absolute;
  left: 0;
  color: #909399;
}

.expense-details {
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  gap: 2px;
}

.expense-amount {
  font-size: 14px;
  font-weight: bold;
  color: #67c23a;
}

.expense-method {
  font-size: 12px;
  color: #909399;
}


</style>