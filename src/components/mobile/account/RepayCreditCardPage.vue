<template>
  <PageTemplate 
    title="信用卡还款"
    show-confirm-button
    confirm-text="确认还款"
    @back="goBack"
    @confirm="repayCreditCard"
  >
    <div class="form-container">
      <el-form :model="repayForm" label-width="100px">
        <el-form-item label="账户名称" required>
          <el-input v-model="repayForm.account_name" placeholder="账户名称" disabled />
        </el-form-item>
        <el-form-item label="账户类型" required>
          <el-input v-model="repayForm.account_type" placeholder="账户类型" disabled />
        </el-form-item>
        <el-form-item label="当前已用额度" required>
          <el-input v-model="repayForm.current_used_limit" placeholder="当前已用额度" disabled />
        </el-form-item>
        <el-form-item label="还款金额" required>
          <el-input v-model.number="repayForm.amount" placeholder="请输入还款金额" type="number" min="0" step="0.01" />
        </el-form-item>
        <el-form-item label="还款时间" required>
          <el-date-picker v-model="repayForm.transaction_time" type="datetime" placeholder="请选择还款时间" style="width: 100%" />
        </el-form-item>
        <el-form-item label="关联账户" required>
          <el-select v-model="repayForm.from_account_id" placeholder="请选择还款来源账户">
            <el-option v-for="account in availableAccounts" :key="account.id" :label="account.name" :value="account.id" />
          </el-select>
        </el-form-item>
        <el-form-item label="备注">
          <el-input v-model="repayForm.remark" placeholder="请输入备注" />
        </el-form-item>
      </el-form>
    </div>
  </PageTemplate>
</template>

<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import dayjs from 'dayjs'
import PageTemplate from '../../common/PageTemplate.vue'
import { getAccountById, getNonCreditCardAccounts, repayCreditCard as repayCreditCardService } from '../../../services/account/accountService'
import type { Account } from '../../../types/account/account'

const props = defineProps({
  accountId: {
    type: String,
    required: true
  }
})

const emit = defineEmits(['navigate'])

// 账户数据
const allAccounts = ref<Account[]>([])
const creditCardInfo = ref<Account | null>(null)

// 可用账户（非信用卡账户）
const availableAccounts = computed(() => {
  return allAccounts.value.filter(account => account.type !== '信用卡')
})

// 表单数据
const repayForm = ref({
  account_id: '',
  account_name: '',
  account_type: '',
  current_used_limit: '',
  amount: 0,
  transaction_time: dayjs(),
  from_account_id: '',
  remark: ''
})

onMounted(async () => {
  await loadAccounts()
  await loadCreditCardData()
})

const loadAccounts = async () => {
  try {
    allAccounts.value = await getNonCreditCardAccounts()
  } catch (error) {
    console.error('加载账户数据失败:', error)
  }
}

const loadCreditCardData = async () => {
  try {
    const account = await getAccountById(props.accountId)
    if (account) {
      creditCardInfo.value = account
      repayForm.value.account_id = account.id
      repayForm.value.account_name = account.name
      repayForm.value.account_type = account.type
      repayForm.value.current_used_limit = `¥${(account.used_limit || 0).toFixed(2)}`
    }
  } catch (error) {
    console.error('加载信用卡数据失败:', error)
  }
}

const goBack = () => {
  emit('navigate', { key: 'accountDetail', params: { accountId: props.accountId } })
}

const repayCreditCard = async () => {
  // 验证必填字段
  if (!repayForm.value.amount || repayForm.value.amount <= 0) {
    alert('请输入有效的还款金额')
    return
  }
  if (!repayForm.value.transaction_time) {
    alert('请选择还款时间')
    return
  }
  if (!repayForm.value.from_account_id) {
    alert('请选择还款来源账户')
    return
  }

  // 验证还款金额不超过已用额度
  const usedLimit = creditCardInfo.value?.used_limit || 0
  if (repayForm.value.amount > usedLimit) {
    alert(`还款金额不能超过已用额度 ¥${usedLimit.toFixed(2)}`)
    return
  }

  try {
    await repayCreditCardService({
      credit_card_id: props.accountId,
      from_account_id: repayForm.value.from_account_id,
      amount: repayForm.value.amount,
      transaction_time: repayForm.value.transaction_time,
      remark: repayForm.value.remark
    })

    emit('navigate', 'account')
  } catch (error: any) {
    console.error('信用卡还款失败:', error)
    alert(error.message || '信用卡还款失败，请重试')
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

/* 响应式设计 */
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
