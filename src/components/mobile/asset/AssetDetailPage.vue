<template>
  <div class="asset-detail-page">
    <!-- 顶部导航栏 -->
    <div class="asset-detail-header">
      <div class="header-left" @click="goBack">
        <el-icon><ArrowLeft /></el-icon>
      </div>
      <h1 class="header-title">资产详情</h1>
      <div class="header-right"></div>
    </div>

    <!-- 资产基本信息 -->
    <div class="asset-basic-info">
      <h2 class="asset-name">{{ assetInfo.name }}</h2>
      <div class="asset-type-row">
        <span class="asset-type-tag">{{ assetInfo.type }}</span>
        <span v-if="assetInfo.ended" class="asset-ended-tag">已结束</span>
      </div>
      <div class="asset-amount">
        <div class="amount-label">资产金额(元)</div>
        <div class="amount-value">¥{{ assetInfo.amount.toFixed(2) }}</div>
      </div>
      <div class="asset-meta">
        <div class="meta-item">
          <div class="meta-label">周期</div>
          <div class="meta-value">{{ assetInfo.period }}</div>
        </div>
        <div class="meta-item">
          <div class="meta-label">剩余期数</div>
          <div class="meta-value">{{ assetInfo.period_count }}</div>
        </div>
        <div class="meta-item">
          <div class="meta-label">收益日</div>
          <div class="meta-value">{{ assetInfo.income_date }}</div>
        </div>
      </div>
      <div class="asset-meta">
        <div class="meta-item">
          <div class="meta-label">计算类型</div>
          <div class="meta-value">{{ assetInfo.calculation_type || '-' }}</div>
        </div>
        <div v-if="assetInfo.calculation_type && assetInfo.calculation_type !== '无'" class="meta-item">
          <div class="meta-label">{{ assetInfo.calculation_type === '按年收益率计算' ? '年收益率' : '每期收益' }}</div>
          <div class="meta-value">
            {{ assetInfo.calculation_type === '按年收益率计算' ? (assetInfo.annual_yield_rate * 100).toFixed(2) + '%' : '¥' + (assetInfo.income_amount || 0).toFixed(2) }}
          </div>
        </div>
        <div v-if="assetInfo.calculation_type && assetInfo.calculation_type !== '无'" class="meta-item">
          <div class="meta-label">下一收益日</div>
          <div class="meta-value">{{ formatDate(assetInfo.next_income_date) }}</div>
        </div>
      </div>
    </div>

    <!-- 收益记录明细 -->
    <div class="asset-income-records">
      <el-tabs v-model="activeTab" class="income-tabs">
        <el-tab-pane label="收益记录" name="income">
          <div class="income-list">
            <div v-if="incomeRecords.length === 0" class="no-records">
              <el-empty description="暂无收益记录" />
            </div>
            <div v-else>
              <div v-for="record in incomeRecords" :key="record.id" class="income-card">
                <div class="income-header">
                  <div class="income-type">收益</div>
                  <div class="income-date">{{ formatDate(record.record_time) }}</div>
                </div>
                <div class="income-content">
                  <div class="income-item">
                    <span class="item-label">收益金额</span>
                    <span class="item-value positive">¥{{ record.income_amount.toFixed(2) }}</span>
                  </div>
                  <div class="income-item" v-if="record.remark">
                    <span class="item-label">备注</span>
                    <span class="item-value">{{ record.remark }}</span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </el-tab-pane>
      </el-tabs>
    </div>

    <!-- 悬浮操作按钮（仅在未结束时显示） -->
    <FloatingActionMenu v-if="!assetInfo.ended" :buttons="actionButtons" />

    <!-- 修改资产信息弹框 -->
    <el-dialog v-model="showEditDialog" title="修改资产信息" width="90%" align-center>
      <el-form :model="editForm" label-width="100px">
        <el-form-item label="计算类型" required>
          <el-select v-model="editForm.calculation_type" placeholder="请选择计算类型" style="width: 100%">
            <el-option
              v-for="item in calculationTypes"
              :key="item.value"
              :label="item.label"
              :value="item.value"
            />
          </el-select>
        </el-form-item>
        <el-form-item v-if="editForm.calculation_type && editForm.calculation_type !== '无'" label="收益周期" required>
          <el-select v-model="editForm.period" placeholder="请选择收益周期" style="width: 100%">
            <el-option
              v-for="item in periodTypes"
              :key="item.value"
              :label="item.label"
              :value="item.value"
            />
          </el-select>
        </el-form-item>
        <el-form-item v-if="editForm.calculation_type === '按年收益率计算'" label="年收益率" required>
          <el-input
            v-model.number="editForm.annual_yield_rate"
            placeholder="请输入年收益率，如0.03表示3%"
            type="number"
            min="0"
            step="0.0001"
          />
        </el-form-item>
        <el-form-item v-if="editForm.calculation_type === '按金额计算'" label="每期收益" required>
          <el-input
            v-model.number="editForm.income_amount"
            placeholder="请输入每期收益金额"
            type="number"
            min="0"
            step="0.01"
          />
        </el-form-item>
      </el-form>
      <template #footer>
        <div class="dialog-footer">
          <el-button @click="showEditDialog = false">取消</el-button>
          <el-button type="primary" @click="saveEdit">保存</el-button>
        </div>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import dayjs from 'dayjs';
import { ArrowLeft, SwitchButton, Edit } from '@element-plus/icons-vue';
import { ElMessageBox, ElMessage } from 'element-plus';
import FloatingActionMenu from '../../../components/common/FloatingActionMenu.vue';
import { getAssetById, endAsset, updateAsset, getAssetIncomeRecords } from '../../../services/asset/assetService';
import { getAccounts } from '../../../services/account/accountService';
import { calculationTypes, periodTypes } from '../../../utils/dictionaries';

interface AssetIncomeRecord {
  id: string
  asset_id: string
  income_amount: number
  record_time: dayjs.Dayjs | string
  remark?: string
}

const props = defineProps({
  assetId: {
    type: String,
    required: true
  }
});

const emit = defineEmits(['navigate']);

const activeTab = ref('income');

const assetInfo = ref({
  name: '',
  type: '',
  amount: 0,
  period: '',
  period_count: 0,
  income_date: '',
  next_income_date: '',
  accountName: '',
  ended: 0,
  created_at: '' as string | Date | dayjs.Dayjs,
  calculation_type: '' as '无' | '按金额计算' | '按年收益率计算' | '',
  annual_yield_rate: 0,
  income_amount: 0
});

const showEditDialog = ref(false);
const editForm = ref({
  calculation_type: '' as '无' | '按金额计算' | '按年收益率计算' | '',
  period: '',
  annual_yield_rate: 0,
  income_amount: 0
});

const incomeRecords = ref<AssetIncomeRecord[]>([]);

const goBack = () => {
  emit('navigate', 'asset');
};

const formatDate = (dateString: string | dayjs.Dayjs | undefined) => {
  if (!dateString) return '-';
  return dayjs(dateString).format('YYYY/MM/DD HH:mm');
};

const handleEndAsset = async () => {
  try {
    await ElMessageBox.confirm(
      `确认要结束资产"${assetInfo.value.name}"吗？结束后该资产将移入历史资产。`,
      '结束资产',
      {
        confirmButtonText: '确认结束',
        cancelButtonText: '取消',
        type: 'warning'
      }
    );

    await endAsset(props.assetId);
    ElMessage.success('资产已结束');
    emit('navigate', 'asset');
  } catch (error) {
    if (error !== 'cancel') {
      console.error('结束资产失败:', error);
      ElMessage.error('结束资产失败');
    }
  }
};

const openEditDialog = () => {
  editForm.value = {
    calculation_type: assetInfo.value.calculation_type || '',
    period: assetInfo.value.period || '',
    annual_yield_rate: assetInfo.value.annual_yield_rate || 0,
    income_amount: assetInfo.value.income_amount || 0
  };
  showEditDialog.value = true;
};

const saveEdit = async () => {
  try {
    if (!editForm.value.calculation_type) {
      ElMessage.warning('请选择计算类型');
      return;
    }
    if (editForm.value.calculation_type !== '无' && !editForm.value.period) {
      ElMessage.warning('请选择收益周期');
      return;
    }
    if (editForm.value.calculation_type === '按年收益率计算' && (editForm.value.annual_yield_rate === undefined || editForm.value.annual_yield_rate < 0)) {
      ElMessage.warning('请输入有效的年收益率');
      return;
    }
    if (editForm.value.calculation_type === '按金额计算' && (editForm.value.income_amount === undefined || editForm.value.income_amount < 0)) {
      ElMessage.warning('请输入有效的每期收益金额');
      return;
    }

    const isNoCalc = editForm.value.calculation_type === '无';
    await updateAsset(props.assetId, {
      calculation_type: editForm.value.calculation_type,
      period: isNoCalc ? '' : editForm.value.period,
      annual_yield_rate: editForm.value.calculation_type === '按年收益率计算' ? editForm.value.annual_yield_rate : 0,
      income_amount: editForm.value.calculation_type === '按金额计算' ? editForm.value.income_amount : 0,
      next_income_date: isNoCalc ? '' : undefined
    });

    ElMessage.success('资产信息已更新');
    showEditDialog.value = false;
    await loadAssetDetail();
  } catch (error) {
    console.error('修改资产信息失败:', error);
    ElMessage.error('修改资产信息失败');
  }
};

const actionButtons = [
  {
    text: '修改',
    icon: Edit,
    action: openEditDialog
  },
  {
    text: '结束',
    icon: SwitchButton,
    action: handleEndAsset
  }
];

const loadIncomeRecords = async () => {
  try {
    const records = await getAssetIncomeRecords(props.assetId);
    incomeRecords.value = records;
  } catch (error) {
    console.error('加载收益记录失败:', error);
    incomeRecords.value = [];
  }
};

const loadAssetDetail = async () => {
  try {
    const asset = await getAssetById(props.assetId);
    if (!asset) {
      ElMessage.error('未找到该资产');
      emit('navigate', 'asset');
      return;
    }

    // 获取账户名称
    let accountName = '';
    if (asset.account_id) {
      const accounts = await getAccounts();
      const account = accounts.find(a => a.id === asset.account_id);
      accountName = account?.name || '';
    }

    assetInfo.value = {
      name: asset.name,
      type: asset.type,
      amount: asset.amount,
      period: asset.period || '',
      period_count: asset.period_count || 0,
      income_date: asset.income_date || '',
      next_income_date: asset.next_income_date || '',
      accountName,
      ended: asset.ended,
      created_at: asset.created_at || '',
      calculation_type: asset.calculation_type || '',
      annual_yield_rate: asset.annual_yield_rate || 0,
      income_amount: asset.income_amount || 0
    };

    // 加载收益记录
    await loadIncomeRecords();
  } catch (error) {
    console.error('加载资产详情失败:', error);
    ElMessage.error('加载资产详情失败');
  }
};

onMounted(() => {
  loadAssetDetail();
});
</script>

<style scoped>
.asset-detail-page {
  height: 100%;
  background-color: #f5f7fa;
  display: flex;
  flex-direction: column;
}

/* 顶部导航栏 */
.asset-detail-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 15px;
  background-color: #ffffff;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
}

.header-left,
.header-right {
  width: 40px;
  height: 40px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.header-title {
  font-size: 18px;
  font-weight: 600;
  color: #333333;
  margin: 0;
}

/* 资产基本信息 */
.asset-basic-info {
  padding: 13px 30px;
  background-color: #ffffff;
  margin-bottom: 10px;
}

.asset-name {
  font-size: 18px;
  font-weight: 600;
  color: #333333;
  margin: 0 0 10px 0;
}

.asset-type-row {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 20px;
}

.asset-type-tag {
  font-size: 13px;
  color: #409eff;
  background-color: #ecf5ff;
  padding: 2px 10px;
  border-radius: 10px;
}

.asset-ended-tag {
  font-size: 13px;
  color: #909399;
  background-color: #f4f4f5;
  padding: 2px 10px;
  border-radius: 10px;
}

.asset-amount {
  text-align: center;
  margin-bottom: 20px;
}

.amount-label {
  font-size: 14px;
  color: #666666;
  margin-bottom: 5px;
}

.amount-value {
  font-size: 32px;
  font-weight: 700;
  color: #333333;
}

.asset-meta {
  display: flex;
  justify-content: space-around;
  border-top: 1px solid #f0f0f0;
  padding-top: 15px;
  margin-bottom: 8px;
}

.meta-item {
  text-align: center;
}

.meta-label {
  font-size: 12px;
  color: #666666;
  margin-bottom: 5px;
}

.meta-value {
  font-size: 14px;
  font-weight: 600;
  color: #333333;
}

/* 收益记录明细 */
.asset-income-records {
  padding: 15px;
  background-color: #ffffff;
  margin-bottom: 80px;
}

.income-tabs {
  margin-bottom: 15px;
}

.income-tabs :deep(.el-tabs__nav) {
  width: 100%;
  display: flex;
}

.income-tabs :deep(.el-tabs__item) {
  flex: 1;
  text-align: center;
}

.no-records {
  padding: 20px 0;
  text-align: center;
}

.income-list {
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.income-card {
  background-color: #f9f9f9;
  border-radius: 8px;
  padding: 15px;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.05);
}

.income-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 10px;
  padding-bottom: 10px;
  border-bottom: 1px solid #f0f0f0;
}

.income-type {
  padding: 2px 8px;
  border-radius: 10px;
  font-size: 12px;
  font-weight: 600;
  background-color: #e6f7ff;
  color: #1890ff;
}

.income-date {
  font-size: 12px;
  color: #999999;
}

.income-content {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.income-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.item-label {
  font-size: 14px;
  color: #666666;
}

.item-value {
  font-size: 14px;
  color: #333333;
  font-weight: 500;
}

.item-value.positive {
  color: #67c23a;
  font-weight: 600;
}
</style>