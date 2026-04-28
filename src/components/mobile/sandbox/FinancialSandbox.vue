<template>
  <div class="financial-sandbox">
    <PageHeader title="财务沙盘" :show-back="false" />

    <div class="scene-grid">
      <div
        v-for="scene in scenes"
        :key="scene.sceneType"
        class="scene-card"
        @click="selectScene(scene.sceneType)"
      >
        <div class="scene-icon">
          <el-icon :size="28" color="#409eff">
            <component :is="scene.icon" />
          </el-icon>
        </div>
        <div class="scene-name">{{ scene.name }}</div>
        <div class="scene-desc">{{ scene.desc }}</div>
      </div>
    </div>

    <FloatingActionMenu :buttons="fabButtons" />
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import {
  Wallet, TrendCharts, Bottom, Money, Checked, Top,
  ShoppingCart, BottomLeft, Sell, DocumentAdd, FirstAidKit,
  Warning, Coin
} from '@element-plus/icons-vue'
import PageHeader from '../../common/PageHeader.vue'
import FloatingActionMenu from '../../common/FloatingActionMenu.vue'
import { SCENES } from '../../../services/sandbox/sandboxService'

const emit = defineEmits(['navigate'])

const iconMap: Record<string, any> = {
  Wallet, TrendCharts, Bottom, Money, Checked, Top,
  ShoppingCart, BottomLeft, Sell, DocumentAdd, FirstAidKit,
  Warning, Coin
}

const scenes = computed(() =>
  SCENES.map(s => ({ ...s, icon: iconMap[s.icon] || Wallet }))
)

const selectScene = (sceneType: number) => {
  emit('navigate', { key: 'sandboxSimulation', params: { sceneType } })
}

const fabButtons = [
  {
    text: '历史推演',
    icon: 'Clock',
    action: () => emit('navigate', 'sandboxHistory')
  }
]
</script>

<style scoped>
.financial-sandbox {
  padding: 12px;
  padding-bottom: 80px;
  min-height: 100%;
}

.scene-grid {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 12px;
  margin-top: 12px;
}

.scene-card {
  background: #fff;
  border-radius: 12px;
  padding: 16px 12px;
  text-align: center;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.06);
  cursor: pointer;
  transition: all 0.2s ease;
  border: 1px solid #f0f0f0;
}

.scene-card:active {
  transform: scale(0.98);
  box-shadow: 0 1px 4px rgba(0, 0, 0, 0.08);
}

.scene-icon {
  width: 48px;
  height: 48px;
  border-radius: 50%;
  background: #ecf5ff;
  display: flex;
  align-items: center;
  justify-content: center;
  margin: 0 auto 10px;
}

.scene-name {
  font-size: 14px;
  font-weight: 600;
  color: #303133;
  margin-bottom: 6px;
  line-height: 1.3;
}

.scene-desc {
  font-size: 11px;
  color: #909399;
  line-height: 1.4;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
</style>
