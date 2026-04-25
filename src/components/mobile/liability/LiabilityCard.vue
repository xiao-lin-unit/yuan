<template>
  <div class="liability-card" :style="cardStyle" @click="handleClick">
    <div class="card-header">
      <h3>{{ title }}</h3>
      <div class="card-badge" :class="statusClass">{{ status }}</div>
    </div>
    <div class="card-type">{{ type }}</div>

    <div class="card-content">
      <div class="amount-section">
        <div class="remaining-label">剩余待还</div>
        <div class="remaining-value">¥{{ totalRemaining.toFixed(2) }}</div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';

const props = defineProps({
  title: { type: String, default: '' },
  type: { type: String, default: '' },
  principal: { type: Number, default: 0 },
  remaining: { type: Number, default: 0 },
  remainingInterest: { type: Number, default: 0 },
  interestRate: { type: Number, default: 0 },
  repaymentMethod: { type: String, default: '' },
  status: { type: String, default: '未结清' },
  color: { type: String, default: '#ff6b6b' },
  liabilityId: { type: String, default: '' }
});

const emit = defineEmits(['click']);

const cardStyle = computed(() => {
  return {
    '--card-color': props.color
  };
});

const statusClass = computed(() => {
  return props.status === '已结清' ? 'settled' : 'unsettled';
});

const totalRemaining = computed(() => {
  return props.remaining + props.remainingInterest;
});

const handleClick = () => {
  emit('click', props.liabilityId);
};
</script>

<style scoped>
.liability-card {
  background: linear-gradient(135deg, var(--card-color, #1890ff) 0%, rgba(24, 144, 255, 0.8) 100%);
  border-radius: 16px;
  padding: 15px;
  color: white;
  box-shadow: 0 4px 12px rgba(24, 144, 255, 0.3);
  position: relative;
  overflow: hidden;
  display: flex;
  flex-direction: column;
  height: 100px;
  cursor: pointer;
  transition: transform 0.2s ease;
}

.liability-card:active {
  transform: scale(0.98);
}

.liability-card::before {
  content: '';
  position: absolute;
  top: -50%;
  right: -50%;
  width: 200%;
  height: 200%;
  background: radial-gradient(circle, rgba(255, 255, 255, 0.1) 0%, transparent 70%);
  border-radius: 50%;
  transform: rotate(45deg);
}

.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 4px;
  position: relative;
  z-index: 1;
}

.card-header h3 {
  margin: 0;
  font-size: 15px;
  font-weight: 600;
}

.card-badge {
  font-size: 11px;
  padding: 2px 8px;
  border-radius: 10px;
  font-weight: 500;
}

.card-badge.unsettled {
  background: rgba(255, 255, 255, 0.25);
}

.card-badge.settled {
  background: rgba(103, 194, 58, 0.8);
}

.card-type {
  font-size: 12px;
  opacity: 0.85;
  margin-bottom: 12px;
  position: relative;
  z-index: 1;
}

.card-content {
  position: relative;
  z-index: 1;
  flex: 1;
  display: flex;
  flex-direction: column;
  justify-content: flex-end;
  margin-top: 10px;
}

.amount-section {
  margin-bottom: 10px;
}

.remaining-label {
  font-size: 12px;
  opacity: 0.85;
  margin-bottom: 2px;
}

.remaining-value {
  font-size: 22px;
  font-weight: bold;
  line-height: 1.2;
}

.card-meta {
  display: flex;
  flex-wrap: wrap;
  gap: 8px 16px;
  margin-bottom: 10px;
}

.meta-item {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.meta-label {
  font-size: 11px;
  opacity: 0.75;
}

.meta-value {
  font-size: 12px;
  font-weight: 500;
}

.progress-bar {
  height: 4px;
  background: rgba(255, 255, 255, 0.25);
  border-radius: 2px;
  overflow: hidden;
  position: relative;
  z-index: 1;
  margin-bottom: 4px;
}

.progress-fill {
  height: 100%;
  background: rgba(255, 255, 255, 0.8);
  border-radius: 2px;
  transition: width 0.3s ease;
}

.progress-label {
  font-size: 11px;
  opacity: 0.8;
  text-align: right;
  position: relative;
  z-index: 1;
}
</style>
