<template>
  <div class="financial-dashboard">
    <!-- 综合评分卡片 -->
    <el-card class="score-card">
      <div class="score-section">
        <div class="score-circle" :class="scoreGradeClass">
          <div class="score-value">{{ comprehensiveScore }}</div>
          <div class="score-label">综合评分</div>
        </div>
        <div class="score-info">
          <div class="score-grade" :class="scoreGradeClass">{{ scoreGrade }}</div>
          <div class="score-comment">{{ scoreComment }}</div>
        </div>
      </div>
    </el-card>

    <!-- 财务健康指标 -->
    <el-card class="mt-4">
      <template #header>
        <div class="card-header">
          <span>财务健康指标</span>
        </div>
      </template>
      <div class="indicators-grid">
        <div
          v-for="indicator in indicators"
          :key="indicator.key"
          class="indicator-item"
          :class="indicator.borderClass"
        >
          <div class="indicator-header">
            <span class="indicator-name">{{ indicator.name }}</span>
            <el-tag
              v-if="indicator.hasStatus"
              :type="indicator.statusType"
              size="small"
              effect="light"
            >
              {{ indicator.statusText }}
            </el-tag>
          </div>
          <div class="indicator-value" :class="indicator.valueClass">
            {{ indicator.formattedValue }}
          </div>
          <div class="indicator-formula">{{ indicator.formula }}</div>
        </div>
      </div>
    </el-card>

    <!-- 资产趋势图表 -->
    <el-card class="mt-4">
      <template #header>
        <div class="card-header">
          <span>趋势</span>
          <el-select v-model="timeRange" placeholder="选择时间范围" size="small" class="time-range-select">
            <el-option label="近6个月" value="6months" />
            <el-option label="近12个月" value="12months" />
          </el-select>
        </div>
      </template>
      <div v-if="!hasSnapshotData" class="no-data-tip">暂无历史数据，系统将自动记录每月资产变化</div>
      <div ref="chartRef" class="chart-container"></div>
    </el-card>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, watch, nextTick } from 'vue'
import dayjs from 'dayjs'
import * as echarts from 'echarts'
import db from '../../../database'

// ============ 图表相关 ============
const chartRef = ref<HTMLElement | null>(null)
let chart: echarts.ECharts | null = null
const timeRange = ref('6months')
const hasSnapshotData = ref(false)

// ============ 原始数据 ============
const accounts = ref<any[]>([])
const assets = ref<any[]>([])
const stocks = ref<any[]>([])
const funds = ref<any[]>([])
const liabilities = ref<any[]>([])
const monthlyIncome = ref(0)
const monthlyExpense = ref(0)
const monthlyRepayment = ref(0)
const confirmedProfitStocks = ref(0)
const confirmedProfitFunds = ref(0)
const lastMonthSnapshot = ref<any>(null)

const loadSnapshot = async (year: number, month: number) => {
  console.log('加载快照数据:', year, month)
  const result = await db.query(
    'SELECT * FROM asset_monthly_snapshots WHERE year = ? AND month = ?',
    [year, month]
  )
  return result.length > 0 ? result[0] : null
}

const getSnapshotHistory = async (months: number) => {
  const now = dayjs()
  const endYear = now.year()
  const endMonth = now.month() + 1
  const start = now.subtract(months - 1, 'month')
  const startYear = start.year()
  const startMonth = start.month() + 1
  console.log('获取快照历史数据:', startYear, startMonth, endYear, endMonth)
  const result = await db.query(
    `SELECT * FROM asset_monthly_snapshots
     WHERE (year > ? OR (year = ? AND month >= ?))
       AND (year < ? OR (year = ? AND month <= ?))
     ORDER BY year, month`,
    [startYear, startYear, startMonth, endYear, endYear, endMonth]
  )

  return result.map((row: any) => ({
    label: `${row.month}月`,
    fullLabel: `${row.year}-${String(row.month).padStart(2, '0')}`,
    totalAssets: row.total_assets || 0,
    netWorth: row.net_worth || 0
  }))
}

// ============ 数据加载 ============
const loadAllData = async () => {
  try {
    await db.connect()
    const now = dayjs()
    const monthStart = now.startOf('month').toISOString()
    const monthEnd = now.endOf('month').toISOString()
    const monthStartDate = now.startOf('month').format('YYYY-MM-DD')
    const monthEndDate = now.endOf('month').format('YYYY-MM-DD')

    // 加载账户数据
    accounts.value = await db.query(
      "SELECT * FROM accounts WHERE status IS NULL OR status = '启用' ORDER BY created_at DESC"
    )

    // 加载资产数据
    assets.value = await db.query('SELECT * FROM assets ORDER BY created_at DESC')

    // 加载股票数据
    stocks.value = await db.query('SELECT * FROM stocks ORDER BY created_at DESC')

    // 加载基金数据
    funds.value = await db.query('SELECT * FROM funds ORDER BY created_at DESC')

    // 加载负债数据
    liabilities.value = await db.query('SELECT * FROM liabilities ORDER BY created_at DESC')

    // 月度收入（账户收入）
    const incomeResult = await db.query(
      "SELECT SUM(amount) as total FROM transactions WHERE type = ? AND created_at BETWEEN ? AND ?",
      ['账户收入', monthStart, monthEnd]
    )
    monthlyIncome.value = incomeResult[0]?.total || 0

    // 月度支出（账户支出，不含投资相关）
    const expenseResult = await db.query(
      "SELECT SUM(amount) as total FROM transactions WHERE type = ? AND created_at BETWEEN ? AND ?",
      ['账户支出', monthStart, monthEnd]
    )
    monthlyExpense.value = expenseResult[0]?.total || 0

    // 月度总还款（当月待还）
    const repaymentResult = await db.query(
      "SELECT SUM(total_amount) as total FROM pending_repayments WHERE due_date BETWEEN ? AND ?",
      [monthStartDate, monthEndDate]
    )
    monthlyRepayment.value = repaymentResult[0]?.total || 0

    // 累计已实现盈亏
    confirmedProfitStocks.value = stocks.value.reduce((sum, s) => sum + (s.confirmed_profit || 0), 0)
    confirmedProfitFunds.value = funds.value.reduce((sum, f) => sum + (f.confirmed_profit || 0), 0)

    // 加载上月快照
    const lastMonth = now.subtract(1, 'month')
    lastMonthSnapshot.value = await loadSnapshot(lastMonth.year(), lastMonth.month() + 1)
  } catch (error) {
    console.error('加载财务数据失败:', error)
  }
}

// ============ 指标计算 ============
// 流动资金 = 流动账户余额（不含信用卡）
const liquidFunds = computed(() => {
  return accounts.value
    .filter((a: any) => a.type !== '信用卡')
    .reduce((sum, a) => sum + (a.balance || 0), 0)
})

// 社保资产
const socialSecurityAssets = computed(() => {
  return assets.value
    .filter((a: any) => a.type === '社保')
    .reduce((sum, a) => sum + (a.amount || 0), 0)
})

// 公积金资产
const providentFundAssets = computed(() => {
  return assets.value
    .filter((a: any) => a.type === '公积金')
    .reduce((sum, a) => sum + (a.amount || 0), 0)
})

// 股票市值
const stockMarketValue = computed(() => {
  return stocks.value.reduce((sum, s) => sum + (s.current_price || 0) * (s.quantity || 0), 0)
})

// 基金市值
const fundMarketValue = computed(() => {
  return funds.value.reduce((sum, f) => sum + (f.current_nav || 0) * (f.shares || 0), 0)
})

// 亲友借出
const loansToFriends = computed(() => {
  return assets.value
    .filter((a: any) => a.type === '亲友借款')
    .reduce((sum, a) => sum + (a.amount || 0), 0)
})

// 资产总额
const totalAssets = computed(() => {
  return (
    liquidFunds.value +
    socialSecurityAssets.value +
    providentFundAssets.value +
    stockMarketValue.value +
    fundMarketValue.value +
    loansToFriends.value
  )
})

// 信用卡已用额度
const creditCardUsed = computed(() => {
  return accounts.value
    .filter((a: any) => a.type === '信用卡')
    .reduce((sum, a) => sum + (a.used_limit || 0), 0)
})

// 总负债
const totalLiabilities = computed(() => {
  const liabilityPrincipal = liabilities.value.reduce(
    (sum, l) => sum + (l.remaining_principal || 0),
    0
  )
  return liabilityPrincipal + creditCardUsed.value
})

// 净资产
const netWorth = computed(() => {
  return totalAssets.value - totalLiabilities.value
})

// 月度现金流
const monthlyCashFlow = computed(() => {
  return monthlyIncome.value - monthlyExpense.value
})

// 月度投资盈亏变化
const monthlyInvestmentProfit = computed(() => {
  if (!lastMonthSnapshot.value) return 0
  const lastStocks = lastMonthSnapshot.value.confirmedProfitStocks || 0
  const lastFunds = lastMonthSnapshot.value.confirmedProfitFunds || 0
  const currentStocks = confirmedProfitStocks.value
  const currentFunds = confirmedProfitFunds.value
  return currentStocks + currentFunds - lastStocks - lastFunds
})

// 投资亏损（仅负数部分转为正数）
const monthlyInvestmentLoss = computed(() => {
  return monthlyInvestmentProfit.value < 0 ? Math.abs(monthlyInvestmentProfit.value) : 0
})

// 月度结余
const monthlyBalance = computed(() => {
  return monthlyIncome.value - monthlyExpense.value - monthlyInvestmentLoss.value - monthlyRepayment.value
})

// 债务收入比
const debtIncomeRatio = computed(() => {
  if (monthlyIncome.value === 0) return 0
  return (monthlyRepayment.value / monthlyIncome.value) * 100
})

// 资产负债率
const assetLiabilityRatio = computed(() => {
  if (totalAssets.value === 0) return 0
  return (totalLiabilities.value / totalAssets.value) * 100
})

// 资产月增长率
const assetGrowthRate = computed(() => {
  if (!lastMonthSnapshot.value) return 0
  const lastAssets = lastMonthSnapshot.value.totalAssets || 0
  if (lastAssets === 0) return 0
  return ((totalAssets.value - lastAssets) / lastAssets) * 100
})

// ============ 评分计算 ============
const comprehensiveScore = computed(() => {
  const maxPerIndicator = 100 / 6
  let score = 0

  // 1. 月度现金流
  if (monthlyCashFlow.value >= 0) score += maxPerIndicator

  // 2. 月度结余
  if (monthlyBalance.value >= 0) score += maxPerIndicator
  else if (monthlyBalance.value >= -1000) score += maxPerIndicator * 0.48

  // 3. 净资产
  if (netWorth.value > 0) score += maxPerIndicator
  else if (netWorth.value === 0) score += maxPerIndicator * 0.48

  // 4. 债务收入比
  if (debtIncomeRatio.value < 30) score += maxPerIndicator
  else if (debtIncomeRatio.value <= 50) score += maxPerIndicator * 0.48

  // 5. 资产负债率
  if (assetLiabilityRatio.value < 50) score += maxPerIndicator
  else if (assetLiabilityRatio.value <= 80) score += maxPerIndicator * 0.48

  // 6. 资产月增长率
  if (assetGrowthRate.value > 0) score += maxPerIndicator
  else if (assetGrowthRate.value === 0) score += maxPerIndicator * 0.48

  return Math.round(score)
})

const scoreGrade = computed(() => {
  const s = comprehensiveScore.value
  if (s >= 90) return '优秀'
  if (s >= 70) return '良好'
  if (s >= 50) return '一般'
  if (s >= 30) return '较弱'
  return '危险'
})

const scoreGradeClass = computed(() => {
  const s = comprehensiveScore.value
  if (s >= 90) return 'excellent'
  if (s >= 70) return 'good'
  if (s >= 50) return 'normal'
  if (s >= 30) return 'weak'
  return 'danger'
})

const scoreComment = computed(() => {
  const s = comprehensiveScore.value
  if (s >= 90) return '你的财务状况非常健康，资产持续增长，负债可控，已逐步跳出老鼠赛跑！'
  if (s >= 70) return '财务状况稳健，现金流充足，负债压力适中，继续坚持买入资产，离财务自由更近一步！'
  if (s >= 50) return '财务状况尚可，但存在一定优化空间，建议控制负债、增加被动收入，避免资产缩水。'
  if (s >= 30) return '财务状况偏弱，现金流紧张或资产缩水，需警惕负债压力，优先保证现金流为正。'
  return '财务状况危险，存在资不抵债或高负债压力，需立即调整收支结构，减少负债、增加收入。'
})

// ============ 指标列表 ============
const formatCurrency = (value: number) => {
  return '¥' + value.toFixed(2)
}

const indicators = computed(() => {
  const getStatus = (value: number, thresholds: number[], labels: string[], defaultType: string = 'success') => {
    for (let i = 0; i < thresholds.length; i++) {
      if (value < thresholds[i]) return { text: labels[i], type: ['success', 'warning', 'danger'][i] }
    }
    return { text: labels[thresholds.length], type: defaultType }
  }

  const getPositiveStatus = (value: number, thresholds: number[], labels: string[]) => {
    return getStatus(value, thresholds, labels, 'success')
  }

  const getNegativeStatus = (value: number, thresholds: number[], labels: string[]) => {
    return getStatus(value, thresholds, labels, 'danger')
  }


  const cashFlowStatus = getPositiveStatus(
    monthlyCashFlow.value,
    [0],
    ['危险', '健康']
  )

  const balanceStatus =
    monthlyBalance.value >= 0
      ? { text: '健康', type: 'success' }
      : monthlyBalance.value >= -1000
        ? { text: '预警', type: 'warning' }
        : { text: '危险', type: 'danger' }

  const netWorthStatus =
    netWorth.value > 0
      ? { text: '健康', type: 'success' }
      : netWorth.value === 0
        ? { text: '预警', type: 'warning' }
        : { text: '危险', type: 'danger' }

  const debtRatioStatus = getPositiveStatus(
    debtIncomeRatio.value,
    [30, 50],
    ['轻松', '正常', '危险']
  )

  const liabilityRatioStatus = getNegativeStatus(
    assetLiabilityRatio.value,
    [50, 80],
    ['健康', '偏高', '高风险']
  )

  const growthStatus =
    assetGrowthRate.value > 0
      ? { text: '增长', type: 'success' }
      : assetGrowthRate.value === 0
        ? { text: '停滞', type: 'warning' }
        : { text: '缩水', type: 'danger' }

  return [
    {
      key: 'cashFlow',
      name: '月度现金流',
      formattedValue: formatCurrency(monthlyCashFlow.value),
      formula: '收入 - 日常支出',
      hasStatus: true,
      statusText: cashFlowStatus.text,
      statusType: cashFlowStatus.type,
      borderClass: `border-${cashFlowStatus.type}`,
      valueClass: monthlyCashFlow.value >= 0 ? 'positive' : 'negative'
    },
    {
      key: 'balance',
      name: '月度结余',
      formattedValue: formatCurrency(monthlyBalance.value),
      formula: '收入 - 支出 - 投资亏损 - 月供',
      hasStatus: true,
      statusText: balanceStatus.text,
      statusType: balanceStatus.type,
      borderClass: `border-${balanceStatus.type}`,
      valueClass: monthlyBalance.value >= 0 ? 'positive' : 'negative'
    },
    {
      key: 'totalAssets',
      name: '资产总额',
      formattedValue: formatCurrency(totalAssets.value),
      formula: '流动+社保+公积金+股票+基金+借出',
      hasStatus: false,
      statusText: '',
      statusType: 'info',
      borderClass: '',
      valueClass: 'primary'
    },
    {
      key: 'totalLiabilities',
      name: '总负债',
      formattedValue: formatCurrency(totalLiabilities.value),
      formula: '所有负债剩余本金+信用卡已用',
      hasStatus: false,
      statusText: '',
      statusType: 'info',
      borderClass: '',
      valueClass: 'warning'
    },
    {
      key: 'netWorth',
      name: '净资产',
      formattedValue: formatCurrency(netWorth.value),
      formula: '资产总额 - 总负债',
      hasStatus: true,
      statusText: netWorthStatus.text,
      statusType: netWorthStatus.type,
      borderClass: `border-${netWorthStatus.type}`,
      valueClass: netWorth.value >= 0 ? 'positive' : 'negative'
    },
    {
      key: 'debtIncomeRatio',
      name: '债务收入比',
      formattedValue: debtIncomeRatio.value.toFixed(2) + '%',
      formula: '月供 / 月收入 × 100%',
      hasStatus: true,
      statusText: debtRatioStatus.text,
      statusType: debtRatioStatus.type,
      borderClass: `border-${debtRatioStatus.type}`,
      valueClass: debtIncomeRatio.value < 30 ? 'positive' : debtIncomeRatio.value <= 50 ? 'warning' : 'negative'
    },
    {
      key: 'assetLiabilityRatio',
      name: '资产负债率',
      formattedValue: assetLiabilityRatio.value.toFixed(2) + '%',
      formula: '总负债 / 资产总额 × 100%',
      hasStatus: true,
      statusText: liabilityRatioStatus.text,
      statusType: liabilityRatioStatus.type,
      borderClass: `border-${liabilityRatioStatus.type}`,
      valueClass: assetLiabilityRatio.value < 50 ? 'positive' : assetLiabilityRatio.value <= 80 ? 'warning' : 'negative'
    },
    {
      key: 'assetGrowthRate',
      name: '资产月增长率',
      formattedValue:
        (!lastMonthSnapshot.value ? '0.00' : assetGrowthRate.value.toFixed(2)) + '%',
      formula: '(本月资产 - 上月资产) / 上月资产 × 100%',
      hasStatus: true,
      statusText: growthStatus.text,
      statusType: growthStatus.type,
      borderClass: `border-${growthStatus.type}`,
      valueClass: assetGrowthRate.value > 0 ? 'positive' : assetGrowthRate.value === 0 ? 'warning' : 'negative'
    }
  ]
})

// ============ 图表 ============
const initChart = () => {
  if (chartRef.value) {
    chart = echarts.init(chartRef.value)
    updateChart()
  }
}

const updateChart = async () => {
  if (!chart) return
  const months = timeRange.value === '6months' ? 6 : 12
  const history = await getSnapshotHistory(months)
  hasSnapshotData.value = history.length > 0

  if (history.length === 0) {
    chart.clear()
    return
  }

  const option = {
    tooltip: {
      trigger: 'axis',
      formatter: (params: any) => {
        const p = params[0]
        return `${p.name}<br/>资产总额: ¥${p.value.toFixed(2)}`
      }
    },
    grid: {
      left: '3%',
      right: '4%',
      top: '12%',
      bottom: '3%',
      containLabel: true
    },
    xAxis: {
      type: 'category',
      data: history.map((h: any) => h.label),
      axisLabel: { fontSize: 11 }
    },
    yAxis: {
      type: 'value',
      axisLabel: {
        formatter: (value: number) => {
          if (value >= 10000) return (value / 10000).toFixed(1) + '万'
          return value.toFixed(0)
        },
        fontSize: 11
      }
    },
    series: [
      {
        name: '资产总额',
        data: history.map((h: any) => h.totalAssets),
        type: 'line',
        smooth: true,
        symbol: 'circle',
        symbolSize: 6,
        lineStyle: { color: '#67c23a', width: 2 },
        itemStyle: { color: '#67c23a' },
        areaStyle: {
          color: {
            type: 'linear',
            x: 0,
            y: 0,
            x2: 0,
            y2: 1,
            colorStops: [
              { offset: 0, color: 'rgba(103, 194, 58, 0.3)' },
              { offset: 1, color: 'rgba(103, 194, 58, 0.05)' }
            ]
          }
        }
      }
    ]
  }
  chart.setOption(option, true)
}

watch(timeRange, () => {
  updateChart()
})

onMounted(() => {
  loadAllData().then(() => {
    nextTick(() => {
      initChart()
    })
  })
})
</script>

<style scoped>
.financial-dashboard {
  padding: 12px;
  background-color: #f5f7fa;
  min-height: 100vh;
}

.score-card {
  margin-bottom: 12px;
}

.score-section {
  display: flex;
  align-items: center;
  gap: 20px;
  padding: 10px 0;
}

.score-circle {
  width: 100px;
  height: 100px;
  border-radius: 50%;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  color: #fff;
  font-weight: bold;
  flex-shrink: 0;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
}

.score-circle.excellent {
  background: linear-gradient(135deg, #67c23a 0%, #85ce61 100%);
}

.score-circle.good {
  background: linear-gradient(135deg, #95d475 0%, #b3e19d 100%);
}

.score-circle.normal {
  background: linear-gradient(135deg, #e6a23c 0%, #eebe77 100%);
}

.score-circle.weak {
  background: linear-gradient(135deg, #f89898 0%, #fab6b6 100%);
}

.score-circle.danger {
  background: linear-gradient(135deg, #f56c6c 0%, #f89898 100%);
}

.score-value {
  font-size: 32px;
  line-height: 1;
}

.score-label {
  font-size: 12px;
  margin-top: 4px;
  opacity: 0.9;
}

.score-info {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.score-grade {
  font-size: 20px;
  font-weight: bold;
}

.score-grade.excellent {
  color: #67c23a;
}

.score-grade.good {
  color: #95d475;
}

.score-grade.normal {
  color: #e6a23c;
}

.score-grade.weak {
  color: #f89898;
}

.score-grade.danger {
  color: #f56c6c;
}

.score-comment {
  font-size: 13px;
  color: #606266;
  line-height: 1.5;
}

.mt-4 {
  margin-top: 12px;
}

.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  font-weight: bold;
}

.indicators-grid {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 12px;
}

.indicator-item {
  background-color: #fff;
  border-radius: 8px;
  padding: 14px;
  border-left: 4px solid transparent;
  box-shadow: 0 1px 4px rgba(0, 0, 0, 0.06);
}

.indicator-item.border-success {
  border-left-color: #67c23a;
}

.indicator-item.border-warning {
  border-left-color: #e6a23c;
}

.indicator-item.border-danger {
  border-left-color: #f56c6c;
}

.indicator-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 8px;
}

.indicator-name {
  font-size: 13px;
  color: #606266;
  font-weight: 500;
}

.indicator-value {
  font-size: 20px;
  font-weight: bold;
  margin-bottom: 6px;
  word-break: break-all;
}

.indicator-value.positive {
  color: #67c23a;
}

.indicator-value.negative {
  color: #f56c6c;
}

.indicator-value.warning {
  color: #e6a23c;
}

.indicator-value.primary {
  color: #409eff;
}

.indicator-formula {
  font-size: 11px;
  color: #909399;
  line-height: 1.3;
}

.chart-container {
  width: 100%;
  height: 220px;
}

.time-range-select {
  width: 100px;
}

.no-data-tip {
  text-align: center;
  color: #909399;
  font-size: 13px;
  padding: 20px 0;
}

.time-range-select :deep(.el-select__wrapper) {
  box-shadow: none !important;
  background: transparent;
  border: none !important;
}

@media (max-width: 375px) {
  .indicators-grid {
    grid-template-columns: 1fr;
  }
}
</style>
