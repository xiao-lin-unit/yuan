<template>
  <div class="credit-card-item">
    <div class="card-icon" :class="iconClass">{{ iconText }}</div>
    <div class="card-info">
      <div class="card-header-row">
        <div class="card-name">{{ card.name }}</div>
        <div class="card-balance" v-if="card.usedLimit">{{ formatCurrency(card.usedLimit) }}</div>
      </div>
      <div class="card-progress" v-if="card.usedLimit && card.totalLimit">
        <div class="progress-bar">
          <div class="progress-fill" :style="{ width: progress + '%' }"></div>
        </div>
        <div class="card-available">额度: {{ formatCurrency(card.totalLimit) }} | 已用: {{ formatCurrency(card.usedLimit) }}</div>
      </div>
      <div class="card-details" v-if="card.days">
        <span class="card-days">{{ card.days }}</span>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'

const props = defineProps({
  card: {
    type: Object,
    required: true
  }
})

const iconClass = computed(() => {
  switch (props.card.name) {
    case '花呗':
      return 'huabei-icon'
    case '京东白条':
      return 'jingdong-icon'
    case '今日免息':
      return 'free-icon'
    default:
      return ''
  }
})

const iconText = computed(() => {
  switch (props.card.name) {
    case '花呗':
      return '花'
    case '京东白条':
      return 'JD'
    case '今日免息':
      return '免'
    default:
      return ''
  }
})

const progress = computed(() => {
  if (!props.card.usedLimit || !props.card.totalLimit || props.card.totalLimit === 0) return 0
  return (props.card.usedLimit / props.card.totalLimit) * 100
})

const formatCurrency = (value: number) => {
  return '¥' + value.toLocaleString('zh-CN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
}
</script>

<style scoped>
.credit-card-item {
  display: flex;
  align-items: center;
  padding-top: 15px;
  border-top: 1px solid #f0f0f0;
}

.credit-card-item:first-child {
  border-top: none;
  padding-top: 0;
}

.card-icon {
  width: 40px;
  height: 40px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  margin-right: 12px;
  font-size: 12px;
  font-weight: bold;
  color: white;
}

.card-icon免 {
  width: 40px;
  height: 40px;
  border-radius: 50%;
  background-color: #ff6b6b;
  display: flex;
  align-items: center;
  justify-content: center;
  margin-right: 12px;
  color: white;
  font-weight: bold;
  font-size: 12px;
}

.card-icon京东白条 {
  width: 40px;
  height: 40px;
  border-radius: 50%;
  background-color: #6a42f4;
  display: flex;
  align-items: center;
  justify-content: center;
  margin-right: 12px;
  color: white;
  font-weight: bold;
  font-size: 12px;
}

.card-info {
  flex: 1;
}

.card-header-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 5px;
}

.card-name {
  font-size: 14px;
  font-weight: normal;
  color: #333333;
}

.card-balance {
  font-size: 14px;
  font-weight: normal;
  color: #67c23a;
  margin-bottom: 0;
}

.card-details {
  display: flex;
  justify-content: space-between;
  font-size: 10px;
  color: #999999;
}

.card-status {
  padding: 2px 8px;
  background-color: #f8f9fa;
  border-radius: 10px;
  color: #67c23a;
  font-size: 10px;
}

.card-progress {
  margin-top: 10px;
}

.progress-bar {
  height: 4px;
  background-color: #ecf5ff;
  border-radius: 2px;
  overflow: hidden;
  margin-bottom: 5px;
}

.progress-fill {
  height: 100%;
  background-color: #409eff;
  border-radius: 2px;
}

.card-available {
  font-size: 10px;
  color: #999999;
}

.free-icon {
  background-color: #ff6b6b;
}

.huabei-icon {
  background-color: #1677ff;
}

.jingdong-icon {
  background-color: #e1251b;
}

.card-days {
  font-size: 12px;
  color: #999999;
}
</style>