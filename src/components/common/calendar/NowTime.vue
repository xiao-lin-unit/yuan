<template>  
    <div class="ch-now" :style="{display: visiable ? 'flex' : 'none'}">
        <div class="now-time" :time-show="`${timeShow} (星期${daysOfWeek[currentDate.day() == 0 ? 6 : currentDate.day() - 1]})`">{{ year }}年{{ month + 1 }}月{{ day }}日</div>
      </div>
</template>
<script setup>
import { ref, onMounted } from 'vue';
import { getCurrentDate } from '../../utils/timezone';

const props = defineProps({
  visiable: { type: Boolean, default: false },
});

const daysOfWeek = ['一', '二', '三', '四', '五', '六', '日'];
const currentDate = getCurrentDate();
const year = ref(currentDate.year());
const month = ref(currentDate.month());
const day = ref(currentDate.date());
const timeShow = ref(getCurrentDate().format('HH:mm:ss'));
let intervalId;

onMounted(() => {
  intervalId = setInterval(() => timeShow.value = getCurrentDate().format('HH:mm:ss'), 1000); // 每秒更新时间
});
</script>
<style scoped lang="scss">
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
</style>