<template>
  <div class="add-account-page">
    <div class="page-header">
      <el-icon @click="goBack"><ArrowLeft /></el-icon>
      <h1>新增账户</h1>
      <div class="placeholder"></div>
    </div>

    <div class="form-container">
      <el-form :model="accountForm" label-width="80px">
        <el-form-item label="账户名称" required>
          <el-input v-model="accountForm.name" placeholder="请输入账户名称" />
        </el-form-item>
        <el-form-item label="账户类型" required>
          <el-select v-model="accountForm.type" placeholder="请选择账户类型">
            <el-option label="现金" value="现金" />
            <el-option label="微信" value="微信" />
            <el-option label="支付宝" value="支付宝" />
            <el-option label="储蓄卡" value="储蓄卡" />
            <el-option label="社保卡" value="社保卡" />
            <el-option label="信用卡" value="信用卡" />
          </el-select>
        </el-form-item>
        <el-form-item label="余额" v-if="accountForm.type !== '信用卡'">
          <el-input v-model.number="accountForm.balance" placeholder="请输入余额" type="number" step="0.01" />
        </el-form-item>
        <el-form-item label="流动资金" v-if="accountForm.type !== '信用卡' && accountForm.type !== '社保卡'">
          <el-switch v-model="accountForm.isLiquid" />
        </el-form-item>
        <el-form-item label="已用额度" v-if="accountForm.type === '信用卡'">
          <el-input v-model.number="accountForm.usedLimit" placeholder="请输入已用额度" type="number" step="0.01" />
        </el-form-item>
        <el-form-item label="总额度" v-if="accountForm.type === '信用卡'">
          <el-input v-model.number="accountForm.totalLimit" placeholder="请输入总额度" type="number" step="0.01" />
        </el-form-item>
        <el-form-item label="备注">
          <el-input v-model="accountForm.remark" placeholder="请输入备注" />
        </el-form-item>
      </el-form>
    </div>

    <div class="button-container">
      <el-button type="primary" class="submit-button" @click="addAccount">
        确认添加
      </el-button>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue'
import { useAccountStore } from '../../../stores/account'
import { ArrowLeft } from '@element-plus/icons-vue'

const emit = defineEmits(['navigate'])
const accountStore = useAccountStore()

const accountForm = ref({
  name: '',
  type: '',
  balance: 0,
  usedLimit: 0,
  totalLimit: 0,
  isLiquid: true,
  remark: ''
})

// 监听账户类型变化，自动更新流动资金状态
watch(() => accountForm.value.type, (newType) => {
  if (newType === '信用卡' || newType === '社保卡') {
    accountForm.value.isLiquid = false
  } else if (newType) {
    accountForm.value.isLiquid = true
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
  
  try {
    await accountStore.addAccount(accountForm.value)
    emit('navigate', 'account')
  } catch (error) {
    console.error('添加账户失败:', error)
  }
}
</script>

<style scoped>
.add-account-page {
  padding: 0;
  min-height: 100%;
  background-color: #f5f5f5;
  display: flex;
  flex-direction: column;
  box-sizing: border-box;
}

.page-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 16px;
  background-color: white;
  border-bottom: 1px solid #e0e0e0;
  position: sticky;
  top: 0;
  z-index: 100;
}

.page-header h1 {
  font-size: 16px;
  font-weight: bold;
  color: #333333;
  margin: 0;
}

.page-header .placeholder {
  width: 24px;
}

.page-header el-icon {
  font-size: 20px;
  color: #333333;
  cursor: pointer;
  transition: color 0.2s ease;
}

.page-header el-icon:hover {
  color: #409eff;
}

.form-container {
  background-color: white;
  padding: 0;
  flex: 1;
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

.button-container {
  padding: 16px;
  box-sizing: border-box;
  margin-top: auto;
  background-color: white;
  border-top: 1px solid #f0f0f0;
}

.submit-button {
  width: 90%;
  margin: 0 auto;
  padding: 14px 0;
  font-size: 16px;
  font-weight: 500;
  border-radius: 8px;
  background-color: #1677ff;
  border: none;
  color: white;
  transition: all 0.3s ease;
  cursor: pointer;
  display: block;
  text-align: center;
  line-height: 1.2;
  height: 44px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.submit-button:hover {
  background-color: #409eff;
}

.submit-button:active {
  background-color: #096dd9;
}

/* 响应式设计 */
@media (max-width: 375px) {
  .page-header {
    padding: 14px;
  }
  
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
  
  .button-container {
    padding: 14px;
  }
  
  .submit-button {
    width: 95%;
    padding: 12px 0;
    font-size: 15px;
    height: 40px;
  }
}
</style>