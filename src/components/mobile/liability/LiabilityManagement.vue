<template>
  <div class="liability-management">
    <el-card>
      <template #header>
        <div class="card-header">
          <span>负债管理</span>
          <el-button type="primary" @click="openAddLiabilityDialog">新增负债</el-button>
        </div>
      </template>
      
      <el-table :data="liabilities" style="width: 100%">
        <el-table-column prop="id" label="ID" width="80" />
        <el-table-column prop="name" label="负债名称" />
        <el-table-column prop="type" label="负债类型" />
        <el-table-column prop="principal" label="本金" width="100">
          <template #default="scope">
            ¥{{ scope.row.principal.toFixed(2) }}
          </template>
        </el-table-column>
        <el-table-column prop="remaining_principal" label="剩余本金" width="120">
          <template #default="scope">
            ¥{{ scope.row.remaining_principal.toFixed(2) }}
          </template>
        </el-table-column>
        <el-table-column prop="interest_rate" label="年化利率" width="100">
          <template #default="scope">
            {{ (scope.row.interest_rate * 100).toFixed(2) }}%
          </template>
        </el-table-column>
        <el-table-column prop="repayment_method" label="还款方式" width="100" />
        <el-table-column prop="status" label="状态" width="80" />
        <el-table-column label="操作" width="200">
          <template #default="scope">
            <el-button type="primary" size="small" @click="openEditLiabilityDialog(scope.row)">编辑</el-button>
            <el-button size="small" @click="openRepaymentDialog(scope.row)">还款</el-button>
            <el-button type="danger" size="small" @click="deleteLiability(scope.row.id)">删除</el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-card>
    
    <!-- 新增负债对话框 -->
    <el-dialog v-model="dialogVisible.addLiability" title="新增负债" width="600px">
      <el-form :model="liabilityForm" label-width="120px">
        <el-form-item label="负债名称">
          <el-input v-model="liabilityForm.name" placeholder="请输入负债名称" />
        </el-form-item>
        <el-form-item label="负债类型">
          <el-select v-model="liabilityForm.type" placeholder="请选择负债类型">
            <el-option v-for="item in liabilityTypes" :key="item.value" :label="item.label" :value="item.value" />
          </el-select>
        </el-form-item>
        <el-form-item label="本金">
          <el-input v-model.number="liabilityForm.principal" placeholder="请输入本金" type="number" min="0" step="0.01" />
        </el-form-item>
        <el-form-item label="是否计息">
          <el-switch v-model="liabilityForm.is_interest" />
        </el-form-item>
        <el-form-item label="年化利率" v-if="liabilityForm.is_interest">
          <el-input v-model.number="liabilityForm.interest_rate" placeholder="请输入年化利率" type="number" min="0" step="0.0001" />
        </el-form-item>
        <el-form-item label="借款日期">
          <el-date-picker v-model="liabilityForm.start_date" type="date" placeholder="请选择借款日期" style="width: 100%" />
        </el-form-item>
        <el-form-item label="还款方式">
          <el-select v-model="liabilityForm.repayment_method" placeholder="请选择还款方式">
            <el-option v-for="item in repaymentMethods" :key="item.value" :label="item.label" :value="item.value" />
          </el-select>
        </el-form-item>
        <el-form-item label="还款日" v-if="liabilityForm.repayment_method !== '随借随还'">
          <el-input v-model.number="liabilityForm.repayment_day" placeholder="请输入还款日" type="number" min="1" max="31" />
        </el-form-item>
        <el-form-item label="期数" v-if="liabilityForm.repayment_method !== '随借随还'">
          <el-input v-model.number="liabilityForm.period" placeholder="请输入期数" type="number" min="1" />
        </el-form-item>
        <el-form-item label="绑定账户">
          <el-select v-model="liabilityForm.account_id" placeholder="请选择绑定账户">
            <el-option v-for="account in accounts" :key="account.id" :label="account.name" :value="account.id" />
          </el-select>
        </el-form-item>
        <el-form-item label="备注">
          <el-input v-model="liabilityForm.remark" placeholder="请输入备注" type="textarea" />
        </el-form-item>
      </el-form>
      <template #footer>
        <span class="dialog-footer">
          <el-button @click="dialogVisible.addLiability = false">取消</el-button>
          <el-button type="primary" @click="addLiability">确定</el-button>
        </span>
      </template>
    </el-dialog>
    
    <!-- 编辑负债对话框 -->
    <el-dialog v-model="dialogVisible.editLiability" title="编辑负债" width="600px">
      <el-form :model="liabilityForm" label-width="120px">
        <el-form-item label="负债名称">
          <el-input v-model="liabilityForm.name" placeholder="请输入负债名称" />
        </el-form-item>
        <el-form-item label="负债类型">
          <el-select v-model="liabilityForm.type" placeholder="请选择负债类型">
            <el-option v-for="item in liabilityTypes" :key="item.value" :label="item.label" :value="item.value" />
          </el-select>
        </el-form-item>
        <el-form-item label="本金">
          <el-input v-model.number="liabilityForm.principal" placeholder="请输入本金" type="number" min="0" step="0.01" />
        </el-form-item>
        <el-form-item label="剩余本金">
          <el-input v-model.number="liabilityForm.remaining_principal" placeholder="请输入剩余本金" type="number" min="0" step="0.01" />
        </el-form-item>
        <el-form-item label="是否计息">
          <el-switch v-model="liabilityForm.is_interest" />
        </el-form-item>
        <el-form-item label="年化利率" v-if="liabilityForm.is_interest">
          <el-input v-model.number="liabilityForm.interest_rate" placeholder="请输入年化利率" type="number" min="0" step="0.0001" />
        </el-form-item>
        <el-form-item label="借款日期">
          <el-date-picker v-model="liabilityForm.start_date" type="date" placeholder="请选择借款日期" style="width: 100%" />
        </el-form-item>
        <el-form-item label="还款方式">
          <el-select v-model="liabilityForm.repayment_method" placeholder="请选择还款方式">
            <el-option v-for="item in repaymentMethods" :key="item.value" :label="item.label" :value="item.value" />
          </el-select>
        </el-form-item>
        <el-form-item label="还款日" v-if="liabilityForm.repayment_method !== '随借随还'">
          <el-input v-model.number="liabilityForm.repayment_day" placeholder="请输入还款日" type="number" min="1" max="31" />
        </el-form-item>
        <el-form-item label="期数" v-if="liabilityForm.repayment_method !== '随借随还'">
          <el-input v-model.number="liabilityForm.period" placeholder="请输入期数" type="number" min="1" />
        </el-form-item>
        <el-form-item label="绑定账户">
          <el-select v-model="liabilityForm.account_id" placeholder="请选择绑定账户">
            <el-option v-for="account in accounts" :key="account.id" :label="account.name" :value="account.id" />
          </el-select>
        </el-form-item>
        <el-form-item label="备注">
          <el-input v-model="liabilityForm.remark" placeholder="请输入备注" type="textarea" />
        </el-form-item>
        <el-form-item label="状态">
          <el-select v-model="liabilityForm.status" placeholder="请选择状态">
            <el-option v-for="item in liabilityStatuses" :key="item.value" :label="item.label" :value="item.value" />
          </el-select>
        </el-form-item>
      </el-form>
      <template #footer>
        <span class="dialog-footer">
          <el-button @click="dialogVisible.editLiability = false">取消</el-button>
          <el-button type="primary" @click="updateLiability">确定</el-button>
        </span>
      </template>
    </el-dialog>
    
    <!-- 还款对话框 -->
    <el-dialog v-model="dialogVisible.repayment" title="还款" width="500px">
      <el-form :model="repaymentForm" label-width="80px">
        <el-form-item label="还款金额">
          <el-input v-model.number="repaymentForm.amount" placeholder="请输入还款金额" type="number" min="0" step="0.01" />
        </el-form-item>
        <el-form-item label="还款方式">
          <el-select v-model="repaymentForm.type" placeholder="请选择还款方式">
            <el-option v-for="item in repaymentTypes" :key="item.value" :label="item.label" :value="item.value" />
          </el-select>
        </el-form-item>
        <el-form-item label="备注">
          <el-input v-model="repaymentForm.remark" placeholder="请输入备注" />
        </el-form-item>
      </el-form>
      <template #footer>
        <span class="dialog-footer">
          <el-button @click="dialogVisible.repayment = false">取消</el-button>
          <el-button type="primary" @click="makeRepayment">确定</el-button>
        </span>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import dayjs from 'dayjs'
import { useAccountStore } from '../../../stores/account'
import { liabilityTypes, repaymentMethods, liabilityStatuses, repaymentTypes } from '../../../utils/dictionaries'

const accountStore = useAccountStore()
const accounts = ref([])
const liabilities = ref([])

const dialogVisible = ref({
  addLiability: false,
  editLiability: false,
  repayment: false
})

const liabilityForm = ref({
  id: '',
  name: '',
  type: '',
  principal: 0,
  remaining_principal: 0,
  is_interest: true,
  interest_rate: 0,
  start_date: dayjs(),
  repayment_method: '等额本息',
  repayment_day: 1,
  period: 12,
  account_id: '',
  remark: '',
  status: '未结清'
})

const repaymentForm = ref({
  liabilityId: '',
  amount: 0,
  type: '正常还款',
  remark: ''
})

onMounted(async () => {
  await accountStore.loadAccounts()
  accounts.value = accountStore.accounts
  await loadLiabilities()
})

const loadLiabilities = async () => {
  // 模拟数据
  liabilities.value = [
    {
      id: '1',
      name: '招商银行房贷',
      type: '房贷',
      principal: 1000000,
      remaining_principal: 950000,
      is_interest: true,
      interest_rate: 0.049,
      start_date: dayjs('2024-01-01'),
      repayment_method: '等额本息',
      repayment_day: 1,
      period: 360,
      account_id: '1',
      remark: '首套房贷款',
      status: '未结清'
    },
    {
      id: '2',
      name: '亲友借款-张三',
      type: '亲友借款',
      principal: 50000,
      remaining_principal: 50000,
      is_interest: false,
      interest_rate: 0,
      start_date: dayjs('2024-03-01'),
      repayment_method: '随借随还',
      account_id: '2',
      remark: '临时周转',
      status: '未结清'
    }
  ]
}

const openAddLiabilityDialog = () => {
  liabilityForm.value = {
    id: '',
    name: '',
    type: '',
    principal: 0,
    remaining_principal: 0,
    is_interest: true,
    interest_rate: 0,
    start_date: dayjs(),
    repayment_method: '等额本息',
    repayment_day: 1,
    period: 12,
    account_id: '',
    remark: '',
    status: '未结清'
  }
  dialogVisible.value.addLiability = true
}

const openEditLiabilityDialog = (liability: any) => {
  liabilityForm.value = { ...liability }
  dialogVisible.value.editLiability = true
}

const openRepaymentDialog = (liability: any) => {
  repaymentForm.value = {
    liabilityId: liability.id,
    amount: 0,
    type: '正常还款',
    remark: ''
  }
  dialogVisible.value.repayment = true
}

const addLiability = () => {
  // 模拟添加负债
  const newLiability = {
    id: dayjs().valueOf().toString(),
    remaining_principal: liabilityForm.value.principal,
    ...liabilityForm.value
  }
  liabilities.value.push(newLiability)
  dialogVisible.value.addLiability = false
}

const updateLiability = () => {
  // 模拟更新负债
  const index = liabilities.value.findIndex(l => l.id === liabilityForm.value.id)
  if (index !== -1) {
    liabilities.value[index] = { ...liabilityForm.value }
  }
  dialogVisible.value.editLiability = false
}

const deleteLiability = (id: string) => {
  // 模拟删除负债
  liabilities.value = liabilities.value.filter(l => l.id !== id)
}

const makeRepayment = () => {
  // 模拟还款
  const liability = liabilities.value.find(l => l.id === repaymentForm.value.liabilityId)
  if (liability) {
    const newRemainingPrincipal = liability.remaining_principal - repaymentForm.value.amount
    if (newRemainingPrincipal <= 0) {
      liability.remaining_principal = 0
      liability.status = '已结清'
    } else {
      liability.remaining_principal = newRemainingPrincipal
    }
  }
  dialogVisible.value.repayment = false
}
</script>

<style scoped>
.liability-management {
  padding: 0;
}

.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.dialog-footer {
  width: 100%;
  display: flex;
  justify-content: flex-end;
}
</style>