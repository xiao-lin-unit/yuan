<template>
  <div class="category-item" :class="{ 'selected': isSelected }" @click="$emit('select', category.id)">
    <div class="category-icon" :class="category.icon">{{ category.iconText }}</div>
    <div class="category-name">{{ category.name }}</div>
  </div>
</template>

<script setup lang="ts">
defineProps<{
  category: {
    id: string
    name: string
    icon: string
    iconText: string
  }
  isSelected: boolean
}>()

defineEmits<{
  (e: 'select', id: string): void
}>()
</script>

<style scoped>
.category-item {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8px;
  cursor: pointer;
  transition: all 0.2s ease;
  border-radius: 8px;
}

.category-item.selected {
  background-color: #e3f2fd;
  box-shadow: 0 4px 12px rgba(64, 158, 255, 0.3);
  transform: translateY(-2px);
}

.category-item.selected .category-icon {
  background-color: #409eff;
  color: white;
}

.category-item.selected .category-name {
  color: #409eff;
  font-weight: 600;
}

.category-icon {
  width: 44px;
  height: 44px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 18px;
  background-color: #f0f0f0;
  transition: all 0.2s ease;
}

.category-name {
  font-size: 12px;
  color: #666666;
  text-align: center;
  transition: all 0.2s ease;
}
</style>