<template>
  <div class="more-features">
    <!-- 轮播图 -->
    <div class="carousel">
      <div class="carousel-container">
        <div class="carousel-item" v-for="(item, index) in carouselItems" :key="index" :class="{ active: currentSlide === index }">
          <img :src="item.image" :alt="item.title" />
          <div class="carousel-content">
            <h3>{{ item.title }}</h3>
            <p>{{ item.description }}</p>
          </div>
        </div>
      </div>
      <div class="carousel-indicators">
        <span 
          v-for="(item, index) in carouselItems" 
          :key="index"
          :class="{ active: currentSlide === index }"
          @click="currentSlide = index"
        ></span>
      </div>
    </div>
    
    <!-- 功能菜单 -->
    <div class="feature-menu">
      <div class="feature-item" @click="navigateTo('dashboard')">
        <div class="feature-icon" style="background-color: #409EFF;">
          <el-icon :size="24"><DataAnalysis /></el-icon>
        </div>
        <span>健康</span>
      </div>
      <div class="feature-item" @click="navigateTo('knowledge')">
        <div class="feature-icon" style="background-color: #67C23A;">
          <el-icon :size="24"><Document /></el-icon>
        </div>
        <span>知识</span>
      </div>
      <!-- <div class="feature-item" @click="navigateTo('goal')">
        <div class="feature-icon" style="background-color: #E6A23C;">
          <el-icon :size="24"><Flag /></el-icon>
        </div>
        <span>目标</span>
      </div> -->
      <div class="feature-item" @click="navigateTo('sandbox')">
        <div class="feature-icon" style="background-color: #909399;">
          <el-icon :size="24"><PieChart /></el-icon>
        </div>
        <span>沙盒</span>
      </div>
    </div>

    <!-- 版本信息 -->
    <div class="version-info">
      <span>裕安 {{ versionText }}</span>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, onUnmounted } from 'vue';
import { DataAnalysis, Document, Flag, PieChart } from '@element-plus/icons-vue';
import { getVersionText } from '../../../utils/version';
import m4 from '@/assets/img/m4.jpg';
import m5 from '@/assets/img/m5.jpg';
import m3 from '@/assets/img/m3.jpg';

const emit = defineEmits<{
  (e: 'navigate', key: string): void
}>();

const carouselItems = [
  {
    image: m4,
    title: '健康评估',
    description: '个人财务健康状况评估'
  },
  {
    image: m5,
    title: '知识分享',
    description: '财务知识分享与学习'
  },
  {
    image: m3,
    title: '沙盒模拟',
    description: '模拟未来财务状况'
  }
];

const currentSlide = ref(0);
const versionText = getVersionText();
let slideInterval: number | null = null;

const startAutoSlide = () => {
  slideInterval = window.setInterval(() => {
    currentSlide.value = (currentSlide.value + 1) % carouselItems.length;
  }, 3000);
};

const stopAutoSlide = () => {
  if (slideInterval) {
    clearInterval(slideInterval);
    slideInterval = null;
  }
};

onMounted(() => {
  startAutoSlide();
});

onUnmounted(() => {
  stopAutoSlide();
});

// 导航到指定页面
const navigateTo = (key: string) => {
  emit('navigate', key);
};
</script>

<style scoped>
.more-features {
  padding: 16px;
  height: 100%;
  overflow-y: auto;
}

.carousel {
  position: relative;
  margin-bottom: 24px;
  border-radius: 8px;
  overflow: hidden;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
}

.carousel-container {
  position: relative;
  height: 180px;
}

.carousel-item {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  opacity: 0;
  transition: opacity 0.5s ease;
}

.carousel-item.active {
  opacity: 1;
}

.carousel-item img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.carousel-content {
  position: absolute;
  bottom: 0;
  left: 0;
  right: 0;
  padding: 16px;
  background: linear-gradient(to top, rgba(0, 0, 0, 0.7), transparent);
  color: white;
}

.carousel-content h3 {
  margin: 0 0 4px 0;
  font-size: 18px;
  font-weight: bold;
}

.carousel-content p {
  margin: 0;
  font-size: 14px;
  opacity: 0.9;
}

.carousel-indicators {
  position: absolute;
  bottom: 10px;
  right: 16px;
  display: flex;
  gap: 6px;
}

.carousel-indicators span {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background-color: rgba(255, 255, 255, 0.5);
  cursor: pointer;
  transition: all 0.3s ease;
}

.carousel-indicators span.active {
  background-color: white;
  width: 16px;
  border-radius: 4px;
}

.feature-menu {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 16px;
}

.feature-item {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8px;
  padding: 16px;
  background-color: white;
  border-radius: 8px;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.05);
  cursor: pointer;
  transition: all 0.3s ease;
}

.feature-item:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 8px rgba(0, 0, 0, 0.1);
}

.feature-icon {
  width: 48px;
  height: 48px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  color: white;
  margin-bottom: 4px;
}

.feature-item span {
  font-size: 14px;
  color: #303133;
  text-align: center;
}

.version-info {
  text-align: center;
  padding: 32px 0 16px;
  color: #C0C4CC;
  font-size: 13px;
}

@media (max-width: 375px) {
  .carousel-container {
    height: 160px;
  }
  
  .feature-menu {
    gap: 12px;
  }
  
  .feature-item {
    padding: 12px;
  }
  
  .feature-icon {
    width: 40px;
    height: 40px;
  }
  
  .feature-icon :deep(el-icon) {
    font-size: 20px;
  }
  
  .feature-item span {
    font-size: 12px;
  }
}

@media (max-width: 320px) {
  .carousel-container {
    height: 140px;
  }
  
  .carousel-content h3 {
    font-size: 16px;
  }
  
  .carousel-content p {
    font-size: 12px;
  }
  
  .feature-menu {
    gap: 10px;
  }
  
  .feature-item {
    padding: 10px;
  }
  
  .feature-icon {
    width: 36px;
    height: 36px;
  }
  
  .feature-icon :deep(el-icon) {
    font-size: 18px;
  }
  
  .feature-item span {
    font-size: 11px;
  }
}
</style>