<template>
  <PageTemplate
    title="新增负债"
    show-confirm-button
    confirm-text="确认添加"
    @back="goBack"
    @confirm="addLiability"
  >
    <div class="form-container">
      <el-form :model="liabilityForm" label-width="100px">
        <el-form-item label="负债名称" required>
          <el-input v-model="liabilityForm.name" placeholder="请输入负债名称" />
        </el-form-item>
        <el-form-item label="负债类型" required>
          <el-select v-model="liabilityForm.type" placeholder="请选择负债类型">
            <el-option v-for="item in liabilityTypes" :key="item.value" :label="item.label" :value="item.value" />
          </el-select>
        </el-form-item>
        <el-form-item label="剩余本金" required>
          <el-input v-model.number="liabilityForm.principal" placeholder="请输入本金" type="number" min="0" step="0.01" />
        </el-form-item>
        <el-form-item label="是否计息">
          <el-switch v-model="liabilityForm.is_interest" />
        </el-form-item>
        <el-form-item label="年化利率" required v-if="liabilityForm.is_interest">
          <el-input v-model.number="liabilityForm.interest_rate" placeholder="请输入年化利率" type="number" min="0" step="0.0001" />
          <template #suffix>%</template>
        </el-form-item>
        <el-form-item label="借款日期" required>
          <el-date-picker v-model="liabilityForm.start_date" type="date" placeholder="请选择借款日期" style="width: 100%" />
        </el-form-item>
        <el-form-item label="还款方式" required>
          <el-select v-model="liabilityForm.repayment_method" placeholder="请选择还款方式" :disabled="!liabilityForm.is_interest">
            <el-option v-for="item in repaymentMethods" :key="item.value" :label="item.label" :value="item.value" />
          </el-select>
        </el-form-item>
        <el-form-item label="还款日" v-if="liabilityForm.repayment_method !== '随借随还'">
            <el-select v-model="liabilityForm.repayment_day" placeholder="请选择日期" style="width: 100%;">
            <el-option 
              v-for="d in 31" 
              :key="d" 
              :label="`${d}日`" 
              :value="d" 
            />
          </el-select>
          <!-- <el-input v-model.number="liabilityForm.repayment_day" placeholder="请输入还款日（1-31）" type="number" min="1" max="31" /> -->
        </el-form-item>
        <el-form-item label="剩余期数" required v-if="liabilityForm.repayment_method !== '随借随还'">
          <el-input v-model.number="liabilityForm.period" placeholder="请输入期数" type="number" min="1" />
          <template #suffix>期</template>
        </el-form-item>
        <el-form-item v-if="liabilityForm.is_interest && totalInterestPreview > 0">
          <div class="interest-preview">
            <span class="interest-label">预计总利息：</span>
            <span class="interest-value">¥{{ totalInterestPreview.toFixed(2) }}</span>
          </div>
        </el-form-item>
        <el-form-item label="绑定账户" required>
          <el-select v-model="liabilityForm.account_id" placeholder="请选择绑定账户">
            <el-option v-for="account in accounts" :key="account.id" :label="account.name" :value="account.id" />
          </el-select>
        </el-form-item>
        <el-form-item label="备注">
          <el-input v-model="liabilityForm.remark" placeholder="请输入备注" type="textarea" />
        </el-form-item>
      </el-form>
    </div>
  </PageTemplate>
</template>

<script setup lang="ts">
import { ref, onMounted, computed, watch } from 'vue'
import { getCurrentDate } from '../../../utils/timezone'
import PageTemplate from '../../common/PageTemplate.vue'
import { liabilityTypes, repaymentMethods } from '../../../utils/dictionaries'
import { addLiability as addLiabilityService, calculateTotalInterest } from '../../../services/liability/liabilityService'
import { getNonCreditCardAccounts } from '../../../services/account/accountService'

const emit = defineEmits(['navigate'])

const accounts = ref<Array<{ id: string; name: string }>>([])

const liabilityForm = ref({
  name: '',
  type: '',
  principal: 0,
  is_interest: true,
  interest_rate: 0,
  start_date: getCurrentDate(),
  repayment_method: '等额本息',
  repayment_day: 1,
  period: 12,
  account_id: '',
  remark: ''
})

onMounted(async () => {
  await loadAccounts()
})

watch(() => liabilityForm.value.is_interest, () => {
  if (!liabilityForm.value.is_interest) {
    liabilityForm.value.repayment_method = '随借随还'
  }
})

const loadAccounts = async () => {
  try {
    accounts.value = await getNonCreditCardAccounts()
  } catch (error) {
    console.error('加载账户数据失败:', error)
  }
}

const totalInterestPreview = computed(() => {
  if (!liabilityForm.value.is_interest || !liabilityForm.value.principal || !liabilityForm.value.period) {
    return 0
  }
  return calculateTotalInterest(
    liabilityForm.value.principal,
    liabilityForm.value.interest_rate / 100,
    liabilityForm.value.period,
    liabilityForm.value.repayment_method
  )
})

const goBack = () => {
  emit('navigate', 'liability')
}

const addLiability = async () => {
  if (!liabilityForm.value.name) {
    alert('请输入负债名称')
    return
  }
  if (!liabilityForm.value.type) {
    alert('请选择负债类型')
    return
  }
  if (!liabilityForm.value.principal || liabilityForm.value.principal <= 0) {
    alert('请输入有效的本金')
    return
  }
  if (!liabilityForm.value.start_date) {
    alert('请选择借款日期')
    return
  }
  if (!liabilityForm.value.repayment_method) {
    alert('请选择还款方式')
    return
  }
  if (liabilityForm.value.is_interest && (!liabilityForm.value.interest_rate || liabilityForm.value.interest_rate < 0)) {
    alert('请输入有效的年化利率')
    return
  }

  try {
    const interestRate = liabilityForm.value.is_interest ? liabilityForm.value.interest_rate / 100 : 0
    await addLiabilityService({
      name: liabilityForm.value.name,
      type: liabilityForm.value.type,
      principal: liabilityForm.value.principal,
      is_interest: liabilityForm.value.is_interest,
      interest_rate: interestRate,
      start_date: liabilityForm.value.start_date,
      repayment_method: liabilityForm.value.repayment_method,
      repayment_day: liabilityForm.value.repayment_method !== '随借随还' ? liabilityForm.value.repayment_day : undefined,
      period: liabilityForm.value.repayment_method !== '随借随还' ? liabilityForm.value.period : undefined,
      account_id: liabilityForm.value.account_id,
      remark: liabilityForm.value.remark
    })
    emit('navigate', 'liability')
  } catch (error: any) {
    console.error('新增负债失败:', error)
    alert(error.message || '新增负债失败，请重试')
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
  width: 100px;
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

.interest-preview {
  width: 100%;
  padding: 8px 12px;
  background-color: #fff5f5;
  border-radius: 8px;
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.interest-label {
  font-size: 14px;
  color: #666;
}

.interest-value {
  font-size: 16px;
  font-weight: 600;
  color: #ff6b6b;
}

@media (max-width: 375px) {
  .el-form {
    padding: 14px;
  }

  .el-form-item {
    padding: 14px 0;
  }

  .el-form-item__label {
    width: 90px;
    font-size: 13px;
  }
}
</style>
