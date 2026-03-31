<template>
  <div class="content-area">
    <component 
      :is="currentComponent" 
      @navigate="$emit('navigate', $event)" 
      @dateChange="$emit('dateChange', $event)"
      v-bind="componentProps"
    />
  </div>
</template>

<script setup lang="ts">
defineProps<{
  currentComponent: any,
  componentProps?: Record<string, any>
}>();

defineEmits<{
  (e: 'navigate', key: string): void,
  (e: 'dateChange', date: { year: number; month: number }): void
}>();
</script>

<style scoped>
.content-area {
  flex: 1;
  overflow-y: auto;
  overflow-x: hidden;
  padding: 15px;
  width: 100%;
  box-sizing: border-box;
  position: relative;
}

/* 响应式调整 */
@media (max-width: 320px) {
  .content-area {
    padding: 10px;
  }
}

/* 隐藏滚动条但保留滚动功能 */
.content-area::-webkit-scrollbar {
  display: none;
}

.content-area {
  -ms-overflow-style: none;
  scrollbar-width: none;
}
</style>