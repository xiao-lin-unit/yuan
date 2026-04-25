<template>
  <div class="stats">
    <div class="background-image">
      <img :src="background || img" alt="背景" />
      <div class="overview-main">
        <div class="overview-item">
          <template v-for="item in main.slice(0, 2)">
            <div class="overview-label">{{ item.title }}</div>
            <div class="overview-value" :style="{ color: item.color || 'white' }">{{ item.value }}</div>
          </template>
        </div>
        <div class="overview-details">
          <template v-for="item in details.slice(0, 3)">
            <div class="detail-item">
              <span class="detail-label">{{ item.title }}</span>
              <span class="detail-value" :style="{ color: item.color || 'white' }">{{ item.value }}</span>
            </div>
          </template>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">

import img from '@/assets/img/m1.jpg';

const props = defineProps<{
  background: string;
  main: { title: string; value: number | string; color: string | undefined | null }[]
  details: { title: string; value: number | string; color: string | undefined | null }[];
}>();

</script>

<style scoped>
.stats {
  margin: 0 0 20px 0;
}

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

.overview-main {
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

.overview-value {
  font-size: 24px;
  font-weight: bold;
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

@media (max-width: 375px) {
  .background-image {
    height: 180px;
  }

  .overview-value {
    font-size: 20px;
  }
}

@media (max-width: 320px) {
  .background-image {
    height: 160px;
  }

  .overview-value {
    font-size: 18px;
  }
}
</style>