<template>
  <div class="asset-card" :style="cardStyle" @click="handleClick">
    <div class="card-header">
      <h3>{{ title }}</h3>
      <div class="card-icon" v-if="icon">
        <img v-if="isImage" :src="icon" :alt="title" />
        <span v-else>{{ icon }}</span>
      </div>
    </div>
    <div class="card-code">{{ code || '-' }}</div>
    <div class="card-content">
    <div class="amount-section">
        <div class="overview-label">金额</div>
        <div class="overview-value">¥{{ amount.toFixed(2) }}</div>
      </div>
    </div> 
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';

const props = defineProps({
  title: {
    type: String,
    default: '默认样式'
  },
  amount: {
    type: Number,
    default: 0
  },
  icon: {
    type: String,
    default: '💳'
  },
  color: {
    type: String,
    default: '#1890ff'
  },
  assetId: {
    type: String,
    default: ''
  },
  code: {
    type: String,
    default: ''
  },
});

const emit = defineEmits(['click']);

const cardStyle = computed(() => {
  return {
    '--card-color': props.color
  };
});

const isImage = computed(() => {
  return props.icon.startsWith('http') || props.icon.startsWith('/');
});

const handleClick = () => {
  emit('click', props.assetId);
};
</script>

<style scoped>
.asset-card {
  background: linear-gradient(135deg, var(--card-color, #1890ff) 0%, rgba(24, 144, 255, 0.8) 100%);
  border-radius: 16px;
  padding: 15px;
  color: white;
  box-shadow: 0 4px 12px rgba(24, 144, 255, 0.3);
  position: relative;
  overflow: hidden;
  height: 100px;
  display: flex;
  flex-direction: column;
  cursor: pointer;
  transition: transform 0.2s ease;
}

.asset-card:active {
  transform: scale(0.98);
}

.asset-card::before {
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

.card-icon {
  font-size: 20px;
  
  img {
    width: 20px;
    height: 20px;
    object-fit: cover;
    border-radius: 4px;
  }
}

.card-code {
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
.overview-label {
  font-size: 12px;
  opacity: 0.85;
  margin-bottom: 2px;
}

.overview-value {
  font-size: 22px;
  font-weight: bold;
  line-height: 1.2;
}

</style>