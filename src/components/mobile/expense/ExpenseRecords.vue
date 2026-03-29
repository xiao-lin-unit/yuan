<template>
  <div class="expense-records">
    <DailyExpense 
      v-for="day in days" 
      :key="day.date"
      :date="day.date"
      :total-expense="day.totalExpense"
      :expenses="day.expenses"
    />
  </div>
</template>

<script setup lang="ts">
import DailyExpense from './DailyExpense.vue';

// 模拟本月的日期数据（倒序）
const days = [
  {
    date: '03.28 今天',
    totalExpense: 76.50,
    expenses: [
      { category: '交通', amount: 62.00, method: '花呗' },
      { category: '交通', amount: 10.00, method: '微信零钱通' },
      { category: '三餐', amount: 4.50, method: '花呗' }
    ]
  },
  {
    date: '03.27 昨天',
    totalExpense: 362.00,
    expenses: [
      { category: '发红包', amount: 300.00, method: '中国银行', note: '随份子' },
      { category: '购物', amount: 62.00, method: '支付宝' }
    ]
  },
  {
    date: '03.26 前天',
    totalExpense: 0,
    expenses: []
  },
  {
    date: '03.25',
    totalExpense: 128.50,
    expenses: [
      { category: '餐饮', amount: 88.50, method: '微信' },
      { category: '交通', amount: 40.00, method: '支付宝' }
    ]
  },
  {
    date: '03.24',
    totalExpense: 0,
    expenses: []
  },
  {
    date: '03.23',
    totalExpense: 95.00,
    expenses: [
      { category: '购物', amount: 95.00, method: '信用卡' }
    ]
  },
  {
    date: '03.22',
    totalExpense: 0,
    expenses: []
  },
  {
    date: '03.21',
    totalExpense: 210.00,
    expenses: [
      { category: '娱乐', amount: 210.00, method: '微信' }
    ]
  },
  {
    date: '03.20',
    totalExpense: 0,
    expenses: []
  },
  {
    date: '03.19',
    totalExpense: 150.00,
    expenses: [
      { category: '餐饮', amount: 150.00, method: '支付宝' }
    ]
  },
  {
    date: '03.18',
    totalExpense: 0,
    expenses: []
  },
  {
    date: '03.17',
    totalExpense: 85.00,
    expenses: [
      { category: '交通', amount: 85.00, method: '微信' }
    ]
  },
  {
    date: '03.16',
    totalExpense: 0,
    expenses: []
  },
  {
    date: '03.15',
    totalExpense: 320.00,
    expenses: [
      { category: '购物', amount: 320.00, method: '信用卡' }
    ]
  },
  {
    date: '03.14',
    totalExpense: 0,
    expenses: []
  },
  {
    date: '03.13',
    totalExpense: 180.00,
    expenses: [
      { category: '餐饮', amount: 180.00, method: '支付宝' }
    ]
  },
  {
    date: '03.12',
    totalExpense: 0,
    expenses: []
  },
  {
    date: '03.11',
    totalExpense: 120.00,
    expenses: [
      { category: '交通', amount: 120.00, method: '微信' }
    ]
  },
  {
    date: '03.10',
    totalExpense: 0,
    expenses: []
  },
  {
    date: '03.09',
    totalExpense: 250.00,
    expenses: [
      { category: '娱乐', amount: 250.00, method: '支付宝' }
    ]
  },
  {
    date: '03.08',
    totalExpense: 0,
    expenses: []
  },
  {
    date: '03.07',
    totalExpense: 160.00,
    expenses: [
      { category: '购物', amount: 160.00, method: '信用卡' }
    ]
  },
  {
    date: '03.06',
    totalExpense: 0,
    expenses: []
  },
  {
    date: '03.05',
    totalExpense: 90.00,
    expenses: [
      { category: '餐饮', amount: 90.00, method: '微信' }
    ]
  },
  {
    date: '03.04',
    totalExpense: 0,
    expenses: []
  },
  {
    date: '03.03',
    totalExpense: 130.00,
    expenses: [
      { category: '交通', amount: 130.00, method: '支付宝' }
    ]
  },
  {
    date: '03.02',
    totalExpense: 0,
    expenses: []
  },
  {
    date: '03.01',
    totalExpense: 200.00,
    expenses: [
      { category: '购物', amount: 200.00, method: '信用卡' }
    ]
  }
];
</script>

<style scoped>
.expense-records {
  margin: 0 0 20px 0;
  padding: 0 15px;
}
</style>