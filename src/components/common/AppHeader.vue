<template>
  <div class="app-header">
    <div class="user-avatar" @click="toggleMenu">
      <img src="@/assets/img/user_icon.png" alt="用户头像" />
    </div>
    <div class="app-logo">
      <img src="@/assets/logo/app_logo.png" alt="裕安" />
      <h1>裕安</h1>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';

const emit = defineEmits<{
  (e: 'toggle-menu'): void;
}>();

// 用户名称和修改状态（保留存储功能，后续可能需要）
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

// 保存用户信息到localStorage
const saveUserInfo = (name: string, modified: boolean) => {
  localStorage.setItem('userName', name);
  localStorage.setItem('hasModifiedName', modified.toString());
};

// 切换菜单显示/隐藏
const toggleMenu = () => {
  emit('toggle-menu');
};
</script>

<style scoped>
.app-header {
  background-color: var(--app-primary-color, #409EFF);
  color: white;
  padding: 15px;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
  z-index: 100;
  flex-shrink: 0;
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.user-avatar {
  display: flex;
  align-items: center;
  cursor: pointer;
  transition: transform 0.3s;
}

.user-avatar:hover {
  transform: scale(1.05);
}

.user-avatar img {
  width: 30px;
  height: 30px;
  border-radius: 50%;
  border: 2px solid rgba(255, 255, 255, 0.8);
}

.app-logo {
  display: flex;
  align-items: center;
  gap: 10px;
}

.app-logo img {
  width: 30px;
  height: 30px;
  border-radius: 8px;
}

.app-logo h1 {
  margin: 0;
  font-size: 18px;
  font-weight: bold;
}

/* 响应式调整 */
@media (max-width: 375px) {
  .app-logo h1 {
    font-size: 16px;
  }
  
  .app-logo img {
    width: 28px;
    height: 28px;
  }
  
  .user-avatar img {
    width: 28px;
    height: 28px;
  }
}

@media (max-width: 320px) {
  .app-header {
    padding: 10px;
  }
  
  .app-logo h1 {
    font-size: 14px;
  }
  
  .app-logo img {
    width: 24px;
    height: 24px;
  }
  
  .user-avatar img {
    width: 24px;
    height: 24px;
  }
}
</style>