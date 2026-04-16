<template>
  <PageTemplate 
    title="新增账户"
    show-confirm-button
    confirm-text="确认添加"
    @back="goBack"
    @confirm="addAccount"
  >
    <div class="form-container">
      <el-form :model="accountForm" label-width="80px">
        <el-form-item label="账户名称" required>
          <el-input v-model="accountForm.name" placeholder="请输入账户名称" />
        </el-form-item>
        <el-form-item label="账户类型" required>
          <el-select v-model="accountForm.type" placeholder="请选择账户类型">
            <el-option v-for="item in accountTypes" :key="item.value" :label="item.label" :value="item.value" />
          </el-select>
        </el-form-item>
        <el-form-item label="余额" v-if="accountForm.type !== '信用卡'">
          <el-input v-model.number="accountForm.balance" placeholder="请输入余额" type="number" step="0.01" />
        </el-form-item>
        <el-form-item label="已用额度" v-if="accountForm.type === '信用卡'">
          <el-input v-model.number="accountForm.used_limit" placeholder="请输入已用额度" type="number" step="0.01" />
        </el-form-item>
        <el-form-item label="总额度" v-if="accountForm.type === '信用卡'">
          <el-input v-model.number="accountForm.total_limit" placeholder="请输入总额度" type="number" step="0.01" />
        </el-form-item>
        <el-form-item label="流动资金" v-if="accountForm.type !== '信用卡' && accountForm.type !== '社保卡' && accountForm.type !== '公积金'">
          <el-switch v-model="accountForm.is_liquid" />
        </el-form-item>
        <el-form-item label="备注">
          <el-input v-model="accountForm.remark" placeholder="请输入备注" />
        </el-form-item>
      </el-form>
    </div>
  </PageTemplate>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue'
import PageTemplate from '../../common/PageTemplate.vue'
import { accountTypes } from '../../../utils/dictionaries'
import { addAccount as addAccountService } from '../../../services/account/accountService'

const emit = defineEmits(['navigate'])

const accountForm = ref({
  name: '',
  type: '',
  balance: 0,
  used_limit: 0,
  total_limit: 0,
  is_liquid: true,
  remark: ''
})

// 监听账户类型变化，自动更新流动资金状态
watch(() => accountForm.value.type, (newType) => {
  if (newType === '信用卡' || newType === '社保卡' || newType === '公积金') {
    accountForm.value.is_liquid = false
  } else if (newType) {
    accountForm.value.is_liquid = true
  }
})

const goBack = () => {
  emit('navigate', 'account')
}

const addAccount = async () => {
  // 表单验证
  if (!accountForm.value.name) {
    alert('请输入账户名称')
    return
  }
  if (!accountForm.value.type) {
    alert('请选择账户类型')
    return
  }
  
  if (accountForm.value.type === '信用卡' || accountForm.value.type === '社保卡' || accountForm.value.type === '公积金') {
    accountForm.value.is_liquid = false
  } else if (accountForm.value.type) {
    accountForm.value.is_liquid = true
  }

  try {
    console.log('Submitting account form:', accountForm.value)
    await addAccountService({
      name: accountForm.value.name,
      type: accountForm.value.type,
      balance: accountForm.value.balance,
      used_limit: accountForm.value.used_limit,
      total_limit: accountForm.value.total_limit,
      is_liquid: accountForm.value.is_liquid,
      remark: accountForm.value.remark
    })
    console.log('Account added successfully, navigating back...')
    emit('navigate', 'account')
  } catch (error: any) {
    console.error('添加账户失败:', error)
    const errorMessage = error?.message || error?.toString() || '未知错误'
    alert('添加账户失败：' + errorMessage)
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