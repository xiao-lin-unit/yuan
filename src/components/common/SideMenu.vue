<template>
  <div class="side-menu" v-if="visible">
    <div class="menu-overlay" @click="closeMenu"></div>
    <div class="menu-content">
      <div class="user-profile">
        <img src="https://trae-api-cn.mchost.guru/api/ide/v1/text_to_image?prompt=user%20avatar%20icon%20minimalist%20design&image_size=square" alt="用户头像" />
        <div class="user-info">
          <h3>{{ userName }}</h3>
        </div>
      </div>
      <div class="menu-items">
        <div class="menu-item" @click="navigateTo('account')">
          <el-icon class="menu-icon"><User /></el-icon>
          <span>账户</span>
        </div>
        <div class="menu-item">
          <el-icon class="menu-icon"><Sunny /></el-icon>
          <span>主题</span>
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
import { User, Sunny, Setting, InfoFilled, Star, HelpFilled, ChatLineRound, Moon } from '@element-plus/icons-vue';

const props = defineProps<{
  visible: boolean;
}>();

const emit = defineEmits<{
  (e: 'close'): void;
  (e: 'navigate', key: string): void;
}>();

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
  border: 2px solid #409EFF;
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
  color: #409EFF;
}

.menu-item :deep(.menu-icon) {
  font-size: 20px;
  color: #409EFF;
  margin-right: 15px;
  width: 20px;
  text-align: center;
}

.menu-item span {
  font-size: 16px;
  color: #333;
}

.menu-item:hover span {
  color: #409EFF;
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