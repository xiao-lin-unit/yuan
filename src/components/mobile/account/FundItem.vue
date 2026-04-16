<template>
  <div class="fund-item" @click="handleClick">
    <div class="fund-icon" :class="'fund-icon'">
      {{ fund.name.charAt(0) }}
    </div>
    <div class="fund-name">{{ fund.name }}</div>
    <div class="fund-balance">{{ formatCurrency(fund.balance) }}</div>
  </div>
</template>

<script setup lang="ts">
const props = defineProps({
  fund: {
    type: Object,
    required: true
  }
})

const emit = defineEmits(['click'])

const formatCurrency = (value: number) => {
  return '¥' + value.toLocaleString('zh-CN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
}

const handleClick = () => {
  emit('click', props.fund.id)
}
</script>

<style scoped>
.fund-item {
  display: flex;
  align-items: center;
  padding: 15px 0;
  border-top: 1px solid #f0f0f0;
  cursor: pointer;
}

.fund-item:active {
  background-color: #f5f5f5;
}

.fund-item:first-child {
  border-top: none;
  padding-top: 0;
}

.fund-icon {
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

.fund-name {
  flex: 1;
  font-size: 14px;
  font-weight: normal;
  color: #333333;
}

.fund-balance {
  font-size: 14px;
  font-weight: normal;
  color: #333333;
}
</style>