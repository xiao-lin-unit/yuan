<template>
  <div class="credit-card-item" @click="handleClick">
    <div class="card-icon">{{ card.name.charAt(0) }}</div>
    <div class="card-info">
      <div class="card-header-row">
        <div class="card-name">{{ card.name }}</div>
        <div class="card-balance" v-if="card.used_limit">{{ formatCurrency(card.used_limit) }}</div>
      </div>
      <div class="card-progress" v-if="card.used_limit && card.total_limit">
        <div class="progress-bar">
          <div class="progress-fill" :style="{ width: progress + '%' }"></div>
        </div>
        <div class="card-available">额度: {{ formatCurrency(card.total_limit) }} | 已用: {{ formatCurrency(card.used_limit) }}</div>
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

const progress = computed(() => {
  if (!props.card.used_limit || !props.card.total_limit || props.card.total_limit === 0) return 0
  return (props.card.used_limit / props.card.total_limit) * 100
})

const emit = defineEmits(['click'])

const formatCurrency = (value: number) => {
  return '¥' + value.toLocaleString('zh-CN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
}

const handleClick = () => {
  emit('click', props.card.id)
}
</script>

<style scoped>
.credit-card-item {
  display: flex;
  align-items: center;
  padding-top: 15px;
  border-top: 1px solid #f0f0f0;
  cursor: pointer;
}

.credit-card-item:active {
  background-color: #f5f5f5;
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
  background-color: #409eff;
  justify-content: center;
  margin-right: 12px;
  font-size: 12px;
  font-weight: bold;
  color: white;
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