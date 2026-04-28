<template>
  <div class="sandbox-result">
    <PageHeader :title="history?.scene_name || '推演详情'" @back="goBack" />

    <div v-if="loading" class="loading-tip">加载中...</div>

    <template v-else-if="history && result">
      <!-- 推演时间 -->
      <div class="info-bar">推演时间: {{ history.simulate_time }}</div>

      <!-- 核心指标卡片 -->
      <div class="metric-cards">
        <div class="metric-card">
          <div class="metric-label">净资产</div>
          <div class="metric-value" :class="netAssetsClass">¥{{ formatNumber(result.net_assets) }}</div>
        </div>
        <div class="metric-card">
          <div class="metric-label">月现金流</div>
          <div class="metric-value" :class="cashFlowClass">¥{{ formatNumber(result.cash_flow_monthly) }}</div>
        </div>
        <div class="metric-card" v-if="result.survival_months != null">
          <div class="metric-label">可维持月数</div>
          <div class="metric-value">{{ result.survival_months === 999 ? '长期' : result.survival_months + '个月' }}</div>
        </div>
        <div class="metric-card" v-if="result.interest_save != null">
          <div class="metric-label">节省利息</div>
          <div class="metric-value positive">¥{{ formatNumber(result.interest_save) }}</div>
        </div>
        <div class="metric-card" v-if="result.monthly_payment_change != null">
          <div class="metric-label">月供变动</div>
          <div class="metric-value" :class="result.monthly_payment_change > 0 ? 'negative' : 'positive'">
            {{ result.monthly_payment_change > 0 ? '+' : '' }}¥{{ formatNumber(result.monthly_payment_change) }}
          </div>
        </div>
        <div class="metric-card">
          <div class="metric-label">负债压力</div>
          <div class="metric-value" :class="pressureClass">{{ pressureLabel }}</div>
        </div>
      </div>

      <!-- 图表 -->
      <el-card class="chart-card">
        <template #header>
          <span class="card-title">趋势图</span>
        </template>
        <div ref="chartRef" class="chart-container"></div>
      </el-card>

      <!-- 参数 -->
      <el-card class="text-card">
        <template #header>
          <span class="card-title">推演参数</span>
        </template>
        <div class="param-list">
          <div v-for="(val, key) in paramsObj" :key="key" class="param-item">
            <span class="param-key">{{ key }}:</span>
            <span class="param-val">{{ val }}</span>
          </div>
        </div>
      </el-card>

      <!-- 文字说明 -->
      <el-card class="text-card" v-if="result.net_assets_change">
        <template #header>
          <span class="card-title">净资产变动</span>
        </template>
        <div class="text-body">{{ result.net_assets_change }}</div>
      </el-card>

      <el-card class="text-card" v-if="result.cash_flow_change">
        <template #header>
          <span class="card-title">现金流变动</span>
        </template>
        <div class="text-body">{{ result.cash_flow_change }}</div>
      </el-card>

      <el-card class="text-card" v-if="result.debt_pressure_desc">
        <template #header>
          <span class="card-title">负债压力分析</span>
        </template>
        <div class="text-body">{{ result.debt_pressure_desc }}</div>
      </el-card>

      <!-- 结论 -->
      <el-card class="conclusion-card">
        <template #header>
          <span class="card-title">推演结论</span>
        </template>
        <div class="conclusion-body">{{ result.conclusion }}</div>
      </el-card>
    </template>

    <div v-else class="empty-tip">
      <el-empty description="未找到推演记录" />
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, watch, nextTick } from 'vue'
import * as echarts from 'echarts'
import PageHeader from '../../common/PageHeader.vue'
import { getSandboxHistoryById, getSandboxResultByHistoryId } from '../../../services/sandbox/sandboxService'
import type { SandboxHistory, SandboxResult } from '../../../services/sandbox/sandboxService'

const props = defineProps<{ historyId: string | number }>()
const emit = defineEmits(['navigate'])

const history = ref<SandboxHistory | null>(null)
const result = ref<SandboxResult | null>(null)
const loading = ref(false)
const chartRef = ref<HTMLElement | null>(null)
let chart: echarts.ECharts | null = null

const paramsObj = computed(() => {
  if (!history.value) return {}
  try {
    return JSON.parse(history.value.params)
  } catch {
    return {}
  }
})

const netAssetsClass = computed(() => {
  if (!result.value?.net_assets) return ''
  return result.value.net_assets >= 0 ? 'positive' : 'negative'
})

const cashFlowClass = computed(() => {
  if (!result.value?.cash_flow_monthly) return ''
  return result.value.cash_flow_monthly >= 0 ? 'positive' : 'negative'
})

const pressureClass = computed(() => {
  const level = result.value?.debt_pressure_level
  if (level === 1) return 'positive'
  if (level === 2) return 'warning'
  if (level === 3) return 'caution'
  return 'negative'
})

const pressureLabel = computed(() => {
  const map: Record<number, string> = { 1: '健康', 2: '良好', 3: '注意', 4: '风险' }
  return map[result.value?.debt_pressure_level || 0] || '-'
})

const formatNumber = (val: number | null | undefined) => {
  if (val == null) return '-'
  return val.toLocaleString('zh-CN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
}

const loadData = async () => {
  loading.value = true
  try {
    history.value = await getSandboxHistoryById(props.historyId)
    if (history.value) {
      result.value = await getSandboxResultByHistoryId(props.historyId)
      nextTick(() => initChart())
    }
  } finally {
    loading.value = false
  }
}

onMounted(loadData)

watch(() => props.historyId, loadData)

const goBack = () => {
  emit('navigate', 'sandboxHistory')
}

const initChart = () => {
  if (!chartRef.value || !result.value) return
  if (chart) {
    chart.dispose()
    chart = null
  }
  chart = echarts.init(chartRef.value)

  const xData: string[] = JSON.parse(result.value.chart_x || '[]')
  const netAssetsData: number[] = JSON.parse(result.value.chart_net_assets || '[]')
  const cashFlowData: number[] = JSON.parse(result.value.chart_cash_flow || '[]')
  const debtData: number[] = JSON.parse(result.value.chart_debt || '[]')

  const option = {
    tooltip: { trigger: 'axis' },
    legend: { data: ['净资产', '现金流', '负债'], bottom: 0, textStyle: { fontSize: 11 } },
    grid: { left: '3%', right: '4%', top: '10%', bottom: '18%', containLabel: true },
    xAxis: { type: 'category', data: xData, axisLabel: { fontSize: 10 } },
    yAxis: [
      { type: 'value', axisLabel: { fontSize: 10, formatter: (v: number) => v >= 10000 ? (v / 10000).toFixed(1) + '万' : v.toFixed(0) } },
    ],
    series: [
      { name: '净资产', type: 'line', smooth: true, data: netAssetsData, lineStyle: { color: '#67c23a', width: 2 }, itemStyle: { color: '#67c23a' }, symbolSize: 4 },
      { name: '现金流', type: 'line', smooth: true, data: cashFlowData, lineStyle: { color: '#409eff', width: 2 }, itemStyle: { color: '#409eff' }, symbolSize: 4 },
      { name: '负债', type: 'line', smooth: true, data: debtData, lineStyle: { color: '#f56c6c', width: 2 }, itemStyle: { color: '#f56c6c' }, symbolSize: 4 }
    ]
  }
  chart.setOption(option)
}
</script>

<style scoped>
.sandbox-result {
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

.info-bar {
  font-size: 12px;
  color: #909399;
  text-align: center;
  margin-bottom: 12px;
}

.metric-cards {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 10px;
  margin-bottom: 12px;
}

.metric-card {
  background: #fff;
  border-radius: 10px;
  padding: 14px;
  text-align: center;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.06);
}

.metric-label {
  font-size: 12px;
  color: #909399;
  margin-bottom: 6px;
}

.metric-value {
  font-size: 16px;
  font-weight: 700;
  color: #303133;
}

.metric-value.positive { color: #67c23a; }
.metric-value.negative { color: #f56c6c; }
.metric-value.warning { color: #e6a23c; }
.metric-value.caution { color: #ff9d00; }

.chart-card,
.text-card,
.conclusion-card {
  margin-bottom: 12px;
}

.card-title {
  font-weight: 600;
  font-size: 14px;
}

.chart-container {
  width: 100%;
  height: 240px;
}

.param-list {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.param-item {
  display: flex;
  justify-content: space-between;
  font-size: 13px;
}

.param-key {
  color: #909399;
}

.param-val {
  color: #303133;
  font-weight: 500;
}

.text-body {
  font-size: 13px;
  color: #606266;
  line-height: 1.6;
}

.conclusion-body {
  font-size: 14px;
  color: #303133;
  line-height: 1.7;
  background: #f0f9ff;
  padding: 12px;
  border-radius: 8px;
}
</style>
