// migrate_asset_income_dates.js
import fs from 'fs/promises';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const ROOT_DIR = path.resolve(__dirname);

// Helper function to read file
async function readFile(relativePath) {
  const fullPath = path.join(ROOT_DIR, relativePath);
  console.log(`Reading: ${relativePath}`);
  return await fs.readFile(fullPath, 'utf-8');
}

// Helper function to write file
async function writeFile(relativePath, content) {
  const fullPath = path.join(ROOT_DIR, relativePath);
  console.log(`Writing: ${relativePath}`);
  await fs.writeFile(fullPath, content, 'utf-8');
}

// 1. Update database schema
async function updateDatabaseSchema() {
  console.log('\n=== Updating Database Schema ===');
  const content = await readFile('src/database/index.js');
  
  // Find the assets table creation and add new columns
  const oldAssetsTable = `CREATE TABLE IF NOT EXISTS assets (
              id TEXT PRIMARY KEY,
              type TEXT NOT NULL,
              name TEXT NOT NULL,
              amount REAL DEFAULT 0,
              account_id TEXT,
              period TEXT,
              period_count INTEGER DEFAULT 0,
              ended INTEGER DEFAULT 0,
              created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
              updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
              FOREIGN KEY (account_id) REFERENCES accounts(id)
            )`;
  
  const newAssetsTable = `CREATE TABLE IF NOT EXISTS assets (
              id TEXT PRIMARY KEY,
              type TEXT NOT NULL,
              name TEXT NOT NULL,
              amount REAL DEFAULT 0,
              account_id TEXT,
              period TEXT,
              period_count INTEGER DEFAULT 0,
              income_date TEXT,
              next_income_date TEXT,
              ended INTEGER DEFAULT 0,
              created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
              updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
              FOREIGN KEY (account_id) REFERENCES accounts(id)
            )`;
  
  if (content.includes('income_date TEXT')) {
    console.log('✓ Database schema already updated');
    return;
  }
  
  let newContent = content.replace(oldAssetsTable, newAssetsTable);
  
  // Add migration statements after the assets table
  const migrationAddition = `},
        // 为assets表添加收益日字段（迁移）
        {
          sql: \`
            ALTER TABLE assets ADD COLUMN income_date TEXT
          \`,
          ignoreError: true
        },
        // 为assets表添加下一收益日字段（迁移）
        {
          sql: \`
            ALTER TABLE assets ADD COLUMN next_income_date TEXT
          \`,
          ignoreError: true
        },`;
  
  // Find the closing of the assets table definition
  const assetsTableEnd = `FOREIGN KEY (account_id) REFERENCES accounts(id)
            )
          \`
        },`;
  
  const migrationPoint = newContent.indexOf(assetsTableEnd);
  if (migrationPoint !== -1) {
    const insertPosition = migrationPoint + assetsTableEnd.length;
    newContent = newContent.slice(0, insertPosition) + migrationAddition + newContent.slice(insertPosition);
  }
  
  await writeFile('src/database/index.js', newContent);
  console.log('✓ Database schema updated successfully');
}

// 2. Update type definitions
async function updateTypeDefinitions() {
  console.log('\n=== Updating Type Definitions ===');
  const content = await readFile('src/types/asset/asset.ts');
  
  const newContent = `/**
 * General asset type definitions
 */

// Base asset interface
export interface Asset {
  id: string
  type: string
  name: string
  amount: number
  account_id: string
  period?: string
  period_count?: number
  income_date?: string
  next_income_date?: string
  ended: number
  created_at?: Date | string
  updated_at?: Date | string
}

// Input for adding a new asset
export interface AssetInput {
  type: string
  name: string
  amount: number
  account_id: string
  period?: string
  period_count?: number
  income_date?: string
}
`;
  
  await writeFile('src/types/asset/asset.ts', newContent);
  console.log('✓ Type definitions updated successfully');
}

// 3. Update asset service
async function updateAssetService() {
  console.log('\n=== Updating Asset Service ===');
  const content = await readFile('src/services/asset/assetService.ts');
  
  // Check if already updated
  if (content.includes('calculateNextIncomeDate')) {
    console.log('✓ Asset service already updated');
    return;
  }
  
  const newContent = `/**
 * Asset Service
 * Handles general asset operations
 */

import db from '../../database/index.js'
import type { Asset, AssetInput } from '../../types/asset/asset.js'

/**
 * Calculate next income date based on period and income date
 */
function calculateNextIncomeDate(period: string, incomeDate: string): string {
  if (!period || !incomeDate) return ''

  const now = new Date()
  const incomeParts = incomeDate.split('-')

  if (period === '年') {
    // 每年：income_date format is MM-DD, next income date is this year or next year
    const [month, day] = incomeParts
    let nextDate = new Date(now.getFullYear(), parseInt(month) - 1, parseInt(day))
    
    // If this year's income date has passed, next year
    if (nextDate <= now) {
      nextDate = new Date(now.getFullYear() + 1, parseInt(month) - 1, parseInt(day))
    }
    
    return nextDate.toISOString().split('T')[0]
  } else if (period === '月') {
    // 每月：income_date format is DD, next income date is this month or next month
    const [day] = incomeParts
    let nextDate = new Date(now.getFullYear(), now.getMonth(), parseInt(day))
    
    // If this month's income date has passed, next month
    if (nextDate <= now) {
      nextDate = new Date(now.getFullYear(), now.getMonth() + 1, parseInt(day))
    }
    
    return nextDate.toISOString().split('T')[0]
  }

  return ''
}

/**
 * Add a new general asset
 */
export async function addAsset(assetData: AssetInput): Promise<void> {
  const id = Date.now().toString()
  
  // Calculate next income date
  let nextIncomeDate = ''
  if (assetData.period && assetData.income_date) {
    nextIncomeDate = calculateNextIncomeDate(assetData.period, assetData.income_date)
  }

  await db.run(
    'INSERT INTO assets (id, type, name, amount, account_id, period, period_count, income_date, next_income_date) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
    [
      id,
      assetData.type,
      assetData.name,
      assetData.amount,
      assetData.account_id,
      assetData.period || null,
      assetData.period_count || 0,
      assetData.income_date || null,
      nextIncomeDate || null
    ]
  )
}

/**
 * Get all assets
 */
export async function getAssets(): Promise<Asset[]> {
  return await db.query('SELECT * FROM assets ORDER BY created_at DESC')
}

/**
 * Get assets by type
 */
export async function getAssetsByType(type: string): Promise<Asset[]> {
  return await db.query('SELECT * FROM assets WHERE type = ? ORDER BY created_at DESC', [type])
}

/**
 * Get active assets (not ended)
 */
export async function getActiveAssets(): Promise<Asset[]> {
  return await db.query('SELECT * FROM assets WHERE ended = 0 ORDER BY created_at DESC')
}

/**
 * Get asset by ID
 */
export async function getAssetById(assetId: string): Promise<Asset | null> {
  const result = await db.query('SELECT * FROM assets WHERE id = ?', [assetId])
  return result.length > 0 ? result[0] : null
}

/**
 * Update asset
 */
export async function updateAsset(assetId: string, data: Partial<Asset>): Promise<void> {
  const fields: string[] = []
  const values: any[] = []

  if (data.name !== undefined) {
    fields.push('name = ?')
    values.push(data.name)
  }
  if (data.amount !== undefined) {
    fields.push('amount = ?')
    values.push(data.amount)
  }
  if (data.account_id !== undefined) {
    fields.push('account_id = ?')
    values.push(data.account_id)
  }
  if (data.period !== undefined) {
    fields.push('period = ?')
    values.push(data.period)
  }
  if (data.period_count !== undefined) {
    fields.push('period_count = ?')
    values.push(data.period_count)
  }
  if (data.income_date !== undefined) {
    fields.push('income_date = ?')
    values.push(data.income_date)
  }
  if (data.ended !== undefined) {
    fields.push('ended = ?')
    values.push(data.ended)
  }

  if (fields.length === 0) return

  fields.push('updated_at = CURRENT_TIMESTAMP')
  values.push(assetId)

  await db.run(
    \`UPDATE assets SET \${fields.join(', ')} WHERE id = ?\`,
    values
  )
}

/**
 * Delete asset
 */
export async function deleteAsset(assetId: string): Promise<void> {
  await db.run('DELETE FROM assets WHERE id = ?', [assetId])
}

/**
 * Mark asset as ended
 */
export async function endAsset(assetId: string): Promise<void> {
  await db.run(
    'UPDATE assets SET ended = 1, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
    [assetId]
  )
}
`;
  
  await writeFile('src/services/asset/assetService.ts', newContent);
  console.log('✓ Asset service updated successfully');
}

// 4. Update AddAssetPage.vue
async function updateAddAssetPage() {
  console.log('\n=== Updating AddAssetPage.vue ===');
  const content = await readFile('src/components/mobile/asset/AddAssetPage.vue');
  
  // Check if already updated
  if (content.includes('income_month')) {
    console.log('✓ AddAssetPage already updated');
    return;
  }
  
  const newContent = `<template>
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
            <el-option v-for="item in assetTypes" :key="item.value" :label="item.label" :value="item.value" />
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
            <el-option v-for="item in periodTypes" :key="item.value" :label="item.label" :value="item.value" />
          </el-select>
        </el-form-item>
        <el-form-item label="收益日" v-if="assetForm.period">
          <div v-if="assetForm.period === '年'" class="income-date-year">
            <el-select v-model="assetForm.income_month" placeholder="月" style="width: 45%; margin-right: 5px;">
              <el-option 
                v-for="m in 12" 
                :key="m" 
                :label="\`\${m}月\`" 
                :value="m" 
              />
            </el-select>
            <el-select v-model="assetForm.income_day" placeholder="日" style="width: 45%;">
              <el-option 
                v-for="d in 31" 
                :key="d" 
                :label="\`\${d}日\`" 
                :value="d" 
              />
            </el-select>
          </div>
          <el-select v-else-if="assetForm.period === '月'" v-model="assetForm.income_day" placeholder="请选择日期" style="width: 100%;">
            <el-option 
              v-for="d in 31" 
              :key="d" 
              :label="\`\${d}日\`" 
              :value="d" 
            />
          </el-select>
        </el-form-item>
        <el-form-item label="周期数量" v-if="assetForm.period">
          <el-input
            v-model.number="assetForm.period_count"
            placeholder="请输入周期数量"
            type="number"
            min="1"
            step="1"
          >
            <template #append>{{ assetForm.period }}</template>
          </el-input>
        </el-form-item>
      </el-form>
    </div>
  </PageTemplate>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import PageTemplate from '../../common/PageTemplate.vue'
import { assetTypes, periodTypes } from '../../../utils/dictionaries'
import { addAsset as addAssetService } from '../../../services/asset/assetService'
import { getNonCreditCardAccounts } from '../../../services/account/accountService'

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
  period: '',
  period_count: 0,
  income_month: 0,
  income_day: 0
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
    accounts.value = await getNonCreditCardAccounts()
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

  // 构建收益日字符串
  let incomeDate = ''
  if (assetForm.value.period) {
    if (assetForm.value.period === '年' && assetForm.value.income_month && assetForm.value.income_day) {
      incomeDate = \`\${String(assetForm.value.income_month).padStart(2, '0')}-\${String(assetForm.value.income_day).padStart(2, '0')}\`
    } else if (assetForm.value.period === '月' && assetForm.value.income_day) {
      incomeDate = \`\${String(assetForm.value.income_day).padStart(2, '0')}\`
    }
  }
  
  try {
    await addAssetService({
      type: assetForm.value.type,
      name: assetForm.value.name,
      amount: assetForm.value.amount,
      account_id: assetForm.value.account_id,
      period: assetForm.value.period,
      period_count: assetForm.value.period_count,
      income_date: incomeDate
    })
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

.income-date-year {
  display: flex;
  width: 100%;
  align-items: center;
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
`;
  
  await writeFile('src/components/mobile/asset/AddAssetPage.vue', newContent);
  console.log('✓ AddAssetPage.vue updated successfully');
}

// 5. Update AssetDetailPage.vue
async function updateAssetDetailPage() {
  console.log('\n=== Updating AssetDetailPage.vue ===');
  const content = await readFile('src/components/mobile/asset/AssetDetailPage.vue');
  
  // Check if already updated
  if (content.includes('income_date') && content.includes('assetInfo.income_date')) {
    console.log('✓ AssetDetailPage already updated');
    return;
  }
  
  // Update assetInfo ref to include new fields
  let newContent = content.replace(
    /const assetInfo = ref\(\{[\s\S]*?\}\);/,
    `const assetInfo = ref({
  name: '',
  type: '',
  amount: 0,
  period: '',
  period_count: 0,
  income_date: '',
  next_income_date: '',
  accountName: '',
  ended: 0,
  created_at: '' as string | Date
});`
  );
  
  // Update assetInfo.value assignment to include new fields
  newContent = newContent.replace(
    /assetInfo\.value = \{[\s\S]*?created_at: asset\.created_at \|\| ''\s*\}/,
    `assetInfo.value = {
      name: asset.name,
      type: asset.type,
      amount: asset.amount,
      period: asset.period || '',
      period_count: asset.period_count || 0,
      income_date: asset.income_date || '',
      next_income_date: asset.next_income_date || '',
      accountName,
      ended: asset.ended,
      created_at: asset.created_at || ''
    }`
  );
  
  // Update the meta section to include income_date and next_income_date
  newContent = newContent.replace(
    /<div class="asset-meta">[\s\S]*?<\/div>\s*<\/div>/,
    `<div class="asset-meta">
        <div class="meta-item" v-if="assetInfo.period">
          <div class="meta-label">周期</div>
          <div class="meta-value">{{ assetInfo.period }}</div>
        </div>
        <div class="meta-item" v-if="assetInfo.period_count">
          <div class="meta-label">剩余期数</div>
          <div class="meta-value">{{ assetInfo.period_count }}</div>
        </div>
        <div class="meta-item" v-if="assetInfo.income_date">
          <div class="meta-label">收益日</div>
          <div class="meta-value">{{ assetInfo.income_date }}</div>
        </div>
        <div class="meta-item" v-if="assetInfo.next_income_date">
          <div class="meta-label">下一收益日</div>
          <div class="meta-value">{{ formatDate(assetInfo.next_income_date) }}</div>
        </div>
      </div>
    </div>`
  );
  
  await writeFile('src/components/mobile/asset/AssetDetailPage.vue', newContent);
  console.log('✓ AssetDetailPage.vue updated successfully');
}

// Main execution
async function main() {
  console.log('Starting asset income date migration...\n');
  
  try {
    await updateDatabaseSchema();
    await updateTypeDefinitions();
    await updateAssetService();
    await updateAddAssetPage();
    await updateAssetDetailPage();
    
    console.log('\n✅ All migrations completed successfully!');
  } catch (error) {
    console.error('\n❌ Migration failed:', error);
    process.exit(1);
  }
}

main();