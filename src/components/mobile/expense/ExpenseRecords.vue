<template>
  <div class="expense-records">
    <DailyExpense 
      v-for="day in days" 
      :key="day.date"
      :date="day.date"
      :date-str="day.dateStr"
      :year="year"
      :month="month"
    />
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, watch } from 'vue';
import DailyExpense from './DailyExpense.vue';

// 接收年月参数
const props = defineProps<{
  year: number;
  month: number;
}>();

const days = ref([]);
const year = ref(props.year);
const month = ref(props.month);

// 生成当月的每一天日期
const generateDays = () => {
  const yearVal = year.value;
  const monthVal = month.value - 1; // 转换为0-11的月份格式
  
  // 获取当月第一天
  const firstDay = new Date(yearVal, monthVal, 1);
  // 获取当月最后一天
  const lastDay = new Date(yearVal, monthVal + 1, 0);
  // 获取当月天数
  const daysInMonth = lastDay.getDate();
  
  const daysArray = [];
  
  // 生成当月的每一天
  for (let day = 1; day <= daysInMonth; day++) {
    const date = new Date(yearVal, monthVal, day);
    const dateStr = `${String(monthVal + 1).padStart(2, '0')}.${String(day).padStart(2, '0')}`;
    
    // 标记今天、昨天、前天
    let displayDate = dateStr;
    const today = new Date();
    const yesterday = new Date(today);
    yesterday.setDate(yesterday.getDate() - 1);
    const dayBeforeYesterday = new Date(today);
    dayBeforeYesterday.setDate(dayBeforeYesterday.getDate() - 2);
    
    const formatDate = (d) => {
      return `${String(d.getMonth() + 1).padStart(2, '0')}.${String(d.getDate()).padStart(2, '0')}`;
    };
    
    const todayStr = formatDate(today);
    const yesterdayStr = formatDate(yesterday);
    const dayBeforeYesterdayStr = formatDate(dayBeforeYesterday);
    
    if (dateStr === todayStr) {
      displayDate += ' 今天';
    } else if (dateStr === yesterdayStr) {
      displayDate += ' 昨天';
    } else if (dateStr === dayBeforeYesterdayStr) {
      displayDate += ' 前天';
    }
    
    daysArray.push({
      date: displayDate,
      dateStr: dateStr
    });
  }
  
  // 按日期倒序排序
  daysArray.sort((a, b) => {
    const dateA = new Date(`${year.value}-${a.dateStr.replace('.', '-')}`);
    const dateB = new Date(`${year.value}-${b.dateStr.replace('.', '-')}`);
    return dateB.getTime() - dateA.getTime();
  });
  
  days.value = daysArray;
};

// 组件挂载时生成日期数据
onMounted(() => {
  generateDays();
});

// 监听年月变化，重新生成日期数据
watch(() => [props.year, props.month], (newValues) => {
  year.value = newValues[0];
  month.value = newValues[1];
  generateDays();
}, { deep: true });
</script>

<style scoped>
.expense-records {
  margin: 0 0 20px 0;
  padding: 0 15px;
}
</style>