<template>
  <div class="sandbox-history">
    <PageHeader title="历史推演" @back="goBack" />

    <div v-if="loading" class="loading-tip">加载中...</div>

    <div v-else-if="historyList.length === 0" class="empty-tip">
      <el-empty description="暂无推演记录" />
    </div>

    <div v-else class="history-list">
      <div
        v-for="item in historyList"
        :key="item.id"
        class="history-card"
        @click="viewDetail(item.id)"
      >
        <div class="history-header">
          <div class="history-name">{{ item.scene_name }}</div>
          <div class="history-time">{{ item.simulate_time }}</div>
        </div>
        <div class="history-desc" v-if="item.result_desc">{{ item.result_desc }}</div>
        <div class="history-actions">
          <el-button type="primary" link size="small" @click.stop="viewDetail(item.id)">查看详情</el-button>
          <el-button type="danger" link size="small" @click.stop="confirmDelete(item.id)">删除</el-button>
        </div>
      </div>
    </div>

    <FloatingActionMenu :buttons="fabButtons" />
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { Clock, Plus } from '@element-plus/icons-vue'
import PageHeader from '../../common/PageHeader.vue'
import FloatingActionMenu from '../../common/FloatingActionMenu.vue'
import { getSandboxHistoryList, softDeleteSandboxHistory } from '../../../services/sandbox/sandboxService'
import type { SandboxHistory as SandboxHistoryType } from '../../../services/sandbox/sandboxService'

const emit = defineEmits(['navigate'])

const historyList = ref<SandboxHistoryType[]>([])
const loading = ref(false)

const fabButtons = [
  { text: '新建推演', icon: 'Plus', action: () => emit('navigate', 'sandbox') }
]

const loadHistory = async () => {
  loading.value = true
  try {
    historyList.value = await getSandboxHistoryList()
  } finally {
    loading.value = false
  }
}

onMounted(loadHistory)

const goBack = () => {
  emit('navigate', 'sandbox')
}

const viewDetail = (id: number) => {
  emit('navigate', { key: 'sandboxResultDetail', params: { historyId: id } })
}

const confirmDelete = async (id: number) => {
  try {
    await softDeleteSandboxHistory(id)
    await loadHistory()
  } catch (err) {
    console.error('Delete failed:', err)
  }
}
</script>

<style scoped>
.sandbox-history {
  padding: 12px;
  padding-bottom: 80px;
  min-height: 100%;
}

.loading-tip,
.empty-tip {
  padding: 40px 0;
  text-align: center;
  color: #909399;
}

.history-list {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.history-card {
  background: #fff;
  border-radius: 12px;
  padding: 14px 16px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.06);
  cursor: pointer;
  transition: all 0.2s ease;
  border: 1px solid #f0f0f0;
}

.history-card:active {
  transform: scale(0.99);
}

.history-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 8px;
}

.history-name {
  font-size: 15px;
  font-weight: 600;
  color: #303133;
}

.history-time {
  font-size: 12px;
  color: #909399;
}

.history-desc {
  font-size: 13px;
  color: #606266;
  margin-bottom: 10px;
  line-height: 1.4;
}

.history-actions {
  display: flex;
  justify-content: flex-end;
  gap: 8px;
}
</style>
