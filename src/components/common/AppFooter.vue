<template>
  <div class="bottom-nav">
    <div class="nav-item" @click="$emit('navigate', 'expense')">
      <el-icon><Minus /></el-icon>
      <span>支出</span>
    </div>
    <div class="nav-item" @click="$emit('navigate', 'income')">
      <el-icon><Plus /></el-icon>
      <span>收入</span>
    </div>
    <div class="nav-item" @click="$emit('navigate', 'asset')">
      <el-icon><TrendCharts /></el-icon>
      <span>资产</span>
    </div>
    <div class="nav-item" @click="$emit('navigate', 'liability')">
      <el-icon><Warning /></el-icon>
      <span>负债</span>
    </div>
    <div class="nav-item" @click="$emit('navigate', 'more')">
      <el-icon><More /></el-icon>
      <span>更多</span>
    </div>
  </div>
</template>

<script setup lang="ts">
import { TrendCharts, Warning, More, Minus, Plus } from '@element-plus/icons-vue'

defineEmits<{
  (e: 'navigate', key: string): void
}>()
</script>

<style scoped>
.bottom-nav {
  display: flex;
  justify-content: space-around;
  align-items: center;
  background-color: white;
  padding: 10px 0;
  box-shadow: 0 -2px 4px rgba(0, 0, 0, 0.1);
  z-index: 100;
  flex-shrink: 0;
}

.nav-item {
  display: flex;
  flex-direction: column;
  align-items: center;
  cursor: pointer;
  padding: 5px 10px;
  transition: all 0.2s;
  flex: 1;
}

.nav-item:hover {
  color: #409EFF;
}

.nav-item :deep(el-icon) {
  font-size: 20px;
  margin-bottom: 4px;
}

.nav-item span {
  font-size: 12px;
  color: #606266;
}

.nav-item:hover span {
  color: #409EFF;
}

/* 响应式调整 */
@media (max-width: 375px) {
  .nav-item :deep(el-icon) {
    font-size: 18px;
  }
  
  .nav-item span {
    font-size: 11px;
  }
}

@media (max-width: 320px) {
  .bottom-nav {
    padding: 8px 0;
  }
  
  .nav-item :deep(el-icon) {
    font-size: 16px;
  }
  
  .nav-item span {
    font-size: 10px;
  }
}
</style>