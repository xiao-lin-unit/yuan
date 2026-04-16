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
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { ArrowLeft, SwitchButton } from '@element-plus/icons-vue';
import { ElMessageBox, ElMessage } from 'element-plus';
import FloatingActionMenu from '../../../components/common/FloatingActionMenu.vue';
import { getAssetById, endAsset } from '../../../services/asset/assetService';
import { getAccounts } from '../../../services/account/accountService';

interface AssetIncomeRecord {
  id: string
  asset_id: string
  income_amount: number
  record_time: Date | string
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
  created_at: '' as string | Date
});

const incomeRecords = ref<AssetIncomeRecord[]>([]);

const goBack = () => {
  emit('navigate', 'asset');
};

const formatDate = (dateString: string | Date | undefined) => {
  if (!dateString) return '-';
  const date = new Date(dateString);
  return date.toLocaleString('zh-CN', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit'
  });
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

const actionButtons = [
  {
    text: '结束',
    icon: SwitchButton,
    action: handleEndAsset
  }
];

const loadIncomeRecords = async () => {
  // TODO: 从数据库加载收益记录
  // 目前使用模拟数据
  incomeRecords.value = [
    {
      id: '1',
      asset_id: props.assetId,
      income_amount: 150.00,
      record_time: '2026-04-10 10:30:00',
      remark: '4月收益'
    },
    {
      id: '2',
      asset_id: props.assetId,
      income_amount: 120.50,
      record_time: '2026-03-10 10:30:00',
      remark: '3月收益'
    }
  ];
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
      created_at: asset.created_at || ''
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
  flex-wrap: wrap;
  border-top: 1px solid #f0f0f0;
  padding-top: 15px;
  gap: 0;
}

.meta-item {
  flex: 1 1 50%;
  text-align: center;
  padding: 8px 0;
}

.meta-label {
  font-size: 12px;
  color: #666666;
  margin-bottom: 4px;
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