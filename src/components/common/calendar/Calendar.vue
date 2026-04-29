<template>
  <div class="calendar-container text-unselect" :style="{width: width}">
    <div class="calendar-header">
      <div class="ch-now" style="display: none;">
        <div class="now-time" :time-show="`${timeShow} (星期${daysOfWeek[currentDate.day() == 0 ? 6 : currentDate.day() - 1]})`">{{ year }}年{{ month + 1 }}月{{ day }}日</div>
      </div>
      <div class="now-select">
          <div class="ch-title" @click="selectDate(null)"><label style="font-weight: 600;">{{ currentDateObj.star }}座</label><br/>探索每一天精彩内容</div>
          <div class="ch-select" style="display: none;">
            <div style="width:80px; font-size: 12px;">年份</div>
            <el-date-picker v-model="formDay.year" type="year" size="small" :editable="false" :clearable="false" format="YYYY" value-format="YYYY" @change="changeYear"/>
            <div style="width: 80px; font-size: 12px; margin-left: 10px;">月份</div>
            <el-date-picker v-model="formDay.month" type="month"  size="small" :editable="false" :clearable="false"  format="MM" value-format="MM" @change="changeMonth"/>
            <div class="now-btn" @click="toNowEvent">Now</div>
          </div>
      </div>
    </div>
    <div class="calendar-toolbar text-unselect">
      <div class="toolbar-item" v-for="day in daysOfWeek" :key="day">
        <div :style="{color: day == '六' || day == '日' ? 'red' : 'blank' }">{{ day }}</div>
      </div>
    </div>
    <div class="calendar-body text-unselect" :data-month="currentDateObj.month">
      <div class="calendar-cell" v-for="(date, index) in calendarPage" :key="index">
        <div class="calendar-cell-item" 
            :style="{ color: index % 7 == 6 || index % 7 == 5 ? 'red' : 'blank', opacity: date.isCurrentMonth ? 0.9 : 0.3 }"
            :class="{
              rest: date.rest,
              active: currentDateObj.dateStr == date.dateStr, 
              toDay: date.dateStr == getCurrentDate().format('YYYY-MM-DD'),
              'has-amount': amount[date.dateStr]
            }"
            @click="selectDate(date)"
          >
            <div style="font-size: 14px; font-family: fangsong;">{{ date.day }}</div>
            <div v-if="amount[date.dateStr] && date.isCurrentMonth" class="amount-class" :style="{ color: type == 'expense' ? '#67c23a' : '#f56c6c' }">
                ¥{{ amount[date.dateStr] }}
            </div>
            <div v-else style="font-size: 8px; font-weight: 500; color: blank;">{{ date.lunar }}</div>
          </div>
      </div>
    </div>
    <div class="calendar-footer" v-if="isWideScreen">
      <div class="footer-card">
        <div style="flex: 2; display: flex; align-items: center; justify-content: left; width: 100%;">
            <div style="font-family: CALENDAR_FONT; font-weight: bold; color: #333; width: 30%;">
              <div style="font-size: 18px;  margin-bottom: 5px;">{{ currentDateObj.lunarStr }}</div>
              <div style="font-size: 14px; ">{{ currentDateObj.lunaryear }} 年</div>
            </div>
            <div style="font-size: 14px; font-family: Arial, sans-serif; color: #333; width: 70%;">
              <div style="overflow: hidden;white-space: nowrap; margin-bottom: 5px; text-overflow: ellipsis; height: 20px; width:  100%;">
                <span style="color: white; background-color: red; padding: 1px; border-radius: 5px; margin-right: 5px;">宜</span> {{ currentDateObj.favorable }}
              </div>
              <div style="overflow: hidden;white-space: nowrap; text-overflow: ellipsis; width:  100%; height: 20px;">
                <span style="color: white; background-color: #333; padding: 1px; border-radius: 5px; margin-right: 5px;" >忌</span> {{ currentDateObj.adverse }}
              </div>
            </div>
        </div>
        <div style="flex: 1; font-size: 14px; border-top: 1px solid #ccc; padding-top: 5px; display: flex; align-items: center;">
            <el-icon style="margin-right: 10px; color: gray;"><Clock /></el-icon>{{ currentDateObj.desc }}
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted, computed, onBeforeUnmount, watch } from 'vue';
import { format, startOfMonth, endOfMonth, eachDayOfInterval, getDay, addDays } from 'date-fns';
// https://6tail.cn/calendar/api.html  农历信息
import { Solar, Lunar, HolidayUtil } from 'lunar-javascript';
import { Clock } from '@element-plus/icons-vue';
import { getCurrentDate } from '../../utils/timezone';

const props = defineProps({
  width: { type: String, default: '500px' },
  height: { type: String, default: '600px' },
  year: { type: Number, default: getCurrentDate().year() },
  month: { type: Number, default: getCurrentDate().month() + 1 },
  amount: { type: Object, default: () => ({}) },
  type: { type: String, default: 'expense' },
});

// 响应式判断屏幕宽度
const isWideScreen = ref(window.innerWidth >= 768);

// 监听窗口大小变化
const handleResize = () => {
  isWideScreen.value = window.innerWidth >= 768;
};

onMounted(() => {
  window.addEventListener('resize', handleResize);
});

onBeforeUnmount(() => {
  window.removeEventListener('resize', handleResize);
});
const daysOfWeek = ['一', '二', '三', '四', '五', '六', '日'];

// 初始化当前日期
const currentDate = getCurrentDate();
const currentDateObj = ref(makeDate(currentDate.toDate(), true));
const year = ref(currentDate.year());
const month = ref(currentDate.month());
const day = ref(currentDate.date());
const calendarPage = ref([]);
const timeShow = ref(getCurrentDate().format('HH:mm:ss'));
var daysUntilNextYear = null;
const formDay = ref({
  year: year.value + '',
  month: (month.value) + 1 + '',
})

// 计算当月的日期数组
/**
 * 计算指定月份的 42 个日期对象
 * @param {number} year - 年份
 * @param {number} month - 月份（0-11）
 * @returns {Array} - 包含 42 个日期对象的数组
 */
function makeDate(date, isCurrentMonth) {
  return fillNongLi({
      date: date,
      year: date.getFullYear(),
      month: date.getMonth() + 1, // 月份从 0 开始，所以加 1
      day: date.getDate(),
      isCurrentMonth: isCurrentMonth,
      dateStr: format(date, 'yyyy-MM-dd'),
    });
}

// 定义一个函数来计算当前时间距离下一年1月1日的天数
function daysUntilNextYearJanuaryFirst() {
  // 获取当前日期
  const now = getCurrentDate();

  // 计算下一年1月1日的日期
  const nextYear = now.year() + 1;
  const nextYearJanuaryFirst = getCurrentDate().year(nextYear).month(0).date(1);

  // 计算当前日期和下一年1月1日之间的毫秒差
  const timeDifference = nextYearJanuaryFirst.valueOf() - now.valueOf();

  // 将毫秒差转换为天数
  const daysDifference = Math.ceil(timeDifference / (1000 * 60 * 60 * 24));

  return daysDifference;
}
// 填充农历信息
function fillNongLi(date) {
      // 设置农历信息 或者 节日
    let nongli = Lunar.fromDate(date.date);
    let xingzuo = Solar.fromDate(date.date);
    date.lunar = nongli.getDayInChinese();
    date.lunarStr = nongli.getMonthInChinese() + '月' + nongli.getDayInChinese();
    date.lunaryear = nongli.getYearInGanZhi() + nongli.getYearShengXiao();
    date.favorable = nongli.getDayYi()?.join(', ');
    date.adverse = nongli.getDayJi()?.join(', ');
    date.star = xingzuo.getXingZuo();
    date.desc = '距离 ' + (getCurrentDate().year() + 1) + ' 年元旦 还有' + daysUntilNextYear + '天';
    return date;
}
function getCalendarDates(year, month) {
  // 获取指定月份的第一天和最后一天
  const firstDayOfMonth = startOfMonth(getCurrentDate().year(year).month(month).toDate());
  const lastDayOfMonth = endOfMonth(getCurrentDate().year(year).month(month).toDate());

  // 计算当月的日期数组
  const daysInMonth = eachDayOfInterval({ start: firstDayOfMonth, end: lastDayOfMonth });

  // 找到当月第一天是星期几（0 表示星期日）
  let startDayOfWeek = getDay(firstDayOfMonth);
  if (startDayOfWeek === 0) {
    startDayOfWeek = 7;
  }

  // 创建 42 个格子的日期数组
  let allDates = [];

  // 填充上个月的日期
  for (let i = 1; i < startDayOfWeek; i++) {
    const prevDate = addDays(firstDayOfMonth, -startDayOfWeek + i);
    allDates.push(makeDate(prevDate, false));
  }

  // 填充当月的日期
  daysInMonth.forEach(day => allDates.push(makeDate(day, true)));

  // 填充下个月的日期直到有 42 个元素
  while (allDates.length < 42) {
    const nextDate = addDays(lastDayOfMonth, allDates.length - daysInMonth.length + 2 - startDayOfWeek);
    allDates.push(makeDate(nextDate, false));
  }
  // 设置农历或者节假日信息
  allDates.forEach((date, index) => {
    // 设置农历信息
    fillNongLi(date);
    // 节气
    var j = Lunar.fromDate(date.date);
    if (j && j.getJieQi()) {
      date.lunar = j.getJieQi();
    }
    // 节假日
    let d = HolidayUtil.getHoliday(Number(date.year), Number(date.month), Number(date.day));
    // 今天不做处理
    if (!(date.dateStr == getCurrentDate().format('YYYY-MM-DD'))) {
      // 默认周末 
      date.rest = (index % 7 === 5 || index % 7 === 6);
      if (d && d.getName()) {
        date.rest = !d.isWork();
      }
    }
    // 设置假日名
    if(d && d.getName() && d.getTarget() && d.getTarget() == date.dateStr) {
      date.lunar = d.getName();
    }

  });
  return allDates;
}

// 年份变化
const changeYear = y => {
  currentDateObj.value.year = y + '';
  fillNongLi(currentDateObj.value);
  calendarPage.value = getCalendarDates(Number(formDay.value.year), Number(formDay.value.month) - 1);
}

// 月份变化
const changeMonth = m => {
  currentDateObj.value.month = m + '';
  fillNongLi(currentDateObj.value);
  calendarPage.value = getCalendarDates(Number(formDay.value.year), Number(formDay.value.month) - 1);
}

// 回调 当拖动变化的时候
const emits = defineEmits(['click']);
// 选择日期触发事件
const selectDate = (date) => {
  if (date) {
    currentDateObj.value = date;
    emits('click', currentDateObj.value);
  } else {
    emits('click', makeDate(getCurrentDate().toDate(), true));
  }
}

// 恢复当前日期
const toNowEvent = () => {
  currentDateObj.value = makeDate(getCurrentDate().toDate(), true);
  calendarPage.value = getCalendarDates(year.value, month.value);
  formDay.value.year = year.value + '';
  formDay.value.month = (month.value + 1) + '';
}

let intervalId;
onMounted(() => {
  // daysUntilNextYear = daysUntilNextYearJanuaryFirst();
  // 当组件加载时执行的操作
  toNowEvent();
  // 时间定时器
  intervalId = setInterval(() => timeShow.value = getCurrentDate().format('HH:mm:ss'), 1000); // 每秒更新时间
});
// 清除定时器
onUnmounted(() => {
  clearInterval(intervalId);
});

// 监听 props.year 和 props.month 的变化
watch(() => props.year, (newYear) => {
  if (newYear !== null && newYear !== undefined) {
    formDay.value.year = newYear + '';
    calendarPage.value = getCalendarDates(Number(formDay.value.year), Number(formDay.value.month) - 1);
  }
});

watch(() => props.month, (newMonth) => {
  if (newMonth !== null && newMonth !== undefined) {
    formDay.value.month = newMonth + '';
    calendarPage.value = getCalendarDates(Number(formDay.value.year), Number(formDay.value.month) - 1);
  }
});

// 假日更新
// https://6tail.cn/calendar/api.html#holiday-util.fix.html  节假日补充
// 2024 年： 202312300120240101202312310120240101202401010120240101202402041020240210202402101120240210202402111120240210202402121120240210202402131120240210202402141120240210202402151120240210202402161120240210202402171120240210202402181020240210202404042120240404202404052120240404202404062120240404202404072020240404202404283020240501202405013120240501202405023120240501202405033120240501202405043120240501202405053120240501202405113020240501202406084120240610202406094120240610202406104120240610202409145020240917202409155120240917202409165120240917202409175120240917202409296020241001202410016120241001202410026120241001202410036120241001202410046120241001202410056120241001202410066120241001202410076120241001202410126020241001
// HolidayUtil.fix('xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx')
// 格式：当天年月日YYYYMMDD(8位)+节假日名称下标(1位)+调休标识(1位)+节假日当天YYYYMMDD(8位)  一共18位
// 0(元旦节)  1(春节)  2(清明节)  3(劳动节)  4(端午节)  5(中秋节)  6(国庆节) 7(国庆中秋)  8(抗战胜利日)
</script>

<style scoped lang="scss">
.calendar-container {
  background-color: rgb(246, 245, 255);
  margin: 0;
  padding: 0;
  border-radius: 22px;
  display: flex;
  flex-direction: column;
  min-height: 400px;
  .calendar-header {
    position: relative;
    background-color: white;
    background-image: linear-gradient(187deg, #c6dfe7f0 20%, #c7dee57d 40%, white 70%);;
    border-radius: 20px 20px 0 0 ;
    display: flex;
    width: 100%;
    padding: 15px 20px;
    box-sizing: border-box;
    &::after {
      content: '';
      position: absolute;
      top: -15px;
      right: 30px;
      z-index: 1;
      width: 60px;
      height: 60px;
      background-image: url('/src/assets/img/rili_icon.png'); /* 图片路径 */
      background-size: cover; /* 使图片覆盖整个区域 */
      background-repeat: no-repeat; /* 防止图片重复 */
    }
    .ch-now {
      display: flex;
      width: 40%;
      min-width: 170px;
      .now-time {
          position: relative;
          width: 100%;
          font-size: 16px;
          font-family: '宋体';
          font-weight: 600;
          color: #044053e0;
          border-right: 1px solid rgba(150, 184, 201 , 0.57);
          &::after {
            content: attr(time-show);
            position: absolute;
            left: 0px;
            top: 30px;
            font-size: small;
            color: #044053a1;
          }
      }
    }
    .now-select {
      position: relative;
      width: 100%;
      .ch-title {
        margin-top: 10px;
        width: 100%;
        overflow: hidden;
        color: #20093a;
        font-size: 12px;
        &:hover {
          cursor: pointer;
          text-decoration: underline;
        }
      }
      .ch-select {
        width: 100%;
        display: flex;
        justify-content: center;
        align-items: center;
        flex-wrap: wrap;
        .now-btn {
          width: 50px; 
          margin-left: 10px; 
          margin-right: 20px; 
          cursor: pointer;
          &:hover {
            background-color: #cedaf5;
          }
        }
      }

    }
  }
  .calendar-toolbar {
    display: flex;
    padding: 10px 0;
    .toolbar-item {
      display: flex;
      flex: 1;
      background-color: #ecf4ff;
      justify-content: center;
      align-items: center;
      font-weight: 600;
    }
  }
  .calendar-body {
    position: relative;
    display: grid;
    grid-template-columns: repeat(7, 14.286%);
    grid-template-rows: repeat(6, 1fr);
    flex: 1;
    min-height: 250px;
    &::before {
      content: attr(data-month);
      position: absolute;
      top: 0;
      left: 0;
      width: 100%;
      height: 100%;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 100px;
      color: rgba(255, 0, 0, 0.03);
    }
    .calendar-cell {
      display: flex;
      flex: 1;
      justify-content: center;
      align-items: center;
      background-color: #ffffff;
      font-weight: 600;
      .calendar-cell-item {
        position: relative;
        display: flex;
        flex-direction: column;
        justify-content: center;
        align-items: center;
        width: 85%;
        height: 85%;
        cursor: pointer;
        border-radius: 10px;
        &:hover {
          background-color: #ecf4ff;
        }
        &.active {
          border: 2px solid rgb(44, 44, 211);
        }
        &.toDay {
          color: rgb(44, 44, 211) !important;
          background-color: #ecf4ff;
        }
        &.toDay::before {
            content: '今';
            position: absolute;
            width: 10px;
            height: 10px;
            top: 0;
            left: 1px;
            font-size: 7px;
        }
        &.rest {
          background-color: #fffae6c7;
        }
        &.rest::before {
            content: '休';
            position: absolute;
            width: 10px;
            height: 10px;
            top: 1px;
            right: 1px;
            font-size: 7px;
        }
        &.has-amount {
          background-color: #ecf5ff;
          border: 1px solid #d9ecff;
        }
      }
      .amount-class {
        font-size: small;
        font-weight: 500;
        // background-color: rgba(255, 255, 255, 0.8);
        // padding: 2px 8px;
        // border-radius: 10px;
        // margin-top: 2px;
      }
    }
  }
  .calendar-footer {
    position: relative;
    display: flex;
    width: 100%;
    background-color: white;
    border-radius: 0 0 20px 20px;
    align-items: center;
    justify-content: center;
    padding: 15px 0;
    .footer-card {
      position: relative;
      width: calc(100% - 60px);
      background-color: #f4f5f8;
      border-radius: 10px;
      display: flex;
      flex-direction: column;
      padding: 10px 20px;
    }
  }
}
</style>

