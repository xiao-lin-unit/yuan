<template>
  <PageTemplate 
    title="新增普通资产"
    show-confirm-button
    confirm-text="确认添加"
    @back="goBack"
    @confirm="addAsset"
  >
    <div class="form-container">
      <el-form :model="assetForm" label-width="80px">
        <el-form-item label="资产名称" required>
          <el-input v-model="assetForm.name" placeholder="请输入资产名称" />
        </el-form-item>
        <el-form-item label="资产类型" required>
          <el-select v-model="assetForm.type" placeholder="请选择资产类型">
            <el-option v-for="item in assetTypes" :key="item.value" :label="item.label" :value="item.value" />
          </el-select>
        </el-form-item>
        <el-form-item label="金额" required>
          <el-input v-model.number="assetForm.amount" placeholder="请输入金额" type="number" min="0" step="0.01" />
        </el-form-item>
        <el-form-item label="关联账户" required>
          <el-select v-model="assetForm.account_id" placeholder="请选择关联账户">
            <el-option
              v-for="account in filteredAccounts"
              :key="account.id"
              :label="account.name"
              :value="account.id"
            />
          </el-select>
        </el-form-item>
        <el-form-item label="账户扣款">
          <el-switch v-model="assetForm.deduct_from_account" active-text="是" inactive-text="否" />
        </el-form-item>
        <el-form-item label="计算类型" required>
          <el-select v-model="assetForm.calculation_type" placeholder="请选择计算类型">
            <el-option v-for="item in calculationTypes" :key="item.value" :label="item.label" :value="item.value" />
          </el-select>
        </el-form-item>
        <el-form-item label="每期收益" required v-if="assetForm.calculation_type === '按金额计算'">
          <el-input v-model.number="assetForm.income_amount" placeholder="请输入每期收益金额" type="number" min="0" step="0.01" />
        </el-form-item>
        <el-form-item label="年收益率" required v-if="assetForm.calculation_type === '按年收益率计算'">
          <el-input v-model.number="assetForm.annual_yield_rate" placeholder="请输入年收益率" type="number" min="0" step="0.0001" />
        </el-form-item>
        <template v-if="assetForm.calculation_type && assetForm.calculation_type !== '无'">
          <el-form-item label="收益周期" required>
            <el-select v-model="assetForm.period" placeholder="请选择周期">
              <el-option v-for="item in periodTypes" :key="item.value" :label="item.label" :value="item.value" />
            </el-select>
          </el-form-item>
          <el-form-item label="收益日" v-if="assetForm.period && assetForm.period !== '日'">
            <div v-if="assetForm.period === '年'" class="income-date-year">
              <el-select v-model="assetForm.income_month" placeholder="月" style="width: 45%; margin-right: 5px;">
                <el-option
                  v-for="m in 12"
                  :key="m"
                  :label="`${m}月`"
                  :value="m"
                />
              </el-select>
              <el-select v-model="assetForm.income_day" placeholder="日" style="width: 45%;">
                <el-option
                  v-for="d in 31"
                  :key="d"
                  :label="`${d}日`"
                  :value="d"
                />
              </el-select>
            </div>
            <el-select v-else-if="assetForm.period === '月'" v-model="assetForm.income_day" placeholder="请选择日期" style="width: 100%;">
              <el-option
                v-for="d in 31"
                :key="d"
                :label="`${d}日`"
                :value="d"
              />
            </el-select>
          </el-form-item>
          <el-form-item label="周期数量" v-if="assetForm.period">
            <el-input
              v-model.number="assetForm.period_count"
              placeholder="请输入周期数量"
              type="number"
              min="1"
              step="1"
            >
              <template #append>{{ assetForm.period }}</template>
            </el-input>
          </el-form-item>
        </template>
      </el-form>
    </div>
  </PageTemplate>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import PageTemplate from '../../common/PageTemplate.vue'
import { assetTypes, periodTypes, calculationTypes } from '../../../utils/dictionaries'
import { addAsset as addAssetService } from '../../../services/asset/assetService'
import { getNonCreditCardAccounts } from '../../../services/account/accountService'

const emit = defineEmits(['navigate'])

// 账户数据
const accounts = ref([])

// 表单数据
const assetForm = ref({
  id: '',
  name: '',
  type: '',
  amount: 0,
  account_id: '',
  calculation_type: '',
  income_amount: 0,
  annual_yield_rate: 0,
  deduct_from_account: true,
  period: '',
  period_count: 1,
  income_month: 0,
  income_day: 0
})

// 过滤后的账户列表
const filteredAccounts = computed(() => {
  if (assetForm.value.type === '公积金') {
    return accounts.value.filter(acc => acc.type === '公积金')
  } else if (assetForm.value.type === '社保') {
    return accounts.value.filter(acc => acc.type === '社保')
  } else {
    return accounts.value.filter(acc => acc.type !== '信用卡')
  }
})

onMounted(async () => {
  await loadAccounts()
})

const loadAccounts = async () => {
  try {
    accounts.value = await getNonCreditCardAccounts()
  } catch (error) {
    console.error('加载账户数据失败:', error)
  }
}

const goBack = () => {
  emit('navigate', 'asset')
}

const addAsset = async () => {
  // 验证必填字段
  if (!assetForm.value.name) {
    alert('请输入资产名称')
    return
  }
  if (!assetForm.value.type) {
    alert('请选择资产类型')
    return
  }
  if (!assetForm.value.amount || assetForm.value.amount <= 0) {
    alert('请输入有效的金额')
    return
  }
  if (!assetForm.value.account_id) {
    alert('请选择关联账户')
    return
  }
  if (!assetForm.value.calculation_type) {
    alert('请选择计算类型')
    return
  }
  if (assetForm.value.calculation_type === '按金额计算' && (!assetForm.value.income_amount || assetForm.value.income_amount <= 0)) {
    alert('请输入每期收益金额')
    return
  }
  if (assetForm.value.calculation_type === '按年收益率计算' && (!assetForm.value.annual_yield_rate || assetForm.value.annual_yield_rate <= 0)) {
    alert('请输入年收益率')
    return
  }
  if (assetForm.value.calculation_type !== '无' && !assetForm.value.period) {
    alert('请选择收益周期')
    return
  }

  // 验证资产类型为公积金时，关联账户必须是公积金账户
  if (assetForm.value.type === '公积金') {
    const selectedAccount = accounts.value.find(acc => acc.id === assetForm.value.account_id)
    if (!selectedAccount || selectedAccount.type !== '公积金') {
      alert('公积金资产必须关联公积金账户')
      return
    }
  }

  // 构建收益日字符串
  let incomeDate = ''
  if (assetForm.value.period && assetForm.value.period !== '日') {
    if (assetForm.value.period === '年' && assetForm.value.income_month && assetForm.value.income_day) {
      incomeDate = `${String(assetForm.value.income_month).padStart(2, '0')}-${String(assetForm.value.income_day).padStart(2, '0')}`
    } else if (assetForm.value.period === '月' && assetForm.value.income_day) {
      incomeDate = `${String(assetForm.value.income_day).padStart(2, '0')}`
    }
  }

  try {
    const isNoCalc = assetForm.value.calculation_type === '无'
    await addAssetService({
      type: assetForm.value.type,
      name: assetForm.value.name,
      amount: assetForm.value.amount,
      account_id: assetForm.value.account_id,
      calculation_type: assetForm.value.calculation_type as '无' | '按金额计算' | '按年收益率计算',
      income_amount: isNoCalc ? 0 : assetForm.value.income_amount,
      annual_yield_rate: isNoCalc ? 0 : assetForm.value.annual_yield_rate / 100,
      period: isNoCalc ? undefined : assetForm.value.period,
      period_count: isNoCalc ? 0 : assetForm.value.period_count,
      income_date: isNoCalc ? undefined : incomeDate
    }, assetForm.value.deduct_from_account)
    emit('navigate', 'asset')
  } catch (error) {
    console.error('新增资产失败:', error)
    alert('新增资产失败，请重试')
  }
}
</script>

<style scoped>
.form-container {
  background-color: white;
  padding: 0;
  box-sizing: border-box;
}

.el-form {
  margin: 0;
  padding: 16px;
}

.el-form-item {
  margin-bottom: 0;
  padding: 16px 0;
  border-bottom: 1px solid #f0f0f0;
  display: flex;
  align-items: center;
}

.el-form-item:last-child {
  border-bottom: none;
}

.el-form-item__label {
  font-size: 14px;
  font-weight: 500;
  color: #333333;
  width: 80px;
  flex-shrink: 0;
  margin-bottom: 0;
}

.el-form-item__content {
  flex: 1;
  margin-left: 16px;
}

.el-input {
  border: none;
  border-radius: 0;
}

.el-input__wrapper {
  border: none;
  box-shadow: none;
  padding: 0;
  height: auto;
  min-height: 32px;
}

.el-input__wrapper:focus-within {
  box-shadow: none;
  border-color: transparent;
}

.el-select {
  border: none;
  border-radius: 0;
  width: 100%;
}

.el-select .el-input__wrapper {
  border: none;
  padding: 0;
  height: auto;
  min-height: 32px;
}

.el-select:focus-within {
  box-shadow: none;
  border-color: transparent;
}

.income-date-year {
  display: flex;
  width: 100%;
  align-items: center;
}

/* 响应式设计 */
@media (max-width: 375px) {
  .el-form {
    padding: 14px;
  }
  
  .el-form-item {
    padding: 14px 0;
  }
  
  .el-form-item__label {
    width: 70px;
    font-size: 13px;
  }
}
</style>
