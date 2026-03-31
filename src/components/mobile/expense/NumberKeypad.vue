<template>
  <div class="keypad-section">
    <div class="keypad-row">
      <div class="keypad-item" @click="$emit('number-click', '1')">1</div>
      <div class="keypad-item" @click="$emit('number-click', '2')">2</div>
      <div class="keypad-item" @click="$emit('number-click', '3')">3</div>
      <div class="keypad-item delete" @click="$emit('delete')">
        ❌
      </div>
    </div>
    <div class="keypad-row">
      <div class="keypad-item" @click="$emit('number-click', '4')">4</div>
      <div class="keypad-item" @click="$emit('number-click', '5')">5</div>
      <div class="keypad-item" @click="$emit('number-click', '6')">6</div>
      <div class="keypad-item" @click="$emit('number-click', '+')">+</div>
    </div>
    <div class="keypad-row">
      <div class="keypad-item" @click="$emit('number-click', '7')">7</div>
      <div class="keypad-item" @click="$emit('number-click', '8')">8</div>
      <div class="keypad-item" @click="$emit('number-click', '9')">9</div>
      <div class="keypad-item" @click="$emit('number-click', '-')">-</div>
    </div>
    <div class="keypad-row">
      <div class="keypad-item" @click="$emit('number-click', 'AC')">AC</div>
      <div class="keypad-item" @click="$emit('number-click', '0')">0</div>
      <div class="keypad-item" @click="$emit('number-click', '.')">.</div>
      <div class="keypad-item save" @click="$emit('save')">保存</div>
    </div>
  </div>
</template>

<script setup lang="ts">
 defineEmits<{
  (e: 'number-click', value: string): void
  (e: 'delete'): void
  (e: 'save'): void
}>()
</script>

<style scoped>
.keypad-section {
  padding: 8px 14px 0px;
  box-sizing: border-box;
}

.keypad-row {
  display: flex;
  gap: 12px;
  margin-bottom: 12px;
}

.keypad-item {
  flex: 1;
  height: 50px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 20px;
  font-weight: 500;
  color: #333333;
  background-color: #f9f9f9;
  border-radius: 8px;
  cursor: pointer;
  transition: background-color 0.2s ease;
}

.keypad-item:hover {
  background-color: #f0f0f0;
}

.keypad-item.delete {
  color: #666666;
  font-size: 12px;
}

.keypad-item.save {
  background-color: #409eff;
  color: white;
  border: none;
}

/* 响应式设计 */
@media (max-width: 375px) {
  .keypad-item {
    height: 44px;
    font-size: 18px;
  }
  
  .keypad-row {
    gap: 10px;
    margin-bottom: 10px;
  }
}

@media (max-width: 320px) {
  .keypad-item {
    height: 40px;
    font-size: 16px;
  }
  
  .keypad-row {
    gap: 8px;
    margin-bottom: 8px;
  }
}
</style>