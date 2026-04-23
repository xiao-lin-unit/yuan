/**
 * Financial goal type definitions
 */
import type dayjs from 'dayjs'

// Base financial goal interface
export interface FinancialGoal {
  id: string
  name: string
  type: string
  target_amount: number
  monthly_amount: number
  period: number
  account_id: string
  status: '未开始' | '进行中' | '已完成' | '已终止'
  created_at?: dayjs.Dayjs | string
  updated_at?: dayjs.Dayjs | string
}

// Goal investment record
export interface GoalInvestment {
  id: string
  goal_id: string
  amount: number
  invest_date: dayjs.Dayjs | string
  remark?: string
  created_at?: dayjs.Dayjs | string
}

// Input for adding a new goal
export interface GoalInput {
  name: string
  type: string
  target_amount: number
  period: number
  monthly_amount: number
  account_id: string
}

// Input for goal investment
export interface GoalInvestInput {
  goalId: string
  amount: number
  date: dayjs.Dayjs
  remark?: string
}
