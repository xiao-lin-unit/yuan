<template>
  <div class="income-records">
    <DailyIncome 
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
import dayjs from 'dayjs';
import DailyIncome from './DailyIncome.vue';

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

  // 获取当月最后一天
  let lastDay = dayjs().year(yearVal).month(monthVal).endOf('month');
  const now = dayjs();
  // 如果当前年份大于展示年份，则展示到月份的最后一天
  if (now.year() > yearVal) {

    // 如果年份相同，当前月份大于展示月份，则展示到月份的最后一天
  } else if (now.year() === yearVal && now.month() > monthVal) {
    
    // 如果年份相同，当前月份等于展示月份，则展示到今天
  } else if (now.year() === yearVal && now.month() === monthVal) {
    lastDay = now;
    // 如果当前年份小于展示年份，或者当前年份等于展示年份但当前月份小于展示月份，则不展示内容
  } else {
    days.value = [];
    return;
  }
  // 获取当月天数
  const daysInMonth = lastDay.date();
  
  const daysArray = [];
  
  // 生成当月的每一天
  for (let day = 1; day <= daysInMonth; day++) {
    const dateStr = `${String(monthVal + 1).padStart(2, '0')}.${String(day).padStart(2, '0')}`;
    
    // 标记今天、昨天、前天
    let displayDate = dateStr;
    const today = dayjs();
    const yesterday = today.subtract(1, 'day');
    const dayBeforeYesterday = today.subtract(2, 'day');
    
    const formatDate = (d: dayjs.Dayjs) => {
      return `${String(d.month() + 1).padStart(2, '0')}.${String(d.date()).padStart(2, '0')}`;
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
    const dateA = dayjs(`${year.value}-${a.dateStr.replace('.', '-')}`);
    const dateB = dayjs(`${year.value}-${b.dateStr.replace('.', '-')}`);
    return dateB.valueOf() - dateA.valueOf();
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
.income-records {
  margin: 0 0 20px 0;
  padding: 0 15px;
}
</style>
