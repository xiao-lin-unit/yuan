<template>
  <el-form :model="form" label-width="80px">
    <el-form-item label="调整类型">
      <el-select v-model="form.type" placeholder="请选择调整类型">
        <el-option label="修正错误" value="修正错误" />
        <el-option label="现金赠与" value="现金赠与" />
        <el-option label="资产盘盈" value="资产盘盈" />
      </el-select>
    </el-form-item>
    <el-form-item label="调整金额">
      <el-input v-model.number="form.amount" placeholder="请输入调整金额" type="number" step="0.01" />
    </el-form-item>
    <el-form-item label="备注">
      <el-input v-model="form.remark" placeholder="请输入备注" />
    </el-form-item>
  </el-form>
</template>

<script setup lang="ts">
import { ref, defineProps, defineEmits } from 'vue'

interface AdjustForm {
  accountId: string
  type: string
  amount: number
  remark: string
}

const props = defineProps<{
  modelValue: AdjustForm
}>()

const emit = defineEmits<{
  (e: 'update:modelValue', value: AdjustForm): void
}>()

const form = ref<AdjustForm>({ ...props.modelValue })
</script>

<style scoped>
</style>