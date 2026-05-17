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
          <el-option
            v-for="t in allTables"
            :key="t.name"
            :label="`${t.label} (${t.name})`"
            :value="t.name"
          />
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

// 表名 → 中文标签映射
const TABLE_LABELS: Record<string, string> = {
  accounts: '账户表',
  income_expense_records: '收支记录表',
  account_transactions: '账户流水表',
  assets: '资产表',
  stocks: '股票表',
  stock_holdings: '股票持有表',
  stock_transactions: '股票交易表',
  funds: '基金表',
  fund_holdings: '基金持有表',
  fund_transactions: '基金交易表',
  liabilities: '负债表',
  repayments: '还款记录表',
  pending_repayments: '待还款表',
  financial_goals: '财务目标表',
  financial_health: '财务健康表',
  db_version: '数据库版本表',
  categories: '分类表',
  asset_income_records: '普通资产收益记录表',
  asset_monthly_snapshots: '月度资产记录表',
  knowledge_favorite: '知识收藏表',
  knowledge_read_history: '阅读历史表',
  sandbox_result: '沙盘推演结果表',
  sandbox_history: '沙盘推演历史表',


}

// 状态
const loading = ref(false)
const selectedTable = ref('accounts')
const tableData = ref<any[]>([])
const tableColumns = ref<string[]>([])
const isMemoryMode = ref(false)
const isDataSaved = ref(false)
const allTables = ref<{ name: string; label: string }[]>([])

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

// 加载所有表名
const loadAllTables = async () => {
  try {
    const tables = await db.query(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name"
    )
    allTables.value = tables.map((t: any) => ({
      name: t.name,
      label: TABLE_LABELS[t.name] || t.name
    }))
    // 如果当前选中的表不在列表中，选第一个
    if (allTables.value.length > 0 && !allTables.value.find(t => t.name === selectedTable.value)) {
      selectedTable.value = allTables.value[0].name
    }
  } catch (error) {
    console.error('Error loading table list:', error)
  }
}

// 初始化
onMounted(async () => {
  await checkStorageStatus()
  await loadAllTables()
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
