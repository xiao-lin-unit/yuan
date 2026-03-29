<template>
  <div class="monthly-stats">
    <div class="background-image">
      <img src="https://trae-api-cn.mchost.guru/api/ide/v1/text_to_image?prompt=hot air balloons in Cappadocia landscape&image_size=landscape_16_9" alt="背景" />
      <div class="financial-overview">
        <div class="overview-item">
          <div class="overview-label">月支出</div>
          <div class="overview-amount expense">¥{{ expense.toFixed(2) }}</div>
        </div>
        <div class="overview-details">
          <div class="detail-item">
            <span class="detail-label">月收入</span>
            <span class="detail-value income">¥{{ income.toFixed(2) }}</span>
          </div>
          <div class="detail-item">
            <span class="detail-label">本月结余</span>
            <span class="detail-value" :class="{ 'balance-negative': balance < 0, 'balance-positive': balance >= 0 }">¥{{ balance.toFixed(2) }}</span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
// 定义收支数据
const expense = 6910.90;
const income = 1042.11;
// 计算本月结余
const balance = income - expense;
</script>

<style scoped>
.monthly-stats {
  margin: 0 0 20px 0;
}

/* 背景图部分 */
.background-image {
  position: relative;
  height: 200px;
  overflow: hidden;
  border-radius: 0 0 20px 20px;
}

.background-image img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.financial-overview {
  position: absolute;
  bottom: 0;
  left: 0;
  right: 0;
  padding: 20px;
  background: linear-gradient(to top, rgba(0, 0, 0, 0.7), transparent);
  color: white;
}

.overview-item {
  margin-bottom: 10px;
}

.overview-label {
  font-size: 14px;
  opacity: 0.9;
  margin-bottom: 5px;
}

.overview-amount {
  font-size: 24px;
  font-weight: bold;
}

.expense {
  color: #67c23a;
}

.overview-details {
  display: flex;
  justify-content: space-between;
  font-size: 12px;
}

.detail-item {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.detail-label {
  opacity: 0.8;
}

.detail-value {
  font-weight: bold;
}

.income {
  color: #f56c6c;
}

.balance-negative {
  color: #67c23a;
}

.balance-positive {
  color: #f56c6c;
}

/* 响应式调整 */
@media (max-width: 375px) {
  .background-image {
    height: 180px;
  }
  
  .overview-amount {
    font-size: 20px;
  }
}

@media (max-width: 320px) {
  .background-image {
    height: 160px;
  }
  
  .overview-amount {
    font-size: 18px;
  }
}
</style>