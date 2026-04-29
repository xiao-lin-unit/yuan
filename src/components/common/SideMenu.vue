<template>
  <div class="side-menu" v-if="visible">
    <div class="menu-overlay" @click="closeMenu"></div>
    <div class="menu-content">
      <div class="user-profile">
        <img src="@/assets/img/user_icon.png" alt="用户头像" />
        <div class="user-info">
          <h3>{{ userName }}</h3>
        </div>
      </div>
      <div class="menu-items">
        <div class="menu-item" @click="navigateTo('account')">
          <el-icon class="menu-icon"><User /></el-icon>
          <span>账户</span>
        </div>
        <div class="menu-item" @click="toggleThemePanel">
          <el-icon class="menu-icon"><Sunny /></el-icon>
          <span>主题</span>
          <el-icon class="expand-icon" :class="{ expanded: showThemePanel }"><ArrowRight /></el-icon>
        </div>
        <div class="theme-panel" v-if="showThemePanel">
          <div
            v-for="theme in allThemes"
            :key="theme.name"
            class="theme-option"
            :class="{ active: themeStore.currentThemeName === theme.name }"
            @click="switchTheme(theme.name)"
          >
            <span class="theme-color-dot" :style="{ backgroundColor: theme.primary }"></span>
            <span class="theme-label">{{ theme.label }}</span>
            <el-icon v-if="themeStore.currentThemeName === theme.name" class="check-icon"><Check /></el-icon>
          </div>
        </div>
        <div class="menu-item">
          <el-icon class="menu-icon"><Setting /></el-icon>
          <span>设置</span>
        </div>
        <div class="menu-item">
          <el-icon class="menu-icon"><InfoFilled /></el-icon>
          <span>关于</span>
        </div>
        <div class="menu-item">
          <el-icon class="menu-icon"><Star /></el-icon>
          <span>收藏</span>
        </div>
        <div class="menu-item">
          <el-icon class="menu-icon"><HelpFilled /></el-icon>
          <span>帮助</span>
        </div>
        <div class="menu-item">
          <el-icon class="menu-icon"><ChatLineRound /></el-icon>
          <span>反馈</span>
        </div>
        <div class="menu-item">
          <el-icon class="menu-icon"><Moon /></el-icon>
          <span>夜间模式</span>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { User, Sunny, Setting, InfoFilled, Star, HelpFilled, ChatLineRound, Moon, ArrowRight, Check } from '@element-plus/icons-vue';
import { useThemeStore } from '../../stores/theme'

const props = defineProps<{
  visible: boolean;
}>();

const emit = defineEmits<{
  (e: 'close'): void;
  (e: 'navigate', key: string): void;
}>();

// Theme store
const themeStore = useThemeStore()
const allThemes = themeStore.getAllPresets()
const showThemePanel = ref(false)

// 用户名称和修改状态
const userName = ref<string>('user');
const hasModifiedName = ref<boolean>(false);

// 从localStorage加载用户信息
onMounted(() => {
  const savedName = localStorage.getItem('userName');
  const savedModified = localStorage.getItem('hasModifiedName');
  
  if (savedName) {
    userName.value = savedName;
  }
  
  if (savedModified) {
    hasModifiedName.value = savedModified === 'true';
  }
});

// Toggle theme panel
const toggleThemePanel = () => {
  showThemePanel.value = !showThemePanel.value
}

// Switch theme
const switchTheme = (name: string) => {
  themeStore.setTheme(name)
}

// 关闭菜单
const closeMenu = () => {
  emit('close');
};

// 导航到指定页面
const navigateTo = (key: string) => {
  emit('navigate', key);
  closeMenu();
};
</script>

<style scoped>
.side-menu {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  z-index: 200;
}

.menu-overlay {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background-color: rgba(0, 0, 0, 0.5);
}

.menu-content {
  position: absolute;
  top: 0;
  left: 0;
  width: 280px;
  height: 100%;
  background-color: white;
  box-shadow: 2px 0 8px rgba(0, 0, 0, 0.1);
  display: flex;
  flex-direction: column;
  animation: slideIn 0.3s ease;
}

@keyframes slideIn {
  from {
    transform: translateX(-100%);
  }
  to {
    transform: translateX(0);
  }
}

.user-profile {
  padding: 20px;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 10px;
  border-bottom: 1px solid #f0f0f0;
}

.user-profile img {
  width: 60px;
  height: 60px;
  border-radius: 50%;
  border: 2px solid var(--app-primary-color, #409EFF);
}

.user-info h3 {
  margin: 0;
  font-size: 18px;
  font-weight: bold;
  color: #333;
}

.menu-items {
  flex: 1;
  padding: 10px 0;
}

.menu-item {
  display: flex;
  align-items: center;
  padding: 15px 20px;
  cursor: pointer;
  transition: all 0.3s;
}

.menu-item:hover {
  background-color: #f5f7fa;
  color: var(--app-primary-color, #409EFF);
}

.menu-item :deep(.menu-icon) {
  font-size: 20px;
  color: var(--app-primary-color, #409EFF);
  margin-right: 15px;
  width: 20px;
  text-align: center;
}

.menu-item span {
  font-size: 16px;
  color: #333;
}

.menu-item:hover span {
  color: var(--app-primary-color, #409EFF);
}

.expand-icon {
  margin-left: auto;
  font-size: 14px;
  color: #999;
  transition: transform 0.3s ease;
}

.expand-icon.expanded {
  transform: rotate(90deg);
}

/* Theme panel */
.theme-panel {
  padding: 8px 20px 8px 55px;
  animation: fadeInPanel 0.2s ease;
}

@keyframes fadeInPanel {
  from {
    opacity: 0;
    max-height: 0;
  }
  to {
    opacity: 1;
    max-height: 300px;
  }
}

.theme-option {
  display: flex;
  align-items: center;
  padding: 5px 12px;
  border-radius: 8px;
  cursor: pointer;
  transition: all 0.2s ease;
  margin-bottom: 4px;
}

.theme-option:hover {
  background-color: #f5f7fa;
}

.theme-option.active {
  background-color: var(--app-primary-color, #409EFF);
}

.theme-option.active .theme-label {
  color: white;
}

.theme-color-dot {
  width: 14px;
  height: 14px;
  border-radius: 50%;
  margin-right: 10px;
  flex-shrink: 0;
  border: 2px solid rgba(0, 0, 0, 0.1);
}

.theme-label {
  font-size: 14px;
  color: #333;
}

.theme-option.active .theme-color-dot {
  border-color: rgba(255, 255, 255, 0.5);
}

.check-icon {
  margin-left: auto;
  font-size: 16px;
  color: white;
}

/* 响应式调整 */
@media (max-width: 375px) {
  .menu-content {
    width: 250px;
  }
  
  .user-profile {
    padding: 15px;
  }
  
  .user-profile img {
    width: 50px;
    height: 50px;
  }
  
  .user-info h3 {
    font-size: 16px;
  }
  
  .menu-item {
    padding: 12px 15px;
  }
  
  .menu-item :deep(.menu-icon) {
    font-size: 18px;
    margin-right: 12px;
  }
  
  .menu-item span {
    font-size: 14px;
  }
}

@media (max-width: 320px) {
  .menu-content {
    width: 220px;
  }
  
  .user-profile {
    padding: 12px;
  }
  
  .user-profile img {
    width: 45px;
    height: 45px;
  }
  
  .user-info h3 {
    font-size: 14px;
  }
  
  .menu-item {
    padding: 10px 12px;
  }
  
  .menu-item :deep(.menu-icon) {
    font-size: 16px;
    margin-right: 10px;
  }
  
  .menu-item span {
    font-size: 13px;
  }
}
</style>