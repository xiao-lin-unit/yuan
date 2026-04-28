<template>
    <div class="floating-switch-button" @click="toggleSwitch">
        <el-icon style="color: white;"><Switch /></el-icon>
        <span class="toggle-text">{{ active ? props.activeText : props.inactiveText }}</span>
    </div>
</template>
<script setup lang="ts">

import { Switch } from '@element-plus/icons-vue';
import { ref } from 'vue';

const props = defineProps({
    active: Boolean,
    activeText: String,
    inactiveText: String,
});


const emit = defineEmits(['update:active']);

const active = ref(false);
const toggleSwitch = () => {
   active.value = !active.value;
   emit('update:active', active.value);
}

</script>
<script setup lang="ts">
</script>
<style scoped>
/* 切换资产按钮 */
.floating-switch-button {
  position: fixed;
  bottom: 80px;
  left: 20px;
  z-index: 1000;
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 12px 16px;
  background-color: #67c23a;
  border-radius: 24px;
  box-shadow: 0 4px 12px rgba(103, 194, 58, 0.5);
  cursor: pointer;
  transition: all 0.3s ease;
}

.floating-switch-button:hover {
  transform: scale(1.05);
  box-shadow: 0 6px 16px rgba(103, 194, 58, 0.5);
}

.toggle-text {
  color: white;
  font-size: 14px;
  font-weight: 500;
}
</style>
