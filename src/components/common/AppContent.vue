<template>
  <div class="content-area">
    <component :is="currentComponent" @navigate="$emit('navigate', $event)" />
  </div>
</template>

<script setup lang="ts">
defineProps<{
  currentComponent: any
}>();

defineEmits<{
  (e: 'navigate', key: string): void
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