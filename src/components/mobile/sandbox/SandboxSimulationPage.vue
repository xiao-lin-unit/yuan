<template>
  <div class="sandbox-simulation">
    <PageHeader :title="scene?.name || '沙盘推演'" @back="goBack" />

    <div class="scene-info" v-if="scene">
      <el-icon :size="32" color="#409eff"><component :is="sceneIcon" /></el-icon>
      <div class="scene-desc">{{ scene.desc }}</div>
    </div>

    <el-card class="param-card">
      <template #header>
        <span class="card-title">推演参数</span>
      </template>
      <el-form :model="paramValues" label-position="top">
        <el-form-item
          v-for="field in scene?.paramSchema"
          :key="field.key"
          :label="field.label"
        >
          <el-switch
            v-if="field.type === 'switch'"
            v-model="paramValues[field.key]"
          />
          <el-select
            v-else-if="field.type === 'select'"
            v-model="paramValues[field.key]"
            style="width: 100%"
          >
            <el-option
              v-for="opt in field.options"
              :key="opt.value"
              :label="opt.label"
              :value="opt.value"
            />
          </el-select>
          <el-input-number
            v-else-if="field.type === 'number'"
            v-model="paramValues[field.key]"
            :min="field.min"
            :max="field.max"
            :step="field.step || 1"
            style="width: 100%"
            controls-position="right"
          />
          <el-input
            v-else
            v-model="paramValues[field.key]"
          />
        </el-form-item>
      </el-form>
    </el-card>

    <div class="action-area">
      <el-button type="primary" size="large" style="width: 100%" :loading="computing" @click="runSimulation">
        开始推演
      </el-button>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import {
  Wallet, TrendCharts, Bottom, Money, Checked, Top,
  ShoppingCart, BottomLeft, Sell, DocumentAdd, FirstAidKit,
  Warning, Coin
} from '@element-plus/icons-vue'
import PageHeader from '../../common/PageHeader.vue'
import { getSceneByType, saveSandboxSimulation } from '../../../services/sandbox/sandboxService'

const props = defineProps<{ sceneType: number }>()
const emit = defineEmits(['navigate'])

const iconMap: Record<string, any> = {
  Wallet, TrendCharts, Bottom, Money, Checked, Top,
  ShoppingCart, BottomLeft, Sell, DocumentAdd, FirstAidKit,
  Warning, Coin
}

const scene = computed(() => getSceneByType(props.sceneType))
const sceneIcon = computed(() => iconMap[scene.value?.icon || 'Wallet'])

const paramValues = ref<Record<string, any>>({})
const computing = ref(false)

onMounted(() => {
  if (scene.value) {
    const defaults: Record<string, any> = {}
    for (const field of scene.value.paramSchema) {
      defaults[field.key] = field.defaultValue ?? ''
    }
    paramValues.value = defaults
  }
})

const goBack = () => {
  emit('navigate', 'sandbox')
}

const runSimulation = async () => {
  if (!scene.value) return
  computing.value = true
  try {
    const historyId = await saveSandboxSimulation(props.sceneType, paramValues.value)
    emit('navigate', { key: 'sandboxResultDetail', params: { historyId } })
  } catch (err) {
    console.error('Simulation failed:', err)
    alert('推演计算失败，请检查数据')
  } finally {
    computing.value = false
  }
}
</script>

<style scoped>
.sandbox-simulation {
  padding: 12px;
  padding-bottom: 80px;
  min-height: 100%;
}

.scene-info {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 20px;
  background: #fff;
  border-radius: 12px;
  margin-bottom: 12px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.06);
}

.scene-desc {
  margin-top: 10px;
  font-size: 13px;
  color: #606266;
  text-align: center;
  line-height: 1.5;
}

.param-card {
  margin-bottom: 16px;
}

.card-title {
  font-weight: 600;
  font-size: 15px;
}

.action-area {
  padding: 8px 0 24px;
}
</style>
