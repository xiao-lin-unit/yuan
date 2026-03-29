<template>
  <div class="weekly-finance-section">
    <div class="section-header">
      <h3>本周支出</h3>
    </div>
    <div class="weekly-total">总计: ¥6,629.50</div>
    <div class="finance-chart">
      <div class="chart-container">
        <div class="chart-bar">
          <div class="bar-value">15</div>
          <div class="bar-container">
            <div class="bar" style="height: 2%;"></div>
          </div>
          <div class="bar-label">周日</div>
        </div>
        <div class="chart-bar">
          <div class="bar-value">11</div>
          <div class="bar-container">
            <div class="bar" style="height: 1%;"></div>
          </div>
          <div class="bar-label">周一</div>
        </div>
        <div class="chart-bar">
          <div class="bar-value">0</div>
          <div class="bar-container">
            <div class="bar" style="height: 0%;"></div>
          </div>
          <div class="bar-label">周二</div>
        </div>
        <div class="chart-bar">
          <div class="bar-value">6.14K</div>
          <div class="bar-container">
            <div class="bar" style="height: 90%;"></div>
          </div>
          <div class="bar-label">周三</div>
        </div>
        <div class="chart-bar">
          <div class="bar-value">25</div>
          <div class="bar-container">
            <div class="bar" style="height: 3%;"></div>
          </div>
          <div class="bar-label">周四</div>
        </div>
        <div class="chart-bar">
          <div class="bar-value">362</div>
          <div class="bar-container">
            <div class="bar" style="height: 6%;"></div>
          </div>
          <div class="bar-label">周五</div>
        </div>
        <div class="chart-bar">
          <div class="bar-value">76.5</div>
          <div class="bar-container">
            <div class="bar" style="height: 1%;"></div>
          </div>
          <div class="bar-label">周六</div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
// 可以添加本周收支相关的逻辑
</script>

<style scoped>
.weekly-finance-section {
  background-color: white;
  border-radius: 12px;
  padding: 15px;
  margin: 0 0 20px 0;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.05);
}

.section-header {
  display: flex;
  align-items: center;
  margin-bottom: 15px;
}

.section-header h3 {
  font-size: 16px;
  margin: 0;
  color: #303133;
}

.weekly-total {
  font-size: 14px;
  color: #606266;
  margin-bottom: 15px;
}

.finance-chart {
  margin-top: 20px;
}

.chart-container {
  display: flex;
  justify-content: space-around;
  align-items: flex-end;
  height: 180px;
}

.chart-bar {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 5px;
  width: 30px;
  position: relative;
  height: 100%;
}

.chart-bar .bar-container {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: flex-end;
  width: 8px;
}

.chart-bar .bar {
  width: 8px;
  background-color: #67c23a;
  border-radius: 4px 4px 0 0;
}

.bar-value {
  font-size: 10px;
  color: #606266;
  text-align: center;
  margin-bottom: 5px;
}

.bar-label {
  font-size: 10px;
  color: #909399;
  text-align: center;
  margin-top: 5px;
}

/* 响应式调整 */
@media (max-width: 375px) {
  .chart-container {
    height: 140px;
  }
}

@media (max-width: 320px) {
  .chart-container {
    height: 120px;
  }
}
</style>