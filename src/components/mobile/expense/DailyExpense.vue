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
          <div v-if="expense.remark" class="expense-note">{{ expense.remark }}</div>
        </div>
        <div class="expense-details">
          <span class="expense-amount">¥{{ expense.amount.toFixed(2) }}</span>
          <span class="expense-method">{{ expense.account_name }}</span>
        </div>
      </div>
    </div>
    <div v-else class="no-expense">
      <!-- 无支出时不显示任何记录 -->
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, defineProps, watch } from 'vue';
import dayjs from 'dayjs';
import db from '../../../database';
import { expenseCategories } from '../../../data/categories';

const props = defineProps({
  date: {
    type: String,
    required: true
  },
  dateStr: {
    type: String,
    required: true
  },
  year: {
    type: Number,
    required: true
  },
  month: {
    type: Number,
    required: true
  }
});

const expenses = ref([]);
const totalExpense = ref(0);

// 查询当天的支出记录
const loadDailyExpenses = async () => {
  try {
    // 连接数据库
    await db.connect();
    
    // 解析日期字符串
    const [month, day] = props.dateStr.split('.').map(Number);
    const year = props.year;
    
    // 构建当天的开始和结束时间
    const startDate = dayjs().year(year).month(month - 1).date(day).startOf('day').toISOString();
    const endDate = dayjs().year(year).month(month - 1).date(day).endOf('day').toISOString();
    
    // 从流水表中查询当天的账户支出记录
    const transactions = await db.query(
      'SELECT t.*, a.name as account_name, a.type as account_type FROM transactions t LEFT JOIN accounts a ON t.account_id = a.id WHERE t.type = ? AND t.created_at BETWEEN ? AND ? ORDER BY t.created_at DESC',
      ['账户支出', startDate, endDate]
    );
    
    // 处理支出记录
    const expenseList = [];
    let total = 0;
    
    transactions.forEach(transaction => {
      console.log("流水信息", JSON.stringify(transaction))
      // 根据subType查找对应的分类名称
      const category = expenseCategories.find(cat => cat.id === transaction.sub_type);
      const categoryName = category ? category.name : transaction.sub_type;
      
      expenseList.push({
        category: categoryName,
        amount: transaction.amount,
        account_name: transaction.account_name,
        remark: transaction.remark
      });
      total += transaction.amount;
    });
    console.log("支出记录", JSON.stringify(expenseList))
    expenses.value = expenseList;
    totalExpense.value = total;
  } catch (error) {
    console.error('加载当日支出记录失败:', error);
  }
};

// 组件挂载时加载数据
onMounted(() => {
  loadDailyExpenses();
});

// 监听年月变化，重新加载数据
watch(() => [props.year, props.month], () => {
  loadDailyExpenses();
}, { deep: true });
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