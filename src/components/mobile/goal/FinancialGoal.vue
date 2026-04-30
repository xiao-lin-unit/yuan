<template>
  <div class="financial-goal">
    <el-card>
      <template #header>
        <div class="card-header">
          <span>财务目标规划</span>
          <el-button type="primary" @click="openAddGoalDialog">新增目标</el-button>
        </div>
      </template>
      
      <el-table :data="goals" style="width: 100%">
        <el-table-column prop="id" label="ID" width="80" />
        <el-table-column prop="name" label="目标名称" />
        <el-table-column prop="type" label="目标类型" />
        <el-table-column prop="target_amount" label="目标金额" width="120">
          <template #default="scope">
            ¥{{ scope.row.target_amount.toFixed(2) }}
          </template>
        </el-table-column>
        <el-table-column prop="monthly_amount" label="每月投入" width="120">
          <template #default="scope">
            ¥{{ scope.row.monthly_amount.toFixed(2) }}
          </template>
        </el-table-column>
        <el-table-column prop="period" label="期限(月)" width="100" />
        <el-table-column prop="status" label="状态" width="80" />
        <el-table-column label="操作" width="200">
          <template #default="scope">
            <el-button type="primary" size="small" @click="openEditGoalDialog(scope.row)">编辑</el-button>
            <el-button size="small" @click="openInvestDialog(scope.row)">投入</el-button>
            <el-button type="danger" size="small" @click="deleteGoal(scope.row.id)">删除</el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-card>
    
    <!-- 新增目标对话框 -->
    <el-dialog v-model="dialogVisible.addGoal" title="新增财务目标" width="500px">
      <el-form :model="goalForm" label-width="100px">
        <el-form-item label="目标名称">
          <el-input v-model="goalForm.name" placeholder="请输入目标名称" />
        </el-form-item>
        <el-form-item label="目标类型">
          <el-select v-model="goalForm.type" placeholder="请选择目标类型">
            <el-option v-for="item in goalTypes" :key="item.value" :label="item.label" :value="item.value" />
          </el-select>
        </el-form-item>
        <el-form-item label="目标金额">
          <el-input v-model.number="goalForm.target_amount" placeholder="请输入目标金额" type="number" min="0" step="0.01" />
        </el-form-item>
        <el-form-item label="目标期限(月)">
          <el-input v-model.number="goalForm.period" placeholder="请输入目标期限" type="number" min="1" />
        </el-form-item>
        <el-form-item label="每月投入金额">
          <el-input v-model.number="goalForm.monthly_amount" placeholder="系统自动计算" type="number" min="0" step="0.01" />
        </el-form-item>
        <el-form-item label="关联账户">
          <el-select v-model="goalForm.account_id" placeholder="请选择关联账户">
            <el-option v-for="account in accounts" :key="account.id" :label="account.name" :value="account.id" />
          </el-select>
        </el-form-item>
      </el-form>
      <template #footer>
        <span class="dialog-footer">
          <el-button @click="dialogVisible.addGoal = false">取消</el-button>
          <el-button type="primary" @click="addGoal">确定</el-button>
        </span>
      </template>
    </el-dialog>
    
    <!-- 编辑目标对话框 -->
    <el-dialog v-model="dialogVisible.editGoal" title="编辑财务目标" width="500px">
      <el-form :model="goalForm" label-width="100px">
        <el-form-item label="目标名称">
          <el-input v-model="goalForm.name" placeholder="请输入目标名称" />
        </el-form-item>
        <el-form-item label="目标类型">
          <el-select v-model="goalForm.type" placeholder="请选择目标类型">
            <el-option v-for="item in goalTypes" :key="item.value" :label="item.label" :value="item.value" />
          </el-select>
        </el-form-item>
        <el-form-item label="目标金额">
          <el-input v-model.number="goalForm.target_amount" placeholder="请输入目标金额" type="number" min="0" step="0.01" />
        </el-form-item>
        <el-form-item label="目标期限(月)">
          <el-input v-model.number="goalForm.period" placeholder="请输入目标期限" type="number" min="1" />
        </el-form-item>
        <el-form-item label="每月投入金额">
          <el-input v-model.number="goalForm.monthly_amount" placeholder="请输入每月投入金额" type="number" min="0" step="0.01" />
        </el-form-item>
        <el-form-item label="关联账户">
          <el-select v-model="goalForm.account_id" placeholder="请选择关联账户">
            <el-option v-for="account in accounts" :key="account.id" :label="account.name" :value="account.id" />
          </el-select>
        </el-form-item>
        <el-form-item label="状态">
          <el-select v-model="goalForm.status" placeholder="请选择状态">
            <el-option v-for="item in goalStatuses" :key="item.value" :label="item.label" :value="item.value" />
          </el-select>
        </el-form-item>
      </el-form>
      <template #footer>
        <span class="dialog-footer">
          <el-button @click="dialogVisible.editGoal = false">取消</el-button>
          <el-button type="primary" @click="updateGoal">确定</el-button>
        </span>
      </template>
    </el-dialog>
    
    <!-- 投入对话框 -->
    <el-dialog v-model="dialogVisible.invest" title="目标投入" width="500px">
      <el-form :model="investForm" label-width="80px">
        <el-form-item label="投入金额">
          <el-input v-model.number="investForm.amount" placeholder="请输入投入金额" type="number" min="0" step="0.01" />
        </el-form-item>
        <el-form-item label="投入日期">
          <el-date-picker v-model="investForm.date" type="date" placeholder="请选择投入日期" style="width: 100%" />
        </el-form-item>
        <el-form-item label="备注">
          <el-input v-model="investForm.remark" placeholder="请输入备注" />
        </el-form-item>
      </el-form>
      <template #footer>
        <span class="dialog-footer">
          <el-button @click="dialogVisible.invest = false">取消</el-button>
          <el-button type="primary" @click="addInvest">确定</el-button>
        </span>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, watch } from 'vue'
import { getCurrentDate } from '../../../utils/timezone'
import { getAccounts } from '../../../services/account/accountService'
import { goalTypes, goalStatuses } from '../../../utils/dictionaries'

const accounts = ref<any[]>([])
const goals = ref([])

const dialogVisible = ref({
  addGoal: false,
  editGoal: false,
  invest: false
})

const goalForm = ref({
  id: '',
  name: '',
  type: '',
  target_amount: 0,
  monthly_amount: 0,
  period: 12,
  account_id: '',
  status: '未开始'
})

const investForm = ref({
  goalId: '',
  amount: 0,
  date: getCurrentDate(),
  remark: ''
})

onMounted(async () => {
  accounts.value = await getAccounts()
  await loadGoals()
})

watch([() => goalForm.value.target_amount, () => goalForm.value.period], () => {
  if (goalForm.value.period > 0) {
    goalForm.value.monthly_amount = goalForm.value.target_amount / goalForm.value.period
  }
})

const loadGoals = async () => {
  // 模拟数据
  goals.value = [
    {
      id: '1',
      name: '3年存10万',
      type: '储蓄类',
      target_amount: 100000,
      monthly_amount: 2777.78,
      period: 36,
      account_id: '1',
      status: '进行中'
    },
    {
      id: '2',
      name: '还清房贷',
      type: '还款类',
      target_amount: 950000,
      monthly_amount: 5000,
      period: 190,
      account_id: '1',
      status: '进行中'
    }
  ]
}

const openAddGoalDialog = () => {
  goalForm.value = {
    id: '',
    name: '',
    type: '',
    target_amount: 0,
    monthly_amount: 0,
    period: 12,
    account_id: '',
    status: '未开始'
  }
  dialogVisible.value.addGoal = true
}

const openEditGoalDialog = (goal: any) => {
  goalForm.value = { ...goal }
  dialogVisible.value.editGoal = true
}

const openInvestDialog = (goal: any) => {
  investForm.value = {
    goalId: goal.id,
    amount: 0,
    date: getCurrentDate(),
    remark: ''
  }
  dialogVisible.value.invest = true
}

const addGoal = () => {
  // 模拟添加目标
  const newGoal = {
    id: getCurrentDate().valueOf().toString(),
    ...goalForm.value
  }
  goals.value.push(newGoal)
  dialogVisible.value.addGoal = false
}

const updateGoal = () => {
  // 模拟更新目标
  const index = goals.value.findIndex(g => g.id === goalForm.value.id)
  if (index !== -1) {
    goals.value[index] = { ...goalForm.value }
  }
  dialogVisible.value.editGoal = false
}

const deleteGoal = (id: string) => {
  // 模拟删除目标
  goals.value = goals.value.filter(g => g.id !== id)
}

const addInvest = () => {
  // 模拟添加投入
  dialogVisible.value.invest = false
  // 这里可以添加投入逻辑，更新目标进度
}
</script>

<style scoped>
.financial-goal {
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