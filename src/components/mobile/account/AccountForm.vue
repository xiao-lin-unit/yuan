<template>
  <el-form :model="form" label-width="80px">
    <el-form-item label="账户名称">
      <el-input v-model="form.name" placeholder="请输入账户名称" />
    </el-form-item>
    <el-form-item label="账户类型">
      <el-select v-model="form.type" placeholder="请选择账户类型">
        <el-option v-for="item in accountTypes" :key="item.value" :label="item.label" :value="item.value" />
      </el-select>
    </el-form-item>
    <el-form-item label="备注">
      <el-input v-model="form.remark" placeholder="请输入备注" />
    </el-form-item>
  </el-form>
</template>

<script setup lang="ts">
import { ref, defineProps, defineEmits } from 'vue'
import { accountTypes } from '../../../utils/dictionaries'

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