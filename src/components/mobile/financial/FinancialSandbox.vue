<template>
  <div class="financial-sandbox">
    <el-card>
      <template #header>
        <div class="card-header">
          <span>情景模拟・财务沙盘</span>
          <el-button type="primary" @click="openCreateSandboxDialog">创建沙盘</el-button>
        </div>
      </template>
      
      <el-table :data="sandboxes" style="width: 100%">
        <el-table-column prop="id" label="ID" width="80" />
        <el-table-column prop="name" label="沙盘名称" />
        <el-table-column prop="created_at" label="创建时间" />
        <el-table-column label="操作" width="200">
          <template #default="scope">
            <el-button type="primary" size="small" @click="openSandbox(scope.row)">打开</el-button>
            <el-button size="small" @click="syncSandbox(scope.row)">同步数据</el-button>
            <el-button type="danger" size="small" @click="deleteSandbox(scope.row.id)">删除</el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-card>
    
    <!-- 创建沙盘对话框 -->
    <el-dialog v-model="dialogVisible.createSandbox" title="创建沙盘" width="500px">
      <el-form :model="sandboxForm" label-width="80px">
        <el-form-item label="沙盘名称">
          <el-input v-model="sandboxForm.name" placeholder="请输入沙盘名称" />
        </el-form-item>
        <el-form-item label="预设情景">
          <el-select v-model="sandboxForm.scenario" placeholder="请选择预设情景">
            <el-option label="失业3个月" value="unemployment" />
            <el-option label="利率上涨1%" value="interest_rate_increase" />
            <el-option label="股市下跌20%" value="stock_market_drop" />
            <el-option label="每月多存1000元" value="monthly_saving" />
            <el-option label="提前还清负债" value="early_repayment" />
            <el-option label="自定义" value="custom" />
          </el-select>
        </el-form-item>
        <el-form-item label="模拟周期(月)">
          <el-input v-model.number="sandboxForm.period" placeholder="请输入模拟周期" type="number" min="1" />
        </el-form-item>
      </el-form>
      <template #footer>
        <span class="dialog-footer">
          <el-button @click="dialogVisible.createSandbox = false">取消</el-button>
          <el-button type="primary" @click="createSandbox">确定</el-button>
        </span>
      </template>
    </el-dialog>
    
    <!-- 沙盘详情对话框 -->
    <el-dialog v-model="dialogVisible.sandboxDetail" title="沙盘详情" width="800px">
      <div class="sandbox-detail">
        <div class="sandbox-header">
          <h3>{{ currentSandbox?.name }}</h3>
          <div class="sandbox-actions">
            <el-button @click="runSimulation">运行模拟</el-button>
            <el-button @click="exportResult">导出结果</el-button>
          </div>
        </div>
        
        <div class="simulation-params">
          <h4>模拟参数</h4>
          <el-form :model="simulationParams" label-width="150px">
            <el-form-item label="模拟周期(月)">
              <el-input v-model.number="simulationParams.period" type="number" min="1" />
            </el-form-item>
            <el-form-item label="主动收入变化(%)">
              <el-input v-model.number="simulationParams.activeIncomeChange" type="number" />
            </el-form-item>
            <el-form-item label="被动收入变化(%)">
              <el-input v-model.number="simulationParams.passiveIncomeChange" type="number" />
            </el-form-item>
            <el-form-item label="固定支出变化(%)">
              <el-input v-model.number="simulationParams.fixedExpenseChange" type="number" />
            </el-form-item>
            <el-form-item label="股票市值变化(%)">
              <el-input v-model.number="simulationParams.stockMarketChange" type="number" />
            </el-form-item>
            <el-form-item label="负债利率变化(%)">
              <el-input v-model.number="simulationParams.interestRateChange" type="number" />
            </el-form-item>
          </el-form>
        </div>
        
        <div class="simulation-results" v-if="simulationResults">
          <h4>模拟结果</h4>
          <div class="results-grid">
            <div class="result-item">
              <span class="result-label">期末净资产</span>
              <span class="result-value">¥{{ simulationResults.finalNetAsset.toFixed(2) }}</span>
            </div>
            <div class="result-item">
              <span class="result-label">净资产变化</span>
              <span class="result-value" :class="simulationResults.netAssetChange >= 0 ? 'positive' : 'negative'">
                {{ simulationResults.netAssetChange >= 0 ? '+' : '' }}{{ simulationResults.netAssetChange.toFixed(2) }}%
              </span>
            </div>
            <div class="result-item">
              <span class="result-label">每月现金流</span>
              <span class="result-value" :class="simulationResults.monthlyCashFlow >= 0 ? 'positive' : 'negative'">
                ¥{{ simulationResults.monthlyCashFlow.toFixed(2) }}
              </span>
            </div>
            <div class="result-item">
              <span class="result-label">负债收入比</span>
              <span class="result-value">{{ simulationResults.liabilitiesIncomeRatio.toFixed(2) }}%</span>
            </div>
          </div>
          <div ref="resultChartRef" class="result-chart"></div>
        </div>
      </div>
      <template #footer>
        <span class="dialog-footer">
          <el-button @click="dialogVisible.sandboxDetail = false">关闭</el-button>
        </span>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, watch, nextTick } from 'vue'
import * as echarts from 'echarts'

const sandboxes = ref([])
const currentSandbox = ref(null)
const dialogVisible = ref({
  createSandbox: false,
  sandboxDetail: false
})

const sandboxForm = ref({
  name: '',
  scenario: 'custom',
  period: 12
})

const simulationParams = ref({
  period: 12,
  activeIncomeChange: 0,
  passiveIncomeChange: 0,
  fixedExpenseChange: 0,
  stockMarketChange: 0,
  interestRateChange: 0
})

const simulationResults = ref(null)
const resultChartRef = ref(null)
let resultChart = null

onMounted(() => {
  loadSandboxes()
})

const loadSandboxes = () => {
  // 模拟数据
  sandboxes.value = [
    {
      id: '1',
      name: '失业场景模拟',
      created_at: '2024-01-01 10:00:00'
    },
    {
      id: '2',
      name: '利率上涨模拟',
      created_at: '2024-02-01 14:00:00'
    }
  ]
}

const openCreateSandboxDialog = () => {
  sandboxForm.value = {
    name: '',
    scenario: 'custom',
    period: 12
  }
  dialogVisible.value.createSandbox = true
}

const createSandbox = () => {
  // 模拟创建沙盘
  const newSandbox = {
    id: Date.now().toString(),
    name: sandboxForm.value.name,
    created_at: new Date().toLocaleString()
  }
  sandboxes.value.push(newSandbox)
  dialogVisible.value.createSandbox = false
}

const openSandbox = (sandbox: any) => {
  currentSandbox.value = sandbox
  simulationParams.value = {
    period: 12,
    activeIncomeChange: 0,
    passiveIncomeChange: 0,
    fixedExpenseChange: 0,
    stockMarketChange: 0,
    interestRateChange: 0
  }
  simulationResults.value = null
  dialogVisible.value.sandboxDetail = true
}

const syncSandbox = (sandbox: any) => {
  // 模拟同步数据
  alert('数据同步成功')
}

const deleteSandbox = (id: string) => {
  // 模拟删除沙盘
  sandboxes.value = sandboxes.value.filter(s => s.id !== id)
}

const runSimulation = () => {
  // 模拟运行结果
  simulationResults.value = {
    finalNetAsset: 120000,
    netAssetChange: 20,
    monthlyCashFlow: 5000,
    liabilitiesIncomeRatio: 25
  }
  nextTick(() => {
    initResultChart()
  })
}

const exportResult = () => {
  // 模拟导出结果
  alert('结果导出成功')
}

const initResultChart = () => {
  if (resultChartRef.value) {
    resultChart = echarts.init(resultChartRef.value)
    const option = {
      tooltip: {
        trigger: 'axis'
      },
      legend: {
        data: ['净资产', '现金流']
      },
      xAxis: {
        type: 'category',
        data: ['1月', '2月', '3月', '4月', '5月', '6月', '7月', '8月', '9月', '10月', '11月', '12月']
      },
      yAxis: {
        type: 'value'
      },
      series: [
        {
          name: '净资产',
          type: 'line',
          data: [100000, 102000, 104000, 106000, 108000, 110000, 112000, 114000, 116000, 118000, 119000, 120000],
          smooth: true
        },
        {
          name: '现金流',
          type: 'bar',
          data: [5000, 5100, 4900, 5200, 5000, 5300, 5100, 5200, 5000, 4900, 5100, 5200]
        }
      ]
    }
    resultChart.setOption(option)
  }
}
</script>

<style scoped>
.financial-sandbox {
  padding: 0;
}

.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.dialog-footer {
  width: 100%;
  display: flex;
  justify-content: flex-end;
}

.sandbox-detail {
  padding: 20px 0;
}

.sandbox-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20px;
}

.sandbox-header h3 {
  margin: 0;
}

.simulation-params {
  margin-bottom: 30px;
  padding: 20px;
  background-color: #f5f7fa;
  border-radius: 8px;
}

.simulation-params h4 {
  margin: 0 0 20px 0;
}

.simulation-results {
  margin-top: 30px;
}

.simulation-results h4 {
  margin: 0 0 20px 0;
}

.results-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
  gap: 20px;
  margin-bottom: 30px;
}

.result-item {
  background-color: #f5f7fa;
  padding: 20px;
  border-radius: 8px;
  text-align: center;
}

.result-label {
  display: block;
  font-size: 14px;
  color: #606266;
  margin-bottom: 10px;
}

.result-value {
  display: block;
  font-size: 20px;
  font-weight: bold;
}

.result-value.positive {
  color: #67c23a;
}

.result-value.negative {
  color: #f56c6c;
}

.result-chart {
  width: 100%;
  height: 400px;
}
</style>