<template>
  <div v-if="buttons.length > 0" class="floating-action-menu">
    <!-- 当只有一个按钮时，直接显示该按钮 -->
    <div v-if="buttons.length === 1" class="floating-action-button floating-menu-item" @click="buttons[0].action">
      <el-icon :size="24" style="color: white;">
        <component :is="buttons[0].icon" />
      </el-icon>
      <span v-if="buttons[0].text">{{ buttons[0].text }}</span>
    </div>
    
    <!-- 当按钮数量大于1时，显示more按钮和展开菜单 -->
    <template v-else>
      <div class="floating-action-button" @click="toggleMenu">
        <el-icon :size="24" style="color: white;"><More /></el-icon>
      </div>
      <div class="floating-menu" v-if="isMenuExpanded">
        <div 
          v-for="(button, index) in buttons" 
          :key="index" 
          class="floating-menu-item"
          @click="button.action"
        >
          <el-icon :size="20" style="color: white;">
            <component :is="button.icon" />
          </el-icon>
          <span v-if="button.text">{{ button.text }}</span>
        </div>
      </div>
    </template>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { More } from '@element-plus/icons-vue'

// 定义按钮类型
interface ActionButton {
  text: string
  icon: any
  action: () => void
}

// 定义组件props
const props = defineProps({
  buttons: {
    type: Array as () => ActionButton[],
    required: true
  }
})

// 菜单展开状态
const isMenuExpanded = ref(false)

// 切换菜单展开/收起
const toggleMenu = () => {
  isMenuExpanded.value = !isMenuExpanded.value
}
</script>

<style scoped>
.floating-action-menu {
  position: fixed;
  bottom: 80px;
  right: 20px;
  z-index: 1000;
}

.floating-action-button {
  width: 48px;
  height: 48px;
  border-radius: 50%;
  background-color: var(--app-primary-color, #409eff);
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: 0 4px 12px rgba(var(--app-primary-rgb, 64, 158, 255), 0.5);
  cursor: pointer;
  opacity: 0.7;
  transition: all 0.3s ease;
}

.floating-action-button:hover {
  transform: scale(1.1);
  box-shadow: 0 6px 16px rgba(var(--app-primary-rgb, 64, 158, 255), 0.5);
  opacity: 1;
}

.floating-menu {
  position: absolute;
  bottom: 66px;
  right: 0;
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  gap: 10px;
  animation: fadeIn 0.3s ease;
}

.floating-menu-item {
  width: 48px;
  height: 48px;
  border-radius: 50%;
  background-color: var(--app-primary-color, #409eff);
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: 0 4px 12px rgba(var(--app-primary-rgb, 64, 158, 255), 0.5);
  cursor: pointer;
  opacity: 0.8;
  transition: all 0.3s ease;
  position: relative;
}

.floating-menu-item:hover {
  transform: scale(1.1);
  box-shadow: 0 6px 16px rgba(var(--app-primary-rgb, 64, 158, 255), 0.5);
  opacity: 1;
}

.floating-menu-item span {
  position: absolute;
  right: 56px;
  background-color: rgba(0, 0, 0, 0.7);
  color: white;
  padding: 4px 8px;
  border-radius: 4px;
  font-size: 12px;
  white-space: nowrap;
  opacity: 0;
  transform: translateX(10px);
  transition: all 0.2s ease;
  pointer-events: none;
}

.floating-menu-item:hover span {
  opacity: 1;
  transform: translateX(0);
}

@keyframes fadeIn {
  from {
    opacity: 0;
    transform: translateY(10px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}
</style>