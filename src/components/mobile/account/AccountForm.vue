<template>
  <el-form :model="form" label-width="80px">
    <el-form-item label="账户名称">
      <el-input v-model="form.name" placeholder="请输入账户名称" />
    </el-form-item>
    <el-form-item label="账户类型">
      <el-select v-model="form.type" placeholder="请选择账户类型">
        <el-option label="现金" value="现金" />
        <el-option label="微信" value="微信" />
        <el-option label="支付宝" value="支付宝" />
        <el-option label="储蓄卡" value="储蓄卡" />
        <el-option label="社保卡" value="社保卡" />
      </el-select>
    </el-form-item>
    <el-form-item label="备注">
      <el-input v-model="form.remark" placeholder="请输入备注" />
    </el-form-item>
  </el-form>
</template>

<script setup lang="ts">
import { ref, defineProps, defineEmits } from 'vue'

interface Account {
  id: string
  name: string
  type: string
  balance: number
  remark: string
}

const props = defineProps<{
  modelValue: Partial<Account>
}>()

const emit = defineEmits<{
  (e: 'update:modelValue', value: Partial<Account>): void
}>()

const form = ref<Partial<Account>>({ ...props.modelValue })
</script>

<style scoped>
</style>