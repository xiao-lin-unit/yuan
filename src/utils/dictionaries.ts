/**
 * 字典管理文件
 * 集中管理项目中使用的所有字典数据
 */

// ==================== 账户相关 ====================

// 账户类型（完整列表，含信用卡）
export const accountTypes = [
  { label: '现金', value: '现金' },
  { label: '微信', value: '微信' },
  { label: '支付宝', value: '支付宝' },
  { label: '储蓄卡', value: '储蓄卡' },
  { label: '社保卡', value: '社保卡' },
  { label: '公积金', value: '公积金' },
  { label: '信用卡', value: '信用卡' }
]

// 余额调整类型
export const adjustmentTypes = [
  { label: '修正错误', value: '修正错误' },
  { label: '现金赠与', value: '现金赠与' },
  { label: '资产盘盈', value: '资产盘盈' }
]

// ==================== 资产相关 ====================

// 普通资产类型
export const assetTypes = [
  { label: '储蓄', value: '储蓄' },
  { label: '利息', value: '利息' },
  { label: '租金', value: '租金' },
  { label: '版权', value: '版权' },
  { label: '社保', value: '社保' },
  { label: '公积金', value: '公积金' }
]

// 收益周期类型
export const periodTypes = [
  { label: '每年', value: '年', num: 1 },
  { label: '每月', value: '月', num: 12 },
  { label: '每日', value: '日', num: 365 }
]

// 收益计算类型
export const calculationTypes = [
  { label: '按金额计算', value: '按金额计算' },
  { label: '按年收益率计算', value: '按年收益率计算' }
]

// ==================== 基金/股票交易相关 ====================

// 交易类型（基金/股票买卖）
export const transactionTypes = [
  { label: '买入', value: '买入' },
  { label: '卖出', value: '卖出' }
]

// ==================== 负债相关 ====================

// 负债类型
export const liabilityTypes = [
  { label: '房贷', value: '房贷' },
  { label: '车贷', value: '车贷' },
  { label: '信用卡', value: '信用卡' },
  { label: '消费贷', value: '消费贷' },
  { label: '装修贷', value: '装修贷' },
  { label: '助学贷款', value: '助学贷款' },
  { label: '网贷', value: '网贷' },
  { label: '电商分期', value: '电商分期' },
  { label: '租金分期', value: '租金分期' },
  { label: '亲友借款', value: '亲友借款' },
  { label: '经营贷', value: '经营贷' },
  { label: '其他负债', value: '其他负债' }
]

// 还款方式
export const repaymentMethods = [
  { label: '等额本息', value: '等额本息' },
  { label: '等额本金', value: '等额本金' },
  { label: '随借随还', value: '随借随还' }
]

// 负债状态
export const liabilityStatuses = [
  { label: '未结清', value: '未结清' },
  { label: '已结清', value: '已结清' }
]

// 还款类型
export const repaymentTypes = [
  { label: '正常还款', value: '正常还款' },
  { label: '提前还款', value: '提前还款' }
]

// ==================== 财务目标相关 ====================

// 财务目标类型
export const goalTypes = [
  { label: '储蓄类', value: '储蓄类' },
  { label: '还款类', value: '还款类' },
  { label: '投资类', value: '投资类' },
  { label: '应急金类', value: '应急金类' }
]

// 财务目标状态
export const goalStatuses = [
  { label: '未开始', value: '未开始' },
  { label: '进行中', value: '进行中' },
  { label: '已完成', value: '已完成' },
  { label: '已终止', value: '已终止' }
]
