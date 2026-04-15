<template>
  <PageTemplate 
    title="新增通用资产"
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
            <el-option label="工资" value="工资" />
            <el-option label="租金" value="租金" />
            <el-option label="利息" value="利息" />
            <el-option label="版权" value="版权" />
            <el-option label="副业" value="副业" />
            <el-option label="被动收入" value="被动收入" />
            <el-option label="社保" value="社保" />
            <el-option label="公积金" value="公积金" />
            <el-option label="其他" value="其他" />
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
        <el-form-item label="收益周期">
          <el-select v-model="assetForm.period" placeholder="请选择周期（可选）">
            <el-option label="每年" value="年" />
            <el-option label="每月" value="月" />
          </el-select>
        </el-form-item>
      </el-form>
    </div>
  </PageTemplate>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import PageTemplate from '../../common/PageTemplate.vue'
import db from '../../../database/index.js'

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
  period: ''
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
    const accountData = await db.query('SELECT * FROM accounts')
    accounts.value = accountData
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
  
  // 验证资产类型为公积金时，关联账户必须是公积金账户
  if (assetForm.value.type === '公积金') {
    const selectedAccount = accounts.value.find(acc => acc.id === assetForm.value.account_id)
    if (!selectedAccount || selectedAccount.type !== '公积金') {
      alert('公积金资产必须关联公积金账户')
      return
    }
  }
  
  try {
    const id = Date.now().toString()
    await db.run(
      'INSERT INTO assets (id, type, name, amount, account_id, period) VALUES (?, ?, ?, ?, ?, ?)',
      [id, assetForm.value.type, assetForm.value.name, assetForm.value.amount, assetForm.value.account_id, assetForm.value.period]
    )
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