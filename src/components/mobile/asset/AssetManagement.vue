<template>
  <div class="asset-management">
    <el-card>
      <template #header>
        <div class="card-header">
          <span>资产管理</span>
          <el-button type="primary" @click="openAddAssetDialog">新增资产</el-button>
        </div>
      </template>
      
      <el-tabs v-model="activeTab">
        <el-tab-pane label="通用资产" name="general">
          <el-table :data="generalAssets" style="width: 100%">
            <el-table-column prop="id" label="ID" width="80" />
            <el-table-column prop="name" label="资产名称" />
            <el-table-column prop="type" label="资产类型" />
            <el-table-column prop="amount" label="金额" width="120">
              <template #default="scope">
                ¥{{ scope.row.amount.toFixed(2) }}
              </template>
            </el-table-column>
            <el-table-column prop="account_id" label="关联账户" />
            <el-table-column label="操作" width="150">
              <template #default="scope">
                <el-button type="primary" size="small" @click="openEditAssetDialog(scope.row)">编辑</el-button>
                <el-button type="danger" size="small" @click="deleteAsset(scope.row.id)">删除</el-button>
              </template>
            </el-table-column>
          </el-table>
        </el-tab-pane>
        
        <el-tab-pane label="股票资产" name="stock">
          <el-table :data="stocks" style="width: 100%">
            <el-table-column prop="id" label="ID" width="80" />
            <el-table-column prop="name" label="股票名称" />
            <el-table-column prop="code" label="股票代码" />
            <el-table-column prop="price" label="交易价格" width="100" />
            <el-table-column prop="quantity" label="股数" width="80" />
            <el-table-column prop="fee" label="手续费" width="80" />
            <el-table-column prop="transaction_time" label="交易时间" />
            <el-table-column prop="type" label="交易类型" width="80" />
            <el-table-column label="操作" width="100">
              <template #default="scope">
                <el-button type="danger" size="small" @click="deleteStock(scope.row.id)">删除</el-button>
              </template>
            </el-table-column>
          </el-table>
          <el-button type="primary" class="mt-4" @click="openAddStockDialog">新增股票交易</el-button>
        </el-tab-pane>
        
        <el-tab-pane label="基金资产" name="fund">
          <el-table :data="funds" style="width: 100%">
            <el-table-column prop="id" label="ID" width="80" />
            <el-table-column prop="name" label="基金名称" />
            <el-table-column prop="code" label="基金代码" />
            <el-table-column prop="nav" label="单位净值" width="100" />
            <el-table-column prop="shares" label="份额" width="80" />
            <el-table-column prop="fee" label="手续费" width="80" />
            <el-table-column prop="has_lock" label="锁定期" width="80">
              <template #default="scope">
                {{ scope.row.has_lock ? '是' : '否' }}
              </template>
            </el-table-column>
            <el-table-column prop="transaction_time" label="交易时间" />
            <el-table-column prop="type" label="交易类型" width="80" />
            <el-table-column label="操作" width="100">
              <template #default="scope">
                <el-button type="danger" size="small" @click="deleteFund(scope.row.id)">删除</el-button>
              </template>
            </el-table-column>
          </el-table>
          <el-button type="primary" class="mt-4" @click="openAddFundDialog">新增基金交易</el-button>
        </el-tab-pane>
      </el-tabs>
    </el-card>
    
    <!-- 新增资产对话框 -->
    <el-dialog v-model="dialogVisible.addAsset" title="新增资产" width="500px">
      <el-form :model="assetForm" label-width="80px">
        <el-form-item label="资产名称">
          <el-input v-model="assetForm.name" placeholder="请输入资产名称" />
        </el-form-item>
        <el-form-item label="资产类型">
          <el-select v-model="assetForm.type" placeholder="请选择资产类型">
            <el-option label="工资" value="工资" />
            <el-option label="租金" value="租金" />
            <el-option label="利息" value="利息" />
            <el-option label="版权" value="版权" />
            <el-option label="副业" value="副业" />
            <el-option label="被动收入" value="被动收入" />
            <el-option label="自定义" value="自定义" />
          </el-select>
        </el-form-item>
        <el-form-item label="金额">
          <el-input v-model.number="assetForm.amount" placeholder="请输入金额" type="number" min="0" step="0.01" />
        </el-form-item>
        <el-form-item label="关联账户">
          <el-select v-model="assetForm.account_id" placeholder="请选择关联账户">
            <el-option v-for="account in accounts" :key="account.id" :label="account.name" :value="account.id" />
          </el-select>
        </el-form-item>
      </el-form>
      <template #footer>
        <span class="dialog-footer">
          <el-button @click="dialogVisible.addAsset = false">取消</el-button>
          <el-button type="primary" @click="addAsset">确定</el-button>
        </span>
      </template>
    </el-dialog>
    
    <!-- 编辑资产对话框 -->
    <el-dialog v-model="dialogVisible.editAsset" title="编辑资产" width="500px">
      <el-form :model="assetForm" label-width="80px">
        <el-form-item label="资产名称">
          <el-input v-model="assetForm.name" placeholder="请输入资产名称" />
        </el-form-item>
        <el-form-item label="资产类型">
          <el-select v-model="assetForm.type" placeholder="请选择资产类型">
            <el-option label="工资" value="工资" />
            <el-option label="租金" value="租金" />
            <el-option label="利息" value="利息" />
            <el-option label="版权" value="版权" />
            <el-option label="副业" value="副业" />
            <el-option label="被动收入" value="被动收入" />
            <el-option label="自定义" value="自定义" />
          </el-select>
        </el-form-item>
        <el-form-item label="金额">
          <el-input v-model.number="assetForm.amount" placeholder="请输入金额" type="number" min="0" step="0.01" />
        </el-form-item>
        <el-form-item label="关联账户">
          <el-select v-model="assetForm.account_id" placeholder="请选择关联账户">
            <el-option v-for="account in accounts" :key="account.id" :label="account.name" :value="account.id" />
          </el-select>
        </el-form-item>
      </el-form>
      <template #footer>
        <span class="dialog-footer">
          <el-button @click="dialogVisible.editAsset = false">取消</el-button>
          <el-button type="primary" @click="updateAsset">确定</el-button>
        </span>
      </template>
    </el-dialog>
    
    <!-- 新增股票交易对话框 -->
    <el-dialog v-model="dialogVisible.addStock" title="新增股票交易" width="500px">
      <el-form :model="stockForm" label-width="100px">
        <el-form-item label="股票名称">
          <el-input v-model="stockForm.name" placeholder="请输入股票名称" />
        </el-form-item>
        <el-form-item label="股票代码">
          <el-input v-model="stockForm.code" placeholder="请输入股票代码" />
        </el-form-item>
        <el-form-item label="交易类型">
          <el-select v-model="stockForm.type" placeholder="请选择交易类型">
            <el-option label="买入" value="买入" />
            <el-option label="卖出" value="卖出" />
          </el-select>
        </el-form-item>
        <el-form-item label="交易价格">
          <el-input v-model.number="stockForm.price" placeholder="请输入交易价格" type="number" min="0" step="0.01" />
        </el-form-item>
        <el-form-item label="交易股数">
          <el-input v-model.number="stockForm.quantity" placeholder="请输入交易股数" type="number" min="1" step="1" />
        </el-form-item>
        <el-form-item label="手续费">
          <el-input v-model.number="stockForm.fee" placeholder="请输入手续费" type="number" min="0" step="0.01" />
        </el-form-item>
        <el-form-item label="交易时间">
          <el-date-picker v-model="stockForm.transaction_time" type="datetime" placeholder="请选择交易时间" style="width: 100%" />
        </el-form-item>
        <el-form-item label="关联账户">
          <el-select v-model="stockForm.account_id" placeholder="请选择关联账户">
            <el-option v-for="account in accounts" :key="account.id" :label="account.name" :value="account.id" />
          </el-select>
        </el-form-item>
      </el-form>
      <template #footer>
        <span class="dialog-footer">
          <el-button @click="dialogVisible.addStock = false">取消</el-button>
          <el-button type="primary" @click="addStock">确定</el-button>
        </span>
      </template>
    </el-dialog>
    
    <!-- 新增基金交易对话框 -->
    <el-dialog v-model="dialogVisible.addFund" title="新增基金交易" width="500px">
      <el-form :model="fundForm" label-width="100px">
        <el-form-item label="基金名称">
          <el-input v-model="fundForm.name" placeholder="请输入基金名称" />
        </el-form-item>
        <el-form-item label="基金代码">
          <el-input v-model="fundForm.code" placeholder="请输入基金代码" />
        </el-form-item>
        <el-form-item label="交易类型">
          <el-select v-model="fundForm.type" placeholder="请选择交易类型">
            <el-option label="买入" value="买入" />
            <el-option label="卖出" value="卖出" />
          </el-select>
        </el-form-item>
        <el-form-item label="单位净值">
          <el-input v-model.number="fundForm.nav" placeholder="请输入单位净值" type="number" min="0" step="0.0001" />
        </el-form-item>
        <el-form-item label="交易份额">
          <el-input v-model.number="fundForm.shares" placeholder="请输入交易份额" type="number" min="0" step="0.0001" />
        </el-form-item>
        <el-form-item label="手续费">
          <el-input v-model.number="fundForm.fee" placeholder="请输入手续费" type="number" min="0" step="0.01" />
        </el-form-item>
        <el-form-item label="锁定期">
          <el-switch v-model="fundForm.has_lock" />
        </el-form-item>
        <el-form-item label="交易时间">
          <el-date-picker v-model="fundForm.transaction_time" type="datetime" placeholder="请选择交易时间" style="width: 100%" />
        </el-form-item>
        <el-form-item label="关联账户">
          <el-select v-model="fundForm.account_id" placeholder="请选择关联账户">
            <el-option v-for="account in accounts" :key="account.id" :label="account.name" :value="account.id" />
          </el-select>
        </el-form-item>
      </el-form>
      <template #footer>
        <span class="dialog-footer">
          <el-button @click="dialogVisible.addFund = false">取消</el-button>
          <el-button type="primary" @click="addFund">确定</el-button>
        </span>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useAccountStore } from '../../../stores/account'

const accountStore = useAccountStore()
const accounts = ref([])
const activeTab = ref('general')

const generalAssets = ref([])
const stocks = ref([])
const funds = ref([])

const dialogVisible = ref({
  addAsset: false,
  editAsset: false,
  addStock: false,
  addFund: false
})

const assetForm = ref({
  id: '',
  name: '',
  type: '',
  amount: 0,
  account_id: ''
})

const stockForm = ref({
  id: '',
  name: '',
  code: '',
  price: 0,
  quantity: 0,
  fee: 0,
  transaction_time: new Date(),
  type: '买入',
  account_id: ''
})

const fundForm = ref({
  id: '',
  name: '',
  code: '',
  nav: 0,
  shares: 0,
  fee: 0,
  has_lock: false,
  transaction_time: new Date(),
  type: '买入',
  account_id: ''
})

onMounted(async () => {
  await accountStore.loadAccounts()
  accounts.value = accountStore.accounts
  await loadAssets()
  await loadStocks()
  await loadFunds()
})

const loadAssets = async () => {
  // 模拟数据
  generalAssets.value = [
    { id: '1', name: '工资收入', type: '工资', amount: 10000, account_id: '1' },
    { id: '2', name: '房租收入', type: '租金', amount: 3000, account_id: '2' }
  ]
}

const loadStocks = async () => {
  // 模拟数据
  stocks.value = [
    { id: '1', name: '贵州茅台', code: '600519', price: 1800, quantity: 10, fee: 18, transaction_time: new Date(), type: '买入', account_id: '1' },
    { id: '2', name: '腾讯控股', code: '00700', price: 350, quantity: 100, fee: 35, transaction_time: new Date(), type: '买入', account_id: '1' }
  ]
}

const loadFunds = async () => {
  // 模拟数据
  funds.value = [
    { id: '1', name: '易方达蓝筹精选', code: '005827', nav: 1.5, shares: 1000, fee: 15, has_lock: false, transaction_time: new Date(), type: '买入', account_id: '2' },
    { id: '2', name: '广发科技先锋', code: '005271', nav: 2.0, shares: 500, fee: 10, has_lock: true, transaction_time: new Date(), type: '买入', account_id: '2' }
  ]
}

const openAddAssetDialog = () => {
  assetForm.value = {
    id: '',
    name: '',
    type: '',
    amount: 0,
    account_id: ''
  }
  dialogVisible.value.addAsset = true
}

const openEditAssetDialog = (asset: any) => {
  assetForm.value = { ...asset }
  dialogVisible.value.editAsset = true
}

const openAddStockDialog = () => {
  stockForm.value = {
    id: '',
    name: '',
    code: '',
    price: 0,
    quantity: 0,
    fee: 0,
    transaction_time: new Date(),
    type: '买入',
    account_id: ''
  }
  dialogVisible.value.addStock = true
}

const openAddFundDialog = () => {
  fundForm.value = {
    id: '',
    name: '',
    code: '',
    nav: 0,
    shares: 0,
    fee: 0,
    has_lock: false,
    transaction_time: new Date(),
    type: '买入',
    account_id: ''
  }
  dialogVisible.value.addFund = true
}

const addAsset = () => {
  // 模拟添加资产
  const newAsset = {
    id: Date.now().toString(),
    ...assetForm.value
  }
  generalAssets.value.push(newAsset)
  dialogVisible.value.addAsset = false
}

const updateAsset = () => {
  // 模拟更新资产
  const index = generalAssets.value.findIndex(a => a.id === assetForm.value.id)
  if (index !== -1) {
    generalAssets.value[index] = { ...assetForm.value }
  }
  dialogVisible.value.editAsset = false
}

const deleteAsset = (id: string) => {
  // 模拟删除资产
  generalAssets.value = generalAssets.value.filter(a => a.id !== id)
}

const addStock = () => {
  // 模拟添加股票交易
  const newStock = {
    id: Date.now().toString(),
    ...stockForm.value
  }
  stocks.value.push(newStock)
  dialogVisible.value.addStock = false
}

const deleteStock = (id: string) => {
  // 模拟删除股票交易
  stocks.value = stocks.value.filter(s => s.id !== id)
}

const addFund = () => {
  // 模拟添加基金交易
  const newFund = {
    id: Date.now().toString(),
    ...fundForm.value
  }
  funds.value.push(newFund)
  dialogVisible.value.addFund = false
}

const deleteFund = (id: string) => {
  // 模拟删除基金交易
  funds.value = funds.value.filter(f => f.id !== id)
}
</script>

<style scoped>
.asset-management {
  padding: 0;
}

.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.mt-4 {
  margin-top: 20px;
}

.dialog-footer {
  width: 100%;
  display: flex;
  justify-content: flex-end;
}
</style>