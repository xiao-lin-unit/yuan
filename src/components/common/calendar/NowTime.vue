<template>  
    <div class="ch-now" :style="{display: visiable ? 'flex' : 'none'}">
        <div class="now-time" :time-show="`${timeShow} (星期${daysOfWeek[currentDate.getDay() == 0 ? 6 : currentDate.getDay() - 1]})`">{{ year }}年{{ month + 1 }}月{{ day }}日</div>
      </div>
</template>
<script setup>
import { ref, computed, onMounted } from 'vue';

const props = defineProps({
  visiable: { type: Boolean, default: false },
});

const daysOfWeek = ['一', '二', '三', '四', '五', '六', '日'];
const currentDate = new Date();
const year = ref(currentDate.getFullYear());
const month = ref(currentDate.getMonth());
const day = ref(currentDate.getDate());
const timeShow = ref(format(currentDate, 'HH:mm:ss'));
let intervalId;

onMounted(() => {
  intervalId = setInterval(() => timeShow.value = format(new Date(), 'HH:mm:ss'), 1000); // 每秒更新时间
});
</script>
<style  scoped lang="scss>
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