<template>
  <el-form :model="form" label-width="80px">
    <el-form-item label="转出账户">
      <el-select v-model="form.from_account_id" placeholder="请选择转出账户">
        <el-option v-for="account in accounts" :key="account.id" :label="account.name" :value="account.id" />
      </el-select>
    </el-form-item>
    <el-form-item label="转入账户">
      <el-select v-model="form.to_account_id" placeholder="请选择转入账户">
        <el-option v-for="account in accounts" :key="account.id" :label="account.name" :value="account.id" />
      </el-select>
    </el-form-item>
    <el-form-item label="转账金额">
      <el-input v-model.number="form.amount" placeholder="请输入转账金额" type="number" min="0" step="0.01" />
    </el-form-item>
    <el-form-item label="备注">
      <el-input v-model="form.remark" placeholder="请输入备注" />
    </el-form-item>
    <el-form-item>
      <el-button type="primary" @click="$emit('submit')">执行转账</el-button>
    </el-form-item>
  </el-form>
</template>

<script setup lang="ts">
import { ref } from 'vue'

interface Account {
  id: string
  name: string
  type: string
  balance: number
  remark: string
}

interface TransferForm {
  from_account_id: string
  to_account_id: string
  amount: number
  remark: string
}

const props = defineProps<{
  modelValue: TransferForm
  accounts: Account[]
}>()

const emit = defineEmits<{
  (e: 'update:modelValue', value: TransferForm): void
  (e: 'submit'): void
}>()

const form = ref<TransferForm>({ ...props.modelValue })
</script>

<style scoped>
</style>