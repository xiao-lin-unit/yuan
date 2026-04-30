<template>
  <div class="daily-income">
    <div class="date-header">
      <span class="date">{{ date }}</span>
      <span class="total-income">收: ¥{{ totalIncome.toFixed(2) }}</span>
    </div>
    <div v-if="incomes.length > 0" class="income-list">
      <div v-for="(income, index) in incomes" :key="index" class="income-item">
        <div class="income-info">
          <div class="income-category">{{ income.category }}</div>
          <div v-if="income.remark" class="income-note">{{ income.remark }}</div>
        </div>
        <div class="income-details">
          <span class="income-amount">¥{{ income.amount.toFixed(2) }}</span>
          <span class="income-method">{{ income.account_name }}</span>
        </div>
      </div>
    </div>
    <div v-else class="no-income">
      <!-- 无收入时不显示任何记录 -->
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, watch } from 'vue';
import { getCurrentDate } from '../../../utils/timezone';
import db from '../../../database';
import { incomeCategories } from '../../../data/categories';

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

const incomes = ref([]);
const totalIncome = ref(0);

// 查询当天的收入记录
const loadDailyIncomes = async () => {
  try {
    // 连接数据库
    await db.connect();
    
    // 解析日期字符串
    const [month, day] = props.dateStr.split('.').map(Number);
    const year = props.year;
    
    // 构建当天的开始和结束时间
    const startDate = getCurrentDate().year(year).month(month - 1).date(day).startOf('day').format('YYYY-MM-DDTHH:mm:ss');
    const endDate = getCurrentDate().year(year).month(month - 1).date(day).endOf('day').format('YYYY-MM-DDTHH:mm:ss');
    console.log("开始时间", startDate, "结束时间", endDate);
    
    // 从流水表中查询当天的账户收入记录
    const transactions = await db.query(
      'SELECT t.*, a.name as account_name, a.type as account_type FROM income_expense_records t LEFT JOIN accounts a ON t.account_id = a.id WHERE t.type = ? AND t.created_at BETWEEN ? AND ? ORDER BY t.created_at DESC',
      ['账户收入', startDate, endDate]
    );
    console.log("当天的收入记录", JSON.stringify(transactions));
    
    // 处理收入记录
    const incomeList = [];
    let total = 0;
    
    transactions.forEach(transaction => {
        
      console.log("处理前的当天的收入记录", JSON.stringify(transaction));
      // 根据subType查找对应的分类名称
      const category = incomeCategories.find(cat => cat.id === transaction.sub_type);
      const categoryName = category ? category.name : transaction.sub_type;
      
      incomeList.push({
        category: categoryName,
        amount: transaction.amount,
        account_name: transaction.account_name,
        remark: transaction.remark
      });
      total += transaction.amount;
    });
    
    console.log("最终当天的收入记录", JSON.stringify(incomeList));
    incomes.value = incomeList;
    totalIncome.value = total;
  } catch (error) {
    console.error('加载当日收入记录失败:', error);
  }
};

// 组件挂载时加载数据
onMounted(() => {
  loadDailyIncomes();
});

// 监听年月变化，重新加载数据
watch(() => [props.year, props.month], () => {
  loadDailyIncomes();
}, { deep: true });
</script>

<style scoped>
.daily-income {
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

.income-list {
  margin-top: 8px;
}

.date {
  font-size: 14px;
  color: #606266;
  font-weight: 500;
}

.total-income {
  font-size: 14px;
  font-weight: bold;
  color: #f56c6c;
}

.income-list {
  margin-top: 10px;
}

.income-item {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  padding: 8px 0;
  border-bottom: 1px solid #f0f0f0;
}

.income-item:last-child {
  border-bottom: none;
}

.income-info {
  flex: 1;
}

.income-category {
  font-size: 14px;
  color: #303133;
  position: relative;
  padding-left: 12px;
  margin-bottom: 2px;
}

.income-note {
  font-size: 12px;
  color: #909399;
  padding-left: 12px;
  margin-top: 1px;
}

.income-category::before {
  content: '•';
  position: absolute;
  left: 0;
  color: #909399;
}

.income-details {
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  gap: 2px;
}

.income-amount {
  font-size: 14px;
  font-weight: bold;
  color: #f56c6c;
}

.income-method {
  font-size: 12px;
  color: #909399;
}
</style>
