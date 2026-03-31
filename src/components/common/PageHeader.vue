<template>
  <div class="page-header">
    <el-icon @click="$emit('back')">
      <ArrowLeft />
    </el-icon>
    <h1>{{ title }}</h1>
    <div class="placeholder"></div>
  </div>
</template>

<script setup lang="ts">
import { ArrowLeft } from '@element-plus/icons-vue'

defineProps<{
  title: string
}>()

defineEmits<{
  (e: 'back'): void
}>()
</script>

<style scoped>
.page-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 16px;
  background-color: white;
  border-bottom: 1px solid #e0e0e0;
  z-index: 100;
  flex-shrink: 0;
}

.page-header h1 {
  font-size: 16px;
  font-weight: bold;
  color: #333333;
  margin: 0;
}

.page-header .placeholder {
  width: 24px;
}

.page-header :deep(.el-icon) {
  font-size: 20px;
  color: #333333;
  cursor: pointer;
  transition: color 0.2s ease;
}

.page-header :deep(.el-icon):hover {
  color: #409eff;
}
</style>
