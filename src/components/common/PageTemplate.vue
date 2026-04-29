<template>
  <div class="page-template">
    <!-- 顶部导航栏 -->
    <PageHeader :title="title" @back="$emit('back')" />
    
    <!-- 中间内容区域（插槽） -->
    <div class="content-area" ref="scrollWrap" @scroll="onScroll">
      <slot></slot>
    </div>

    <!-- 底部确认按钮（可选） -->
    <div v-if="showConfirmButton" class="confirm-section">
      <button
        class="confirm-btn"
        :disabled="confirmDisabled"
        @click="$emit('confirm')"
      >
        {{ confirmText }}
      </button>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import PageHeader from './PageHeader.vue'
const scrollWrap = ref<HTMLDivElement>()

defineProps<{
  title: string
  showConfirmButton?: boolean
  confirmText?: string
  confirmDisabled?: boolean
}>()

const emit = defineEmits<{
  (e: 'back'): void
  (e: 'confirm'): void
  (e: 'scroll', scrollTop: number): void
}>()

const onScroll = () => {
  emit('scroll', scrollWrap.value?.scrollTop || 0)
}

const scrollToTop = (top: number = 0, behavior: ScrollBehavior = 'smooth') => {
  scrollWrap.value?.scrollTo({ top, behavior })
}

defineExpose({
  scrollToTop
})

</script>

<style scoped>
.page-template {
  padding: 0;
  height: 100%;
  background-color: #f5f5f5;
  display: flex;
  flex-direction: column;
  box-sizing: border-box;
}

.content-area {
  background-color: white;
  padding: 0;
  flex: 1;
  overflow-y: auto;
  overflow-x: hidden;
  box-sizing: border-box;
}

.confirm-section {
  padding: 16px;
  background-color: white;
  border-top: 1px solid #e0e0e0;
  flex-shrink: 0;
}

.confirm-btn {
  width: 100%;
  padding: 14px;
  border: none;
  border-radius: 8px;
  background-color: #409eff;
  color: white;
  font-size: 16px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s ease;
}

.confirm-btn:hover:not(:disabled) {
  background-color: #66b1ff;
}

.confirm-btn:active:not(:disabled) {
  background-color: #1d8ce0;
  transform: scale(0.98);
}

.confirm-btn:disabled {
  background-color: #c0c4cc;
  cursor: not-allowed;
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
