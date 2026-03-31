<template>
  <div class="database-viewer">
    <div class="page-header">
      <el-icon @click="goBack"><ArrowLeft /></el-icon>
      <h1>数据库查看</h1>
      <div class="placeholder"></div>
    </div>

    <div class="content">
      <!-- 数据库状态 -->
      <div class="status-section">
        <div class="status-item">
          <span class="status-label">数据库模式:</span>
          <span class="status-value" :class="{ 'memory-mode': isMemoryMode }">
            {{ isMemoryMode ? '内存模式' : 'SQLite模式' }}
          </span>
        </div>
        <div class="status-item">
          <span class="status-label">数据持久化:</span>
          <span class="status-value" :class="{ 'saved': isDataSaved }">
            {{ isDataSaved ? '已保存到本地' : '未保存' }}
          </span>
        </div>
      </div>

      <!-- 表选择 -->
      <div class="table-selector">
        <el-select v-model="selectedTable" placeholder="选择数据表" @change="loadTableData">
          <el-option label="账户表 (accounts)" value="accounts" />
          <el-option label="流水表 (transactions)" value="transactions" />
          <el-option label="分类表 (categories)" value="categories" />
          <el-option label="资产表 (assets)" value="assets" />
          <el-option label="股票表 (stocks)" value="stocks" />
          <el-option label="基金表 (funds)" value="funds" />
          <el-option label="负债表 (liabilities)" value="liabilities" />
        </el-select>
        <el-button type="primary" @click="refreshData" :loading="loading">
          <el-icon><Refresh /></el-icon>
          刷新
        </el-button>
      </div>

      <!-- 数据表格 -->
      <div class="data-section" v-if="tableData.length > 0">
        <div class="data-header">
          <span class="data-count">共 {{ tableData.length }} 条记录</span>
        </div>
        <div class="data-table-wrapper">
          <table class="data-table">
            <thead>
              <tr>
                <th v-for="key in tableColumns" :key="key">{{ key }}</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(row, index) in tableData" :key="index">
                <td v-for="key in tableColumns" :key="key">
                  {{ formatValue(row[key]) }}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <!-- 空状态 -->
      <div class="empty-state" v-else-if="!loading">
        <el-icon class="empty-icon"><Document /></el-icon>
        <p>暂无数据</p>
        <p class="empty-hint">请选择数据表或添加数据</p>
      </div>

      <!-- 加载状态 -->
      <div class="loading-state" v-if="loading">
        <el-icon class="loading-icon"><Loading /></el-icon>
        <p>加载中...</p>
      </div>

      <!-- 本地存储查看 -->
      <div class="storage-section">
        <h3>本地存储信息</h3>
        <div class="storage-info">
          <div class="storage-item">
            <span class="storage-label">SQLite数据库:</span>
            <span class="storage-value">{{ sqliteStorageSize }}</span>
          </div>
          <div class="storage-item">
            <span class="storage-label">内存数据:</span>
            <span class="storage-value">{{ memoryStorageSize }}</span>
          </div>
        </div>
        <el-button type="danger" size="small" @click="clearAllData">
          清空所有数据
        </el-button>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { ArrowLeft, Refresh, Document, Loading } from '@element-plus/icons-vue'
import db from '../../database'

const emit = defineEmits(['navigate'])

// 状态
const loading = ref(false)
const selectedTable = ref('accounts')
const tableData = ref<any[]>([])
const tableColumns = ref<string[]>([])
const isMemoryMode = ref(false)
const isDataSaved = ref(false)

// 本地存储大小
const sqliteStorageSize = ref('0 KB')
const memoryStorageSize = ref('0 KB')

// 返回
const goBack = () => {
  emit('navigate', 'account')
}

// 格式化值
const formatValue = (value: any): string => {
  if (value === null || value === undefined) return '-'
  if (typeof value === 'boolean') return value ? '是' : '否'
  if (typeof value === 'number') {
    // 如果是金额，保留2位小数
    if (Math.abs(value) > 1000) {
      return value.toLocaleString('zh-CN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
    }
    return value.toString()
  }
  if (typeof value === 'string' && value.length > 50) {
    return value.substring(0, 50) + '...'
  }
  return String(value)
}

// 加载表数据
const loadTableData = async () => {
  if (!selectedTable.value) return
  
  loading.value = true
  try {
    // 查询数据
    const data = await db.query(`SELECT * FROM ${selectedTable.value}`)
    tableData.value = data
    
    // 获取列名
    if (data.length > 0) {
      tableColumns.value = Object.keys(data[0])
    } else {
      tableColumns.value = []
    }
    
    console.log(`Loaded ${data.length} records from ${selectedTable.value}`)
  } catch (error) {
    console.error('Error loading table data:', error)
    tableData.value = []
    tableColumns.value = []
  } finally {
    loading.value = false
  }
}

// 刷新数据
const refreshData = async () => {
  await loadTableData()
  await checkStorageStatus()
}

// 检查存储状态
const checkStorageStatus = async () => {
  try {
    // 获取数据库状态
    const status = db.getStatus()
    isMemoryMode.value = !status.isNative
    
    // 检查本地存储（仅Web环境）
    if (typeof window !== 'undefined' && window.localStorage) {
      const sqliteData = localStorage.getItem('sqlite_finance-app-db')
      
      if (sqliteData) {
        const size = new Blob([sqliteData]).size
        sqliteStorageSize.value = formatSize(size)
        isDataSaved.value = true
      } else {
        sqliteStorageSize.value = '0 KB'
        isDataSaved.value = status.isNative // 原生环境自动持久化
      }
      
      memoryStorageSize.value = '0 KB'
    }
  } catch (error) {
    console.error('Error checking storage status:', error)
  }
}

// 格式化大小
const formatSize = (bytes: number): string => {
  if (bytes === 0) return '0 KB'
  if (bytes < 1024) return bytes + ' B'
  if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(2) + ' KB'
  return (bytes / (1024 * 1024)).toFixed(2) + ' MB'
}

// 清空所有数据
const clearAllData = async () => {
  if (confirm('确定要清空所有数据吗？此操作不可恢复！')) {
    try {
      // 使用数据库连接池的清空方法
      await db.clearAllData()
      
      // 清空本地存储（Web环境）
      if (typeof window !== 'undefined' && window.localStorage) {
        localStorage.removeItem('sqlite_finance-app-db')
      }
      
      tableData.value = []
      tableColumns.value = []
      await checkStorageStatus()
      
      alert('所有数据已清空')
    } catch (error) {
      console.error('Error clearing data:', error)
      alert('清空数据失败')
    }
  }
}

// 初始化
onMounted(async () => {
  await checkStorageStatus()
  await loadTableData()
})
</script>

<style scoped>
.database-viewer {
  height: 100%;
  display: flex;
  flex-direction: column;
  background-color: #f5f7fa;
}

.page-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 16px;
  background-color: white;
  border-bottom: 1px solid #e0e0e0;
  flex-shrink: 0;
}

.page-header h1 {
  font-size: 16px;
  font-weight: bold;
  color: #333333;
  margin: 0;
}

.page-header .placeholder {
  width: 24px;
}

.content {
  flex: 1;
  overflow-y: auto;
  padding: 16px;
}

/* 状态区域 */
.status-section {
  background-color: white;
  border-radius: 8px;
  padding: 16px;
  margin-bottom: 16px;
}

.status-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 8px 0;
  border-bottom: 1px solid #f0f0f0;
}

.status-item:last-child {
  border-bottom: none;
}

.status-label {
  font-size: 14px;
  color: #666666;
}

.status-value {
  font-size: 14px;
  font-weight: 500;
  color: #333333;
}

.status-value.memory-mode {
  color: #ff9800;
}

.status-value.saved {
  color: #4caf50;
}

/* 表选择器 */
.table-selector {
  display: flex;
  gap: 12px;
  margin-bottom: 16px;
}

.table-selector .el-select {
  flex: 1;
}

/* 数据区域 */
.data-section {
  background-color: white;
  border-radius: 8px;
  padding: 16px;
  margin-bottom: 16px;
}

.data-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 12px;
}

.data-count {
  font-size: 14px;
  color: #666666;
}

.data-table-wrapper {
  overflow-x: auto;
  max-height: 400px;
  overflow-y: auto;
}

.data-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 12px;
}

.data-table th,
.data-table td {
  padding: 8px 12px;
  text-align: left;
  border-bottom: 1px solid #f0f0f0;
  white-space: nowrap;
}

.data-table th {
  background-color: #f5f7fa;
  font-weight: 600;
  color: #333333;
  position: sticky;
  top: 0;
}

.data-table td {
  color: #666666;
}

.data-table tr:hover {
  background-color: #f5f7fa;
}

/* 空状态 */
.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 60px 20px;
  background-color: white;
  border-radius: 8px;
  margin-bottom: 16px;
}

.empty-icon {
  font-size: 48px;
  color: #cccccc;
  margin-bottom: 16px;
}

.empty-state p {
  font-size: 16px;
  color: #999999;
  margin: 0;
}

.empty-hint {
  font-size: 14px !important;
  color: #cccccc !important;
  margin-top: 8px !important;
}

/* 加载状态 */
.loading-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 60px 20px;
  background-color: white;
  border-radius: 8px;
  margin-bottom: 16px;
}

.loading-icon {
  font-size: 32px;
  color: #409eff;
  margin-bottom: 16px;
  animation: rotate 1s linear infinite;
}

@keyframes rotate {
  from {
    transform: rotate(0deg);
  }
  to {
    transform: rotate(360deg);
  }
}

/* 存储区域 */
.storage-section {
  background-color: white;
  border-radius: 8px;
  padding: 16px;
}

.storage-section h3 {
  font-size: 16px;
  font-weight: 600;
  color: #333333;
  margin: 0 0 16px 0;
}

.storage-info {
  margin-bottom: 16px;
}

.storage-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 8px 0;
  border-bottom: 1px solid #f0f0f0;
}

.storage-item:last-child {
  border-bottom: none;
}

.storage-label {
  font-size: 14px;
  color: #666666;
}

.storage-value {
  font-size: 14px;
  font-weight: 500;
  color: #333333;
}
</style>
