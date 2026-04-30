import db from '../../database'
import { getCurrentDate } from '../../utils/timezone'

export interface SceneDef {
  sceneType: number
  name: string
  desc: string
  icon: string
  paramSchema: ParamField[]
}

export interface ParamField {
  key: string
  label: string
  type: 'switch' | 'number' | 'select' | 'text'
  options?: { label: string; value: any }[]
  defaultValue?: any
  min?: number
  max?: number
  step?: number
}

export interface SandboxHistory {
  id?: string
  scene_type: number
  scene_name: string
  user_title?: string
  simulate_time: string
  params: string
  result_desc?: string
  created_at: string
  is_deleted: number
  remark?: string
}

export interface SandboxResult {
  id?: string
  history_id: string
  net_assets?: number
  net_assets_change?: string
  cash_flow_monthly?: number
  cash_flow_change?: string
  debt_pressure_level?: number
  debt_pressure_desc?: string
  survival_months?: number
  interest_save?: number
  monthly_payment_change?: number
  total_interest_change?: number
  chart_x: string
  chart_net_assets: string
  chart_cash_flow: string
  chart_debt: string
  conclusion: string
  created_at: string
}

export const SCENES: SceneDef[] = [
  {
    sceneType: 1, name: '失业维持时长推演', desc: '推演失业后依靠现有资产和被动收入可维持生活的时长', icon: 'Wallet',
    paramSchema: [
      { key: 'retain_passive_income', label: '保留被动收入', type: 'switch', defaultValue: true },
      { key: 'suspend_expense', label: '暂停非必要支出', type: 'switch', defaultValue: false }
    ]
  },
  {
    sceneType: 2, name: '债务利率上涨推演', desc: '推演债务利率上涨后对月供和总利息的影响', icon: 'TrendCharts',
    paramSchema: [
      { key: 'rate_increase', label: '利率涨幅(%)', type: 'number', defaultValue: 1, min: 0.1, max: 10, step: 0.1 }
    ]
  },
  {
    sceneType: 3, name: '股票/基金下跌推演', desc: '推演投资组合下跌对净资产的影响及回本预测', icon: 'Bottom',
    paramSchema: [
      { key: 'decline_rate', label: '下跌幅度(%)', type: 'number', defaultValue: 20, min: 1, max: 90, step: 1 },
      { key: 'hold_quantity', label: '保持持仓', type: 'switch', defaultValue: true }
    ]
  },
  {
    sceneType: 4, name: '每月多存流动资金推演', desc: '推演每月定额增存后的资产积累效果', icon: 'Money',
    paramSchema: [
      { key: 'monthly_deposit', label: '每月新增存款(元)', type: 'number', defaultValue: 1500, min: 100, step: 100 },
      { key: 'simulate_period', label: '推演周期(月)', type: 'select', defaultValue: 36, options: [{ label: '12', value: 12 }, { label: '24', value: 24 }, { label: '36', value: 36 }, { label: '48', value: 48 }, { label: '60', value: 60 }] }
    ]
  },
  {
    sceneType: 5, name: '提前还清负债推演', desc: '推演使用流动资产提前还清负债后的财务状况', icon: 'Checked',
    paramSchema: [
      { key: 'repay_amount', label: '提前还款金额(元)', type: 'number', defaultValue: 30000, min: 1000, step: 1000 }
    ]
  },
  {
    sceneType: 6, name: '收入上涨推演', desc: '推演收入增长对净资产和现金流的长期影响', icon: 'Top',
    paramSchema: [
      { key: 'rise_rate', label: '收入涨幅(%)', type: 'number', defaultValue: 15, min: 1, max: 100, step: 1 },
      { key: 'simulate_period', label: '推演周期(月)', type: 'select', defaultValue: 24, options: [{ label: '1年', value: 12 }, { label: '2年', value: 24 }, { label: '3年', value: 36 }] }
    ]
  },
  {
    sceneType: 7, name: '大额一次性支出推演', desc: '推演大额支出对净资产和现金流的影响', icon: 'ShoppingCart',
    paramSchema: [
      { key: 'expense_amount', label: '支出金额(元)', type: 'number', defaultValue: 20000, min: 1000, step: 1000 },
      { key: 'fund_source', label: '资金来源', type: 'select', defaultValue: 'current_assets', options: [{ label: '流动资产', value: 'current_assets' }, { label: '投资变现', value: 'investment' }, { label: '新增负债', value: 'debt' }] }
    ]
  },
  {
    sceneType: 8, name: '收入下降推演', desc: '推演收入下降后的现金流和净资产变化', icon: 'BottomLeft',
    paramSchema: [
      { key: 'decline_rate', label: '收入跌幅(%)', type: 'number', defaultValue: 20, min: 1, max: 100, step: 1 },
      { key: 'simulate_period', label: '推演周期(月)', type: 'select', defaultValue: 12, options: [{ label: '12', value: 12 }, { label: '24', value: 24 }, { label: '36', value: 36 }, { label: '48', value: 48 }, { label: '60', value: 60 }] }
    ]
  },
  {
    sceneType: 9, name: '投资变现推演', desc: '推演部分或全部投资变现后的财务状况', icon: 'Sell',
    paramSchema: [
      { key: 'sell_ratio', label: '变现比例(%)', type: 'number', defaultValue: 50, min: 1, max: 100, step: 1 },
      { key: 'fund_use', label: '资金用途', type: 'select', defaultValue: 'debt_repay', options: [{ label: '偿还负债', value: 'debt_repay' }, { label: '补充流动资产', value: 'current_assets' }, { label: '支付支出', value: 'expense' }] }
    ]
  },
  {
    sceneType: 10, name: '新增负债推演', desc: '推演新增一笔负债后的月供和总利息变化', icon: 'DocumentAdd',
    paramSchema: [
      { key: 'debt_amount', label: '负债金额(元)', type: 'number', defaultValue: 30000, min: 1000, step: 1000 },
      { key: 'annual_rate', label: '年利率(%)', type: 'number', defaultValue: 8, min: 0.1, max: 36, step: 0.1 },
      { key: 'repay_period', label: '还款期数(月)', type: 'number', defaultValue: 24, min: 3, max: 360, step: 1 }
    ]
  },
  {
    sceneType: 11, name: '应急金不足推演', desc: '推演补充应急金对现金流的影响及所需周期', icon: 'FirstAidKit',
    paramSchema: [
      { key: 'target_months', label: '目标应急月数', type: 'select', defaultValue: 6, options: [{ label: '3个月', value: 3 }, { label: '6个月', value: 6 }, { label: '12个月', value: 12 }] },
      { key: 'supplement_period', label: '补充周期(月)', type: 'select', defaultValue: 12, options: [{ label: '6个月', value: 6 }, { label: '12个月', value: 12 }, { label: '24个月', value: 24 }] }
    ]
  },
  {
    sceneType: 12, name: '投资亏损推演', desc: '推演投资品亏损后的净资产恢复趋势', icon: 'Warning',
    paramSchema: [
      { key: 'loss_rate', label: '亏损比例(%)', type: 'number', defaultValue: 15, min: 1, max: 100, step: 1 },
      { key: 'hold_period', label: '持有观察周期(月)', type: 'select', defaultValue: 6, options: [{ label: '6个月', value: 6 }, { label: '12个月', value: 12 }, { label: '24个月', value: 24 }] }
    ]
  },
  {
    sceneType: 13, name: '固定支出增加推演', desc: '推演固定支出增加后的现金流和净资产变化', icon: 'TrendCharts',
    paramSchema: [
      { key: 'increase_amount', label: '每月增加金额(元)', type: 'number', defaultValue: 500, min: 100, step: 100 },
      { key: 'increase_period', label: '增加持续周期(月)', type: 'select', defaultValue: 12, options: [{ label: '6个月', value: 6 }, { label: '12个月', value: 12 }, { label: '24个月', value: 24 }, { label: '36个月', value: 36 }] }
    ]
  },
  {
    sceneType: 14, name: '被动收入增加推演', desc: '推演被动收入增长对净资产积累的加速效果', icon: 'Coin',
    paramSchema: [
      { key: 'increase_amount', label: '每月增加金额(元)', type: 'number', defaultValue: 800, min: 100, step: 100 },
      { key: 'stable_period', label: '稳定持续周期(月)', type: 'select', defaultValue: 24, options: [{ label: '12', value: 12 }, { label: '24', value: 24 }, { label: '36', value: 36 }, { label: '48', value: 48 }, { label: '60', value: 60 }] }
    ]
  }
]

export function getSceneByType(sceneType: number): SceneDef | undefined {
  return SCENES.find(s => s.sceneType === sceneType)
}

// DB operations
export async function getSandboxHistoryList(): Promise<SandboxHistory[]> {
  return db.query(
    `SELECT * FROM sandbox_history WHERE is_deleted = 0 ORDER BY created_at DESC`
  )
}

export async function getSandboxHistoryById(id: number): Promise<SandboxHistory | null> {
  const rows = await db.query(`SELECT * FROM sandbox_history WHERE id = ? AND is_deleted = 0`, [id])
  return rows.length > 0 ? rows[0] : null
}

export async function getSandboxResultByHistoryId(historyId: number): Promise<SandboxResult | null> {
  const rows = await db.query(`SELECT * FROM sandbox_result WHERE history_id = ?`, [historyId])
  return rows.length > 0 ? rows[0] : null
}

export async function softDeleteSandboxHistory(id: string): Promise<void> {
  await db.run(`UPDATE sandbox_history SET is_deleted = 1 WHERE id = ?`, [id])
}

// 读取用户真实财务数据
async function loadUserFinancialData() {
  const accounts = await db.query(`SELECT * FROM accounts WHERE status = '启用'`)
  const assets = await db.query(`SELECT * FROM assets WHERE status != '结束'`)
  const stocks = await db.query(`SELECT * FROM stocks WHERE status != '结束'`)
  const funds = await db.query(`SELECT * FROM funds WHERE status != '结束'`)
  const liabilities = await db.query(`SELECT * FROM liabilities WHERE status = '未结清'`)

  const liquidAccounts = accounts.filter((a: any) => a.type !== '信用卡')
  const creditCards = accounts.filter((a: any) => a.type === '信用卡')

  const liquidBalance = liquidAccounts.reduce((s: number, a: any) => s + (a.balance || 0), 0)
  const creditCardUsed = creditCards.reduce((s: number, a: any) => s + (a.used_limit || 0), 0)

  const assetAmount = assets.reduce((s: number, a: any) => s + (a.amount || 0), 0)
  const stockValue = stocks.reduce((s: number, st: any) => s + (st.current_price || 0) * (st.quantity || 0), 0)
  const fundValue = funds.reduce((s: number, f: any) => s + (f.current_nav || 0) * (f.shares || 0), 0)

  const totalAssets = liquidBalance + assetAmount + stockValue + fundValue
  const totalLiabilities = liabilities.reduce((s: number, l: any) => s + (l.remaining_principal || 0), 0) + creditCardUsed
  const netWorth = totalAssets - totalLiabilities

  // 月收入/支出估算（从最近3个月平均）
  const now = new Date()
  const threeMonthsAgo = new Date(now.getFullYear(), now.getMonth() - 3, 1)
  const startStr = `${threeMonthsAgo.getFullYear()}-${String(threeMonthsAgo.getMonth() + 1).padStart(2, '0')}-01`

  const incomes = await db.query(`SELECT amount FROM transactions WHERE type = '账户收入' AND created_at >= ?`, [startStr])
  const expenses = await db.query(`SELECT amount FROM transactions WHERE type = '账户支出' AND created_at >= ?`, [startStr])

  const totalIncome = incomes.reduce((s: number, r: any) => s + (r.amount || 0), 0)
  const totalExpense = expenses.reduce((s: number, r: any) => s + (r.amount || 0), 0)
  const monthlyIncome = totalIncome / 3
  const monthlyExpense = totalExpense / 3

  // 月负债还款
  const monthlyRepayment = liabilities.reduce((s: number, l: any) => {
    if (l.repayment_method === 'equal_principal_and_interest' || l.repayment_method === '等额本息') {
      const rate = (l.interest_rate || 0) / 100 / 12
      const n = l.period || 1
      const p = l.remaining_principal || 0
      if (rate === 0) return s + p / n
      return s + p * rate * Math.pow(1 + rate, n) / (Math.pow(1 + rate, n) - 1)
    }
    return s + (l.monthly_payment || 0)
  }, 0)

  const monthlyCashFlow = monthlyIncome - monthlyExpense - monthlyRepayment

  // 被动收入（资产收益），排除暂停状态的资产
  const passiveIncome = assets.reduce((s: number, a: any) => {
    if (a.status === '暂停') return s
    if (a.income_amount) return s + a.income_amount
    if (a.annual_yield_rate && a.amount) return s + a.amount * (a.annual_yield_rate / 100) / 12
    return s
  }, 0)

  // 负债收入比
  const debtIncomeRatio = monthlyIncome > 0 ? (monthlyRepayment / monthlyIncome) * 100 : 0

  return {
    totalAssets, totalLiabilities, netWorth, liquidBalance,
    monthlyIncome, monthlyExpense, monthlyRepayment, monthlyCashFlow,
    passiveIncome, debtIncomeRatio, stockValue, fundValue, liabilities, assets
  }
}

function getDebtPressureLevel(ratio: number): number {
  if (ratio < 20) return 1
  if (ratio < 30) return 2
  if (ratio < 40) return 3
  return 4
}

function getDebtPressureDesc(level: number): string {
  const map: Record<number, string> = {
    1: '负债压力健康，月现金流充足，可轻松覆盖月供',
    2: '负债压力良好，月供占收入比例合理，不影响正常生活',
    3: '负债压力需注意，月供占比较高，建议控制新增负债',
    4: '负债压力风险，月供占比过高，财务脆弱性较高'
  }
  return map[level] || ''
}

// 等额本息月供计算
function calcMonthlyPayment(principal: number, annualRate: number, months: number): number {
  const r = annualRate / 100 / 12
  if (r === 0) return principal / months
  return principal * r * Math.pow(1 + r, months) / (Math.pow(1 + r, months) - 1)
}

// 总利息计算
function calcTotalInterest(principal: number, annualRate: number, months: number): number {
  const monthly = calcMonthlyPayment(principal, annualRate, months)
  return monthly * months - principal
}

// 核心推演计算引擎
export async function computeSandbox(sceneType: number, params: any): Promise<{ history: SandboxHistory; result: SandboxResult }> {
  const data = await loadUserFinancialData()
  const scene = getSceneByType(sceneType)!
  const now = getCurrentDate()
  const simulateTime = `${now.year()}-${String(now.month() + 1).padStart(2, '0')}-${String(now.date()).padStart(2, '0')} ${String(now.hour()).padStart(2, '0')}:${String(now.minute()).padStart(2, '0')}:${String(now.second()).padStart(2, '0')}`

  let netAssets = data.netWorth
  let cashFlow = data.monthlyCashFlow
  let debtPressureLevel = getDebtPressureLevel(data.debtIncomeRatio)
  let debtPressureDesc = getDebtPressureDesc(debtPressureLevel)
  let survivalMonths: number | null = null
  let interestSave: number | null = null
  let monthlyPaymentChange: number | null = null
  let totalInterestChange: number | null = null
  let chartX: string[] = []
  let chartNetAssets: number[] = []
  let chartCashFlow: number[] = []
  let chartDebt: number[] = []
  let conclusion = ''
  let resultDesc = ''
  let netAssetsChange = ''
  let cashFlowChange = ''

  const months = params.simulate_period || params.increase_period || params.hold_period || params.stable_period || params.supplement_period || 12

  switch (sceneType) {
    case 1: { // 失业维持时长
      const retainPassive = params.retain_passive_income !== false
      const suspendExpense = params.suspend_expense === true
      const monthlySpend = suspendExpense ? data.monthlyExpense * 0.7 + data.monthlyRepayment : data.monthlyExpense + data.monthlyRepayment
      // 失业情景下不计算社保和公积金类型的资产收益
      const monthlyIn = retainPassive ? data.assets.reduce((s: number, a: any) => {
        if (a.status === '暂停') return s
        if (a.type === '社保' || a.type === '公积金') return s
        if (a.income_amount) return s + a.income_amount
        if (a.annual_yield_rate && a.amount) return s + a.amount * (a.annual_yield_rate / 100) / 12
        return s
      }, 0) : 0
      const monthlyGap = monthlyIn - monthlySpend
      survivalMonths = monthlyGap >= 0 ? 999 : Math.floor(data.liquidBalance / Math.abs(monthlyGap))
      if (survivalMonths > 120) survivalMonths = 120

      const actualMonths = Math.min(survivalMonths, 24)
      chartX = Array.from({ length: actualMonths }, (_, i) => `${i + 1}月`)
      chartNetAssets = Array.from({ length: actualMonths }, (_, i) => Math.max(0, data.netWorth + monthlyGap * (i + 1)))
      chartCashFlow = Array.from({ length: actualMonths }, () => monthlyGap)
      chartDebt = Array.from({ length: actualMonths }, (_, i) => {
        const paid = data.liabilities.reduce((s: number, l: any) => s + (l.monthly_payment || 0) * (i + 1), 0)
        return Math.max(0, data.totalLiabilities - paid)
      })

      netAssets = chartNetAssets[chartNetAssets.length - 1]
      cashFlow = monthlyGap
      debtPressureLevel = monthlyGap < -data.monthlyIncome * 0.3 ? 3 : 2
      debtPressureDesc = `失业后月现金流缺口${Math.abs(monthlyGap).toFixed(0)}元，可维持${survivalMonths}个月`
      netAssetsChange = `净资产从${data.netWorth.toFixed(2)}元${monthlyGap < 0 ? '衰减' : '增长'}至${netAssets.toFixed(2)}元`
      cashFlowChange = `月现金流从${data.monthlyCashFlow.toFixed(2)}元变为${monthlyGap.toFixed(2)}元`
      conclusion = `失业后可维持${survivalMonths}个月正常生活。建议提前储备3-6个月应急资金，或暂停非必要支出延长维持时间。`
      resultDesc = `可维持${survivalMonths}个月`
      break
    }

    case 2: { // 债务利率上涨
      const rateIncrease = params.rate_increase || 1
      const oldMonthly = data.monthlyRepayment
      const newMonthly = data.liabilities.reduce((s: number, l: any) => {
        const newRate = (l.interest_rate || 0) + rateIncrease
        const months = l.period || 1
        const principal = l.remaining_principal || 0
        return s + calcMonthlyPayment(principal, newRate, months)
      }, 0)
      monthlyPaymentChange = newMonthly - oldMonthly
      const oldTotalInterest = data.liabilities.reduce((s: number, l: any) => s + calcTotalInterest(l.remaining_principal || 0, l.interest_rate || 0, l.period || 1), 0)
      const newTotalInterest = data.liabilities.reduce((s: number, l: any) => s + calcTotalInterest(l.remaining_principal || 0, (l.interest_rate || 0) + rateIncrease, l.period || 1), 0)
      totalInterestChange = newTotalInterest - oldTotalInterest
      cashFlow = data.monthlyCashFlow - monthlyPaymentChange
      const newRatio = data.monthlyIncome > 0 ? (newMonthly / data.monthlyIncome) * 100 : 0
      debtPressureLevel = getDebtPressureLevel(newRatio)
      debtPressureDesc = `利率上涨${rateIncrease}%后，月供增加${monthlyPaymentChange.toFixed(2)}元，负债收入比升至${newRatio.toFixed(1)}%`

      const maxMonths = Math.max(...data.liabilities.map((l: any) => l.period || 12), 12)
      chartX = Array.from({ length: Math.min(maxMonths, 60) }, (_, i) => `${i + 1}月`)
      chartNetAssets = chartX.map((_, i) => data.netWorth + cashFlow * (i + 1))
      chartCashFlow = chartX.map(() => cashFlow)
      chartDebt = chartX.map((_, i) => {
        const paid = newMonthly * (i + 1)
        return Math.max(0, data.totalLiabilities - paid)
      })
      netAssets = chartNetAssets[chartNetAssets.length - 1]
      netAssetsChange = `净资产从${data.netWorth.toFixed(2)}元变为${netAssets.toFixed(2)}元，因月供增加导致积累放缓`
      cashFlowChange = `月现金流从${data.monthlyCashFlow.toFixed(2)}元减少至${cashFlow.toFixed(2)}元`
      conclusion = `利率上涨${rateIncrease}%后，月供增加${monthlyPaymentChange.toFixed(2)}元，总利息增加${totalInterestChange.toFixed(2)}元。建议优先偿还高利率负债。`
      resultDesc = `月供增加${monthlyPaymentChange.toFixed(0)}元`
      break
    }

    case 3: { // 股票/基金下跌
      const declineRate = params.decline_rate || 20
      const hold = params.hold_quantity !== false
      const investValue = data.stockValue + data.fundValue
      const lossAmount = investValue * declineRate / 100
      netAssets = data.netWorth - lossAmount
      const recoveryRate = declineRate / (1 - declineRate / 100)
      const recoveryMonths = Math.ceil(Math.log(1 + recoveryRate / 100) / Math.log(1 + 0.08 / 12) * 12)

      chartX = ['当前', '1个月后', '3个月后', '6个月后', '12个月后']
      chartNetAssets = [data.netWorth, netAssets, netAssets + lossAmount * 0.1, netAssets + lossAmount * 0.3, netAssets + lossAmount * 0.6]
      chartCashFlow = chartX.map(() => data.monthlyCashFlow)
      chartDebt = chartX.map((_, i) => Math.max(0, data.totalLiabilities - data.monthlyRepayment * i))

      debtPressureLevel = getDebtPressureLevel(data.debtIncomeRatio)
      debtPressureDesc = `投资下跌仅影响净资产，不影响每月现金流和负债还款能力`
      netAssetsChange = `净资产从${data.netWorth.toFixed(2)}元降至${netAssets.toFixed(2)}元，跌幅${(lossAmount / data.netWorth * 100).toFixed(1)}%`
      cashFlowChange = `现金流无变化，仍为每月${data.monthlyCashFlow.toFixed(2)}元`
      conclusion = `投资组合下跌${declineRate}%后，净资产减少${lossAmount.toFixed(2)}元。${hold ? '建议长期持有，预计' + recoveryMonths + '个月后可回本。' : '若已卖出，亏损已锁定。'}`
      resultDesc = `净资产下跌${(lossAmount / data.netWorth * 100).toFixed(0)}%`
      break
    }

    case 4: { // 每月多存
      const deposit = params.monthly_deposit || 1500
      const period = params.simulate_period || 36
      const interestRate = 0.02 / 12
      let accumulated = 0
      chartX = Array.from({ length: period }, (_, i) => `${i + 1}月`)
      chartNetAssets = chartX.map((_, i) => {
        accumulated = accumulated * (1 + interestRate) + deposit
        return data.netWorth + accumulated
      })
      chartCashFlow = chartX.map(() => data.monthlyCashFlow - deposit)
      chartDebt = chartX.map((_, i) => Math.max(0, data.totalLiabilities - data.monthlyRepayment * (i + 1)))
      netAssets = chartNetAssets[chartNetAssets.length - 1]
      cashFlow = data.monthlyCashFlow - deposit
      const newRatio = data.monthlyIncome > 0 ? (data.monthlyRepayment / data.monthlyIncome) * 100 : 0
      debtPressureLevel = getDebtPressureLevel(newRatio)
      debtPressureDesc = `每月增存${deposit}元后，月现金流${cashFlow >= 0 ? '仍有' + cashFlow.toFixed(0) + '元结余' : '出现缺口'}`
      netAssetsChange = `净资产从${data.netWorth.toFixed(2)}元增长至${netAssets.toFixed(2)}元，累计增存${accumulated.toFixed(2)}元`
      cashFlowChange = `月现金流从${data.monthlyCashFlow.toFixed(2)}元减少至${cashFlow.toFixed(2)}元`
      conclusion = `每月增存${deposit}元，${period}个月后净资产增长至${netAssets.toFixed(2)}元。建议坚持执行，优先补足应急金。`
      resultDesc = `${period}个月后净资产${netAssets.toFixed(0)}元`
      break
    }

    case 5: { // 提前还清负债
      const repayAmount = params.repay_amount || 30000
      const actualRepay = Math.min(repayAmount, data.totalLiabilities, data.liquidBalance)
      const repayRatio = actualRepay / data.totalLiabilities
      const oldMonthly = data.monthlyRepayment
      const newMonthly = oldMonthly * (1 - repayRatio)
      monthlyPaymentChange = newMonthly - oldMonthly
      const remainingPrincipal = data.totalLiabilities - actualRepay
      const oldInterest = data.liabilities.reduce((s: number, l: any) => s + calcTotalInterest(l.remaining_principal || 0, l.interest_rate || 0, l.period || 1), 0)
      const newInterest = data.liabilities.reduce((s: number, l: any) => s + calcTotalInterest((l.remaining_principal || 0) * (1 - repayRatio), l.interest_rate || 0, l.period || 1), 0)
      interestSave = oldInterest - newInterest
      netAssets = data.netWorth - actualRepay
      cashFlow = data.monthlyCashFlow - monthlyPaymentChange
      const newRatio = data.monthlyIncome > 0 ? (newMonthly / data.monthlyIncome) * 100 : 0
      debtPressureLevel = getDebtPressureLevel(newRatio)
      debtPressureDesc = `提前还款${actualRepay.toFixed(2)}元后，月供减少${Math.abs(monthlyPaymentChange).toFixed(2)}元`

      chartX = ['还款前', '还款当月', '3个月后', '6个月后', '12个月后']
      chartNetAssets = [data.netWorth, netAssets, netAssets + cashFlow * 3, netAssets + cashFlow * 6, netAssets + cashFlow * 12]
      chartCashFlow = [data.monthlyCashFlow, cashFlow, cashFlow, cashFlow, cashFlow]
      chartDebt = [data.totalLiabilities, remainingPrincipal, Math.max(0, remainingPrincipal - newMonthly * 3), Math.max(0, remainingPrincipal - newMonthly * 6), Math.max(0, remainingPrincipal - newMonthly * 12)]

      netAssetsChange = `净资产从${data.netWorth.toFixed(2)}元降至${netAssets.toFixed(2)}元，节省利息${(interestSave || 0).toFixed(2)}元`
      cashFlowChange = `月现金流从${data.monthlyCashFlow.toFixed(2)}元增至${cashFlow.toFixed(2)}元`
      conclusion = `提前还款${actualRepay.toFixed(2)}元，节省总利息${(interestSave || 0).toFixed(2)}元，月供减少${Math.abs(monthlyPaymentChange).toFixed(2)}元。建议执行。`
      resultDesc = `节省利息${(interestSave || 0).toFixed(0)}元`
      break
    }

    case 6: { // 收入上涨
      const riseRate = params.rise_rate || 15
      const period = params.simulate_period || 24
      const incomeIncrease = data.monthlyIncome * riseRate / 100
      cashFlow = data.monthlyCashFlow + incomeIncrease
      const newRatio = data.monthlyIncome > 0 ? (data.monthlyRepayment / (data.monthlyIncome + incomeIncrease)) * 100 : 0
      debtPressureLevel = getDebtPressureLevel(newRatio)
      debtPressureDesc = `收入上涨${riseRate}%后，月现金流增至${cashFlow.toFixed(2)}元，负债收入比降至${newRatio.toFixed(1)}%`

      chartX = Array.from({ length: period }, (_, i) => `${i + 1}月`)
      chartNetAssets = chartX.map((_, i) => data.netWorth + cashFlow * (i + 1))
      chartCashFlow = chartX.map(() => cashFlow)
      chartDebt = chartX.map((_, i) => Math.max(0, data.totalLiabilities - data.monthlyRepayment * (i + 1)))
      netAssets = chartNetAssets[chartNetAssets.length - 1]
      netAssetsChange = `净资产从${data.netWorth.toFixed(2)}元增长至${netAssets.toFixed(2)}元，增长率${((netAssets - data.netWorth) / data.netWorth * 100).toFixed(1)}%`
      cashFlowChange = `月现金流从${data.monthlyCashFlow.toFixed(2)}元增加至${cashFlow.toFixed(2)}元`
      conclusion = `收入上涨${riseRate}%后，月现金流增加${incomeIncrease.toFixed(2)}元，${period}个月后净资产增至${netAssets.toFixed(2)}元。建议用于增存或提前还款。`
      resultDesc = `${period}个月后净资产${netAssets.toFixed(0)}元`
      break
    }

    case 7: { // 大额一次性支出
      const expense = params.expense_amount || 20000
      const source = params.fund_source || 'current_assets'
      let newDebtMonthly = 0
      if (source === 'debt') {
        newDebtMonthly = calcMonthlyPayment(expense, 8, 24)
        monthlyPaymentChange = newDebtMonthly
        totalInterestChange = calcTotalInterest(expense, 8, 24)
      }
      netAssets = source === 'debt' ? data.netWorth : data.netWorth - expense
      cashFlow = data.monthlyCashFlow - newDebtMonthly
      const newRatio = data.monthlyIncome > 0 ? ((data.monthlyRepayment + newDebtMonthly) / data.monthlyIncome) * 100 : 0
      debtPressureLevel = getDebtPressureLevel(newRatio)
      debtPressureDesc = source === 'debt' ? `新增负债${expense}元，月供增加${newDebtMonthly.toFixed(2)}元` : `支出${expense}元，未新增负债`

      chartX = ['支出前', '支出当月', '3个月后', '6个月后', '12个月后']
      chartNetAssets = [data.netWorth, netAssets, netAssets + cashFlow * 3, netAssets + cashFlow * 6, netAssets + cashFlow * 12]
      chartCashFlow = [data.monthlyCashFlow, cashFlow, cashFlow, cashFlow, cashFlow]
      chartDebt = source === 'debt'
        ? [data.totalLiabilities, data.totalLiabilities + expense, data.totalLiabilities + expense - (data.monthlyRepayment + newDebtMonthly) * 3, data.totalLiabilities + expense - (data.monthlyRepayment + newDebtMonthly) * 6, data.totalLiabilities + expense - (data.monthlyRepayment + newDebtMonthly) * 12]
        : [data.totalLiabilities, data.totalLiabilities, Math.max(0, data.totalLiabilities - data.monthlyRepayment * 3), Math.max(0, data.totalLiabilities - data.monthlyRepayment * 6), Math.max(0, data.totalLiabilities - data.monthlyRepayment * 12)]
      chartDebt = chartDebt.map(v => Math.max(0, v))

      netAssetsChange = `净资产从${data.netWorth.toFixed(2)}元变为${netAssets.toFixed(2)}元`
      cashFlowChange = source === 'debt' ? `月现金流从${data.monthlyCashFlow.toFixed(2)}元减少至${cashFlow.toFixed(2)}元` : `现金流无变化`
      conclusion = `${source === 'debt' ? '新增负债' : '使用流动资产'}支付${expense}元后，净资产${netAssets.toFixed(2)}元。${source === 'debt' ? '建议评估新增负债必要性。' : '建议后续补充流动资产。'}`
      resultDesc = `净资产变为${netAssets.toFixed(0)}元`
      break
    }

    case 8: { // 收入下降
      const declineRate = params.decline_rate || 20
      const period = params.simulate_period || 12
      const incomeDecrease = data.monthlyIncome * declineRate / 100
      cashFlow = data.monthlyCashFlow - incomeDecrease
      const newRatio = data.monthlyIncome > 0 ? (data.monthlyRepayment / Math.max(1, data.monthlyIncome - incomeDecrease)) * 100 : 0
      debtPressureLevel = getDebtPressureLevel(newRatio)
      debtPressureDesc = `收入下降${declineRate}%后，月现金流降至${cashFlow.toFixed(2)}元，负债收入比升至${newRatio.toFixed(1)}%`

      chartX = Array.from({ length: period }, (_, i) => `${i + 1}月`)
      chartNetAssets = chartX.map((_, i) => data.netWorth + cashFlow * (i + 1))
      chartCashFlow = chartX.map(() => cashFlow)
      chartDebt = chartX.map((_, i) => Math.max(0, data.totalLiabilities - data.monthlyRepayment * (i + 1)))
      netAssets = chartNetAssets[chartNetAssets.length - 1]
      netAssetsChange = `净资产从${data.netWorth.toFixed(2)}元变为${netAssets.toFixed(2)}元`
      cashFlowChange = `月现金流从${data.monthlyCashFlow.toFixed(2)}元减少至${cashFlow.toFixed(2)}元`
      conclusion = `收入下降${declineRate}%后，月现金流减少${incomeDecrease.toFixed(2)}元。建议暂停非必要支出，寻找兼职增加收入。`
      resultDesc = `月现金流降至${cashFlow.toFixed(0)}元`
      break
    }

    case 9: { // 投资变现
      const ratio = params.sell_ratio || 50
      const use = params.fund_use || 'debt_repay'
      const sellValue = (data.stockValue + data.fundValue) * ratio / 100
      const fee = sellValue * 0.005
      const netSell = sellValue - fee
      let debtReduction = 0
      if (use === 'debt_repay') {
        debtReduction = Math.min(netSell, data.totalLiabilities)
        const oldMonthly = data.monthlyRepayment
        const newMonthly = oldMonthly * (1 - debtReduction / Math.max(data.totalLiabilities, 1))
        monthlyPaymentChange = newMonthly - oldMonthly
        interestSave = data.liabilities.reduce((s: number, l: any) => {
          const pr = (l.remaining_principal || 0)
          const repaid = pr * (debtReduction / Math.max(data.totalLiabilities, 1))
          return s + calcTotalInterest(pr, l.interest_rate || 0, l.period || 1) - calcTotalInterest(Math.max(0, pr - repaid), l.interest_rate || 0, l.period || 1)
        }, 0)
      }
      netAssets = data.netWorth - fee - (use === 'debt_repay' ? 0 : netSell)
      if (use === 'current_assets') netAssets = data.netWorth - fee
      cashFlow = data.monthlyCashFlow - (monthlyPaymentChange || 0)
      const newRatio = data.monthlyIncome > 0 ? ((data.monthlyRepayment + (monthlyPaymentChange || 0)) / data.monthlyIncome) * 100 : 0
      debtPressureLevel = getDebtPressureLevel(newRatio)
      debtPressureDesc = `变现${ratio}%投资后，${use === 'debt_repay' ? '月供减少' + Math.abs(monthlyPaymentChange || 0).toFixed(2) + '元' : '补充流动资产' + netSell.toFixed(2) + '元'}`

      chartX = ['变现前', '变现当月', '3个月后', '6个月后', '12个月后']
      chartNetAssets = [data.netWorth, netAssets, netAssets + cashFlow * 3, netAssets + cashFlow * 6, netAssets + cashFlow * 12]
      chartCashFlow = [data.monthlyCashFlow, cashFlow, cashFlow, cashFlow, cashFlow]
      chartDebt = [data.totalLiabilities, Math.max(0, data.totalLiabilities - debtReduction), Math.max(0, data.totalLiabilities - debtReduction - data.monthlyRepayment * 3), Math.max(0, data.totalLiabilities - debtReduction - data.monthlyRepayment * 6), Math.max(0, data.totalLiabilities - debtReduction - data.monthlyRepayment * 12)]

      netAssetsChange = `净资产从${data.netWorth.toFixed(2)}元变为${netAssets.toFixed(2)}元，手续费${fee.toFixed(2)}元`
      cashFlowChange = `月现金流从${data.monthlyCashFlow.toFixed(2)}元变为${cashFlow.toFixed(2)}元`
      conclusion = `变现${ratio}%投资，${use === 'debt_repay' ? '偿还负债可节省利息' + (interestSave || 0).toFixed(2) + '元' : '补充流动资产'}。建议权衡投资收益与负债成本。`
      resultDesc = use === 'debt_repay' ? `节省利息${(interestSave || 0).toFixed(0)}元` : `变现${netSell.toFixed(0)}元`
      break
    }

    case 10: { // 新增负债
      const debtAmount = params.debt_amount || 30000
      const rate = params.annual_rate || 8
      const period = params.repay_period || 24
      const newMonthly = calcMonthlyPayment(debtAmount, rate, period)
      monthlyPaymentChange = newMonthly
      totalInterestChange = calcTotalInterest(debtAmount, rate, period)
      cashFlow = data.monthlyCashFlow - newMonthly
      const newRatio = data.monthlyIncome > 0 ? ((data.monthlyRepayment + newMonthly) / data.monthlyIncome) * 100 : 0
      debtPressureLevel = getDebtPressureLevel(newRatio)
      debtPressureDesc = `新增负债${debtAmount}元后，月供增加${newMonthly.toFixed(2)}元，负债收入比升至${newRatio.toFixed(1)}%`
      netAssets = data.netWorth

      chartX = ['新增前', '新增当月', '3个月后', '6个月后', '12个月后', `${period}个月后`]
      chartNetAssets = chartX.map((_, i) => data.netWorth + cashFlow * i)
      chartCashFlow = chartX.map(() => cashFlow)
      chartDebt = [data.totalLiabilities, data.totalLiabilities + debtAmount, data.totalLiabilities + debtAmount - newMonthly * 3, data.totalLiabilities + debtAmount - newMonthly * 6, data.totalLiabilities + debtAmount - newMonthly * 12, Math.max(0, data.totalLiabilities + debtAmount - newMonthly * period)]

      netAssetsChange = `净资产无变化，仍为${data.netWorth.toFixed(2)}元`
      cashFlowChange = `月现金流从${data.monthlyCashFlow.toFixed(2)}元减少至${cashFlow.toFixed(2)}元`
      conclusion = `新增${debtAmount}元负债，月供增加${newMonthly.toFixed(2)}元，总利息${totalInterestChange.toFixed(2)}元。建议确认资金用途必要性。`
      resultDesc = `月供增加${newMonthly.toFixed(0)}元`
      break
    }

    case 11: { // 应急金不足
      const targetMonths = params.target_months || 6
      const supplementPeriod = params.supplement_period || 12
      const targetAmount = data.monthlyExpense * targetMonths
      const currentEmergency = data.liquidBalance
      const shortage = Math.max(0, targetAmount - currentEmergency)
      const monthlySupplement = shortage / supplementPeriod
      cashFlow = data.monthlyCashFlow - monthlySupplement

      chartX = ['补充前', '1月', '2月', '3月', '6月', '9月', `${supplementPeriod}月(完成)`]
      chartNetAssets = chartX.map(() => data.netWorth)
      chartCashFlow = chartX.map((_, i) => i === 0 ? data.monthlyCashFlow : (i === chartX.length - 1 ? data.monthlyCashFlow : cashFlow))
      chartDebt = chartX.map((_, i) => Math.max(0, data.totalLiabilities - data.monthlyRepayment * i))
      debtPressureLevel = getDebtPressureLevel(data.debtIncomeRatio)
      debtPressureDesc = `每月补充${monthlySupplement.toFixed(2)}元，${supplementPeriod}个月后应急金达标`
      netAssets = data.netWorth
      netAssetsChange = `净资产无变化，仍为${data.netWorth.toFixed(2)}元`
      cashFlowChange = `补充期间月现金流从${data.monthlyCashFlow.toFixed(2)}元降至${cashFlow.toFixed(2)}元，完成后恢复`
      conclusion = `应急金缺口${shortage.toFixed(2)}元，每月补充${monthlySupplement.toFixed(2)}元，${supplementPeriod}个月后可达标。建议严格执行。`
      resultDesc = `缺口${shortage.toFixed(0)}元，${supplementPeriod}个月补齐`
      break
    }

    case 12: { // 投资亏损
      const lossRate = params.loss_rate || 15
      const holdPeriod = params.hold_period || 6
      const investValue = data.stockValue + data.fundValue
      const lossAmount = investValue * lossRate / 100
      netAssets = data.netWorth - lossAmount
      const monthlyRecovery = investValue * 0.005

      chartX = ['亏损前', '亏损当月', '1个月后', '3个月后', '6个月后']
      chartNetAssets = [data.netWorth, netAssets, netAssets + monthlyRecovery, netAssets + monthlyRecovery * 3, netAssets + monthlyRecovery * 6]
      chartCashFlow = chartX.map(() => data.monthlyCashFlow)
      chartDebt = chartX.map((_, i) => Math.max(0, data.totalLiabilities - data.monthlyRepayment * i))
      debtPressureLevel = getDebtPressureLevel(data.debtIncomeRatio)
      debtPressureDesc = `投资亏损${lossAmount.toFixed(2)}元，不影响现金流和负债还款`
      netAssetsChange = `净资产从${data.netWorth.toFixed(2)}元降至${netAssets.toFixed(2)}元，亏损${(lossRate).toFixed(0)}%`
      cashFlowChange = `现金流无变化，仍为每月${data.monthlyCashFlow.toFixed(2)}元`
      conclusion = `投资亏损${lossRate}%后，净资产减少${lossAmount.toFixed(2)}元。建议保持持有观察，等待回升。`
      resultDesc = `净资产下跌${lossRate}%`
      break
    }

    case 13: { // 固定支出增加
      const increase = params.increase_amount || 500
      const period = params.increase_period || 12
      cashFlow = data.monthlyCashFlow - increase
      const newRatio = data.monthlyIncome > 0 ? (data.monthlyRepayment / data.monthlyIncome) * 100 : 0
      debtPressureLevel = getDebtPressureLevel(newRatio)
      debtPressureDesc = `固定支出每月增加${increase}元，月现金流降至${cashFlow.toFixed(2)}元`

      chartX = ['增加前', '1月', '2月', '3月', '6月', '9月', `${period}月(恢复)`]
      chartNetAssets = chartX.map((_, i) => data.netWorth + (i === 0 ? 0 : cashFlow * Math.min(i, period)))
      chartCashFlow = chartX.map((_, i) => i === 0 ? data.monthlyCashFlow : (i === chartX.length - 1 ? data.monthlyCashFlow : cashFlow))
      chartDebt = chartX.map((_, i) => Math.max(0, data.totalLiabilities - data.monthlyRepayment * i))
      netAssets = chartNetAssets[chartNetAssets.length - 2]
      netAssetsChange = `固定支出增加期间，净资产从${data.netWorth.toFixed(2)}元变为${netAssets.toFixed(2)}元`
      cashFlowChange = `支出增加期间月现金流从${data.monthlyCashFlow.toFixed(2)}元降至${cashFlow.toFixed(2)}元，${period}个月后恢复`
      conclusion = `固定支出每月增加${increase}元，持续${period}个月。建议适当减少非必要支出弥补缺口。`
      resultDesc = `${period}个月后净资产${netAssets.toFixed(0)}元`
      break
    }

    case 14: { // 被动收入增加
      const increase = params.increase_amount || 800
      const period = params.stable_period || 24
      cashFlow = data.monthlyCashFlow + increase
      const newRatio = data.monthlyIncome > 0 ? (data.monthlyRepayment / (data.monthlyIncome + increase)) * 100 : 0
      debtPressureLevel = getDebtPressureLevel(newRatio)
      debtPressureDesc = `被动收入每月增加${increase}元，月现金流增至${cashFlow.toFixed(2)}元，负债收入比降至${newRatio.toFixed(1)}%`

      chartX = Array.from({ length: Math.min(period, 36) }, (_, i) => `${i + 1}月`)
      chartNetAssets = chartX.map((_, i) => data.netWorth + cashFlow * (i + 1))
      chartCashFlow = chartX.map(() => cashFlow)
      chartDebt = chartX.map((_, i) => Math.max(0, data.totalLiabilities - data.monthlyRepayment * (i + 1)))
      netAssets = chartNetAssets[chartNetAssets.length - 1]
      netAssetsChange = `净资产从${data.netWorth.toFixed(2)}元增长至${netAssets.toFixed(2)}元，增幅${((netAssets - data.netWorth) / Math.max(data.netWorth, 1) * 100).toFixed(1)}%`
      cashFlowChange = `月现金流从${data.monthlyCashFlow.toFixed(2)}元增加至${cashFlow.toFixed(2)}元`
      conclusion = `被动收入每月增加${increase}元，${period}个月后净资产增至${netAssets.toFixed(2)}元。建议用于提前还款或增投。`
      resultDesc = `${period}个月后净资产${netAssets.toFixed(0)}元`
      break
    }
  }

  const history: SandboxHistory = {
    id: getCurrentDate().valueOf().toString() + '-' + sceneType,
    scene_type: sceneType,
    scene_name: scene.name,
    simulate_time: simulateTime,
    params: JSON.stringify(params),
    result_desc: resultDesc,
    created_at: simulateTime,
    is_deleted: 0
  }

  const result: SandboxResult = {
    id: history.id + '-result',
    history_id: history.id || now.format('YYYYMMDDHHmmss') + '-' + sceneType,
    net_assets: Number(netAssets.toFixed(2)),
    net_assets_change: netAssetsChange,
    cash_flow_monthly: Number(cashFlow.toFixed(2)),
    cash_flow_change: cashFlowChange,
    debt_pressure_level: debtPressureLevel,
    debt_pressure_desc: debtPressureDesc,
    survival_months: survivalMonths,
    interest_save: interestSave !== null ? Number(interestSave.toFixed(2)) : null,
    monthly_payment_change: monthlyPaymentChange !== null ? Number(monthlyPaymentChange.toFixed(2)) : null,
    total_interest_change: totalInterestChange !== null ? Number(totalInterestChange.toFixed(2)) : null,
    chart_x: JSON.stringify(chartX),
    chart_net_assets: JSON.stringify(chartNetAssets.map((v: number) => Number(v.toFixed(2)))),
    chart_cash_flow: JSON.stringify(chartCashFlow.map((v: number) => Number(v.toFixed(2)))),
    chart_debt: JSON.stringify(chartDebt.map((v: number) => Number(v.toFixed(2)))),
    conclusion,
    created_at: simulateTime
  }

  return { history, result }
}

export async function saveSandboxSimulation(sceneType: number, params: any): Promise<string | number> {
  const { history, result } = await computeSandbox(sceneType, params)

  const statements = [
      {
        statement: `INSERT INTO sandbox_history (id, scene_type, scene_name, simulate_time, params, result_desc, created_at, is_deleted)
            VALUES (?,?, ?, ?, ?, ?, ?, ?)`,
        values: [history.id, history.scene_type, history.scene_name, history.simulate_time, history.params, history.result_desc, history.created_at, history.is_deleted]
      },
      {
        statement: `INSERT INTO sandbox_result (id, history_id, net_assets, net_assets_change, cash_flow_monthly, cash_flow_change,
            debt_pressure_level, debt_pressure_desc, survival_months, interest_save, monthly_payment_change,
            total_interest_change, chart_x, chart_net_assets, chart_cash_flow, chart_debt, conclusion, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        values: [result.id, result.history_id, result.net_assets, result.net_assets_change, result.cash_flow_monthly, result.cash_flow_change,
            result.debt_pressure_level, result.debt_pressure_desc, result.survival_months, result.interest_save,
            result.monthly_payment_change, result.total_interest_change, result.chart_x, result.chart_net_assets,
            result.chart_cash_flow, result.chart_debt, result.conclusion, result.created_at]
      }
    ]

  await db.executeTransaction(statements)
  return history.id
}
