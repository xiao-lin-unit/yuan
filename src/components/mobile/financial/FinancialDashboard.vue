<template>
  <div class="financial-dashboard">
    <el-card>
      <template #header>
        <div class="card-header">
          <span>财务健康评估</span>
        </div>
      </template>
      
      <div class="dashboard-grid">
        <div class="dashboard-item">
          <h3>负债收入比</h3>
          <div class="value">{{ healthData.liabilitiesIncomeRatio }}%</div>
          <div class="status" :class="getStatusClass('liabilities')">
            {{ getStatusText('liabilities') }}
          </div>
        </div>
        
        <div class="dashboard-item">
          <h3>应急金充足率</h3>
          <div class="value">{{ healthData.emergencyFundRatio }}%</div>
          <div class="status" :class="getStatusClass('emergency')">
            {{ getStatusText('emergency') }}
          </div>
        </div>
        
        <div class="dashboard-item">
          <h3>资产负债率</h3>
          <div class="value">{{ healthData.assetLiabilityRatio }}%</div>
          <div class="status" :class="getStatusClass('assetLiability')">
            {{ getStatusText('assetLiability') }}
          </div>
        </div>
        
        <div class="dashboard-item">
          <h3>储蓄率</h3>
          <div class="value">{{ healthData.savingsRate }}%</div>
          <div class="status" :class="getStatusClass('savings')">
            {{ getStatusText('savings') }}
          </div>
        </div>
        
        <div class="dashboard-item">
          <h3>净资产增长率</h3>
          <div class="value">{{ healthData.netAssetGrowth }}%</div>
          <div class="status" :class="getStatusClass('growth')">
            {{ getStatusText('growth') }}
          </div>
        </div>
        
        <div class="dashboard-item">
          <h3>财务健康评分</h3>
          <div class="value">{{ healthData.totalScore }}</div>
          <div class="status" :class="getStatusClass('score')">
            {{ getStatusText('score') }}
          </div>
        </div>
      </div>
    </el-card>
    
    <el-card class="mt-4">
      <template #header>
        <div class="card-header">
          <span>净资产增长率趋势</span>
          <el-select v-model="timeRange" placeholder="选择时间范围">
            <el-option label="月度" value="monthly" />
            <el-option label="季度" value="quarterly" />
            <el-option label="年度" value="yearly" />
          </el-select>
        </div>
      </template>
      <div ref="chartRef" class="chart-container"></div>
    </el-card>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, watch, nextTick } from 'vue'
import * as echarts from 'echarts'

const chartRef = ref(null)
let chart = null
const timeRange = ref('monthly')

const healthData = ref({
  liabilitiesIncomeRatio: 25,
  emergencyFundRatio: 80,
  assetLiabilityRatio: 35,
  savingsRate: 28,
  netAssetGrowth: 12,
  totalScore: 85
})

const growthData = ref({
  monthly: {
    labels: ['1月', '2月', '3月', '4月', '5月', '6月'],
    data: [2.5, 3.2, 1.8, 4.5, 3.8, 5.2]
  },
  quarterly: {
    labels: ['Q1', 'Q2', 'Q3', 'Q4'],
    data: [8.5, 12.3, 9.8, 15.2]
  },
  yearly: {
    labels: ['2022', '2023', '2024', '2025', '2026'],
    data: [15.2, 18.5, 12.8, 16.5, 20.3]
  }
})

onMounted(() => {
  initChart()
})

watch(timeRange, () => {
  updateChart()
})

const initChart = () => {
  if (chartRef.value) {
    chart = echarts.init(chartRef.value)
    updateChart()
  }
}

const updateChart = () => {
  if (chart) {
    const data = growthData.value[timeRange.value]
    const option = {
      tooltip: {
        trigger: 'axis',
        formatter: '{b}: {c}%'
      },
      xAxis: {
        type: 'category',
        data: data.labels
      },
      yAxis: {
        type: 'value',
        axisLabel: {
          formatter: '{value}%'
        }
      },
      series: [{
        data: data.data,
        type: 'line',
        smooth: true,
        areaStyle: {
          color: {
            type: 'linear',
            x: 0,
            y: 0,
            x2: 0,
            y2: 1,
            colorStops: [{
              offset: 0, color: 'rgba(64, 158, 255, 0.5)'
            }, {
              offset: 1, color: 'rgba(64, 158, 255, 0.1)'
            }]
          }
        },
        lineStyle: {
          color: '#409EFF'
        },
        itemStyle: {
          color: '#409EFF'
        }
      }]
    }
    chart.setOption(option)
  }
}

const getStatusClass = (type: string) => {
  switch (type) {
    case 'liabilities':
      return healthData.value.liabilitiesIncomeRatio <= 30 ? 'good' : healthData.value.liabilitiesIncomeRatio <= 50 ? 'warning' : 'danger'
    case 'emergency':
      return healthData.value.emergencyFundRatio >= 100 ? 'good' : healthData.value.emergencyFundRatio >= 50 ? 'warning' : 'danger'
    case 'assetLiability':
      return healthData.value.assetLiabilityRatio <= 40 ? 'good' : healthData.value.assetLiabilityRatio <= 60 ? 'warning' : 'danger'
    case 'savings':
      return healthData.value.savingsRate >= 30 ? 'good' : healthData.value.savingsRate >= 20 ? 'warning' : 'danger'
    case 'growth':
      return healthData.value.netAssetGrowth >= 8 ? 'good' : healthData.value.netAssetGrowth >= 5 ? 'warning' : 'danger'
    case 'score':
      return healthData.value.totalScore >= 80 ? 'good' : healthData.value.totalScore >= 60 ? 'warning' : 'danger'
    default:
      return 'good'
  }
}

const getStatusText = (type: string) => {
  switch (type) {
    case 'liabilities':
      return healthData.value.liabilitiesIncomeRatio <= 30 ? '健康' : healthData.value.liabilitiesIncomeRatio <= 50 ? '预警' : '危险'
    case 'emergency':
      return healthData.value.emergencyFundRatio >= 100 ? '充足' : healthData.value.emergencyFundRatio >= 50 ? '不足' : '严重不足'
    case 'assetLiability':
      return healthData.value.assetLiabilityRatio <= 40 ? '健康' : healthData.value.assetLiabilityRatio <= 60 ? '预警' : '危险'
    case 'savings':
      return healthData.value.savingsRate >= 30 ? '优秀' : healthData.value.savingsRate >= 20 ? '良好' : '待提升'
    case 'growth':
      return healthData.value.netAssetGrowth >= 8 ? '优秀' : healthData.value.netAssetGrowth >= 5 ? '良好' : '待提升'
    case 'score':
      return healthData.value.totalScore >= 80 ? '优秀' : healthData.value.totalScore >= 60 ? '良好' : '待提升'
    default:
      return '未知'
  }
}
</script>

<style scoped>
.financial-dashboard {
  padding: 0;
}

.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.mt-4 {
  margin-top: 20px;
}

.dashboard-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
  gap: 20px;
  margin-top: 20px;
}

.dashboard-item {
  background-color: #f5f7fa;
  padding: 20px;
  border-radius: 8px;
  text-align: center;
}

.dashboard-item h3 {
  margin: 0 0 10px 0;
  font-size: 14px;
  color: #606266;
}

.dashboard-item .value {
  font-size: 24px;
  font-weight: bold;
  margin-bottom: 10px;
}

.dashboard-item .status {
  font-size: 12px;
  padding: 4px 12px;
  border-radius: 12px;
  display: inline-block;
}

.status.good {
  background-color: #f0f9eb;
  color: #67c23a;
}

.status.warning {
  background-color: #fdf6ec;
  color: #e6a23c;
}

.status.danger {
  background-color: #fef0f0;
  color: #f56c6c;
}

.chart-container {
  width: 100%;
  height: 400px;
  margin-top: 20px;
}
</style>