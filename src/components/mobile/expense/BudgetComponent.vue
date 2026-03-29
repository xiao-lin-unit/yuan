<template>
  <div class="budget-section">
    <div class="section-header">
      <h3>预算</h3>
      <el-icon class="more-icon"><More /></el-icon>
    </div>
    <div class="budget-details">
      <div class="budget-item">
        <span class="budget-label">剩余:</span>
        <span class="budget-value">--</span>
      </div>
      <div class="budget-item">
        <span class="budget-label">总额:</span>
        <span class="budget-value">未设置</span>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { More } from '@element-plus/icons-vue';

// 可以添加预算相关的逻辑
</script>

<style scoped>
.budget-section {
  background-color: white;
  border-radius: 12px;
  padding: 15px;
  margin: 0 0 20px 0;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.05);
}

.section-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 15px;
}

.section-header h3 {
  font-size: 16px;
  margin: 0;
  color: #303133;
}

.more-icon {
  color: #909399;
  font-size: 18px;
}

.budget-details {
  display: flex;
  justify-content: space-between;
}

.budget-item {
  display: flex;
  align-items: center;
  gap: 10px;
}

.budget-label {
  font-size: 14px;
  color: #606266;
}

.budget-value {
  font-size: 14px;
  color: #303133;
  font-weight: bold;
}
</style>