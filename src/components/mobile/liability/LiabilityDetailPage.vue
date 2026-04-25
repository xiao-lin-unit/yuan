<template>
  <div class="liability-detail-page">
    <!-- 顶部导航栏 -->
    <div class="liability-detail-header">
      <div class="header-left" @click="goBack">
        <el-icon><ArrowLeft /></el-icon>
      </div>
      <h1 class="header-title">负债详情</h1>
      <div class="header-right"></div>
    </div>

    <!-- 负债基本信息 -->
    <div class="liability-basic-info">
      <h2 class="liability-name">{{ liabilityInfo.name }}</h2>
      <div class="liability-type-row">
        <span class="liability-type-tag">{{ liabilityInfo.type }}</span>
        <span v-if="liabilityInfo.status === '已结清'" class="liability-status-tag settled">已结清</span>
        <span v-else class="liability-status-tag unsettled">未结清</span>
      </div>
      <div class="liability-amount">
        <div class="amount-label">剩余待还(元)</div>
        <div class="amount-value">¥{{ (liabilityInfo.remaining_principal + liabilityInfo.remaining_total_interest).toFixed(2) }}</div>
      </div>
      <div class="liability-meta">
        <div class="meta-item">
          <div class="meta-label">负债本金</div>
          <div class="meta-value">¥{{ liabilityInfo.principal.toFixed(2) }}</div>
        </div>
        <div class="meta-item">
          <div class="meta-label">剩余本金</div>
          <div class="meta-value">¥{{ liabilityInfo.remaining_principal.toFixed(2) }}</div>
        </div>
        <div class="meta-item" v-if="liabilityInfo.is_interest">
          <div class="meta-label">年化利率</div>
          <div class="meta-value">{{ (liabilityInfo.interest_rate * 100).toFixed(2) }}%</div>
        </div>
      </div>
      <div class="liability-meta">
        <div class="meta-item">
          <div class="meta-label">还款方式</div>
          <div class="meta-value">{{ liabilityInfo.repayment_method }}</div>
        </div>
        <div class="meta-item" v-if="liabilityInfo.repayment_day">
          <div class="meta-label">还款日</div>
          <div class="meta-value">每月{{ liabilityInfo.repayment_day }}日</div>
        </div>
        <div class="meta-item" v-if="liabilityInfo.period">
          <div class="meta-label">期数</div>
          <div class="meta-value">{{ liabilityInfo.period }}期</div>
        </div>
      </div>
      <div class="liability-meta">
        <div class="meta-item" v-if="liabilityInfo.is_interest">
          <div class="meta-label">剩余利息</div>
          <div class="meta-value">¥{{ liabilityInfo.remaining_total_interest.toFixed(2) }}</div>
        </div>
        <div class="meta-item">
          <div class="meta-label">借款日期</div>
          <div class="meta-value">{{ formatDate(liabilityInfo.start_date) }}</div>
        </div>
      </div>
      <div class="progress-section" v-if="liabilityInfo.principal > 0">
        <div class="progress-bar">
          <div class="progress-fill" :style="{ width: progressPercent + '%' }"></div>
        </div>
        <div class="progress-text">
          已还 {{ ((liabilityInfo.principal - liabilityInfo.remaining_principal) / liabilityInfo.principal * 100).toFixed(1) }}%
          （¥{{ (liabilityInfo.principal - liabilityInfo.remaining_principal).toFixed(2) }} / ¥{{ liabilityInfo.principal.toFixed(2) }}）
        </div>
      </div>
    </div>

    <!-- 还款与待还记录明细 -->
    <div class="liability-transactions">
      <el-tabs v-model="activeTag" class="transaction-tabs" type="card">
        <!-- 待还记录 -->
        <el-tab-pane label="待还记录" name="pending" v-if="liabilityInfo.status !== '已结清' && liabilityInfo.repayment_method !== '随借随还'">
          <div class="transaction-list">
            <div v-if="pendingRepayments.length === 0" class="no-transactions">
              <el-empty description="暂无待还记录" />
            </div>
            <div v-else>
              <div v-for="pending in pendingRepayments" :key="pending.id" class="transaction-card">
                <div class="transaction-header">
                  <div class="transaction-type pending">第{{ pending.period_number }}期</div>
                  <div class="transaction-date">{{ formatDate(pending.due_date) }}到期</div>
                </div>
                <div class="transaction-content">
                  <div class="transaction-item">
                    <span class="item-label">应还总额</span>
                    <span class="item-value">¥{{ (pending.total_amount || 0).toFixed(2) }}</span>
                  </div>
                  <div class="transaction-item">
                    <span class="item-label">本金</span>
                    <span class="item-value">¥{{ (pending.principal_amount || 0).toFixed(2) }}</span>
                  </div>
                  <div class="transaction-item">
                    <span class="item-label">利息</span>
                    <span class="item-value">¥{{ (pending.interest_amount || 0).toFixed(2) }}</span>
                  </div>
                  <div class="transaction-item">
                    <span class="item-label">到期日</span>
                    <span class="item-value">{{ formatDate(pending.due_date) }}</span>
                  </div>
                  <div class="transaction-item">
                    <span class="item-label">状态</span>
                    <span class="item-value" :style="{color: pending.status === '未还' ? '#ff6b6b' : (pending.status === '已还' ? '#67c23a' : '#666666')}">{{ pending.status }}</span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </el-tab-pane>

        <!-- 还款记录 -->
        <el-tab-pane label="还款记录" name="repayments">
          <div class="transaction-list">
            <div v-if="repayments.length === 0" class="no-transactions">
              <el-empty description="暂无还款记录" />
            </div>
            <div v-else>
              <div v-for="repayment in repayments" :key="repayment.id" class="transaction-card">
                <div class="transaction-header">
                  <div class="transaction-type" :class="repayment.type === '提前还款' ? 'early' : 'normal'">
                    {{ repayment.type }}
                  </div>
                  <div class="transaction-date">{{ formatDate(repayment.repayment_time) }}</div>
                </div>
                <div class="transaction-content">
                  <div class="transaction-item">
                    <span class="item-label">还款金额</span>
                    <span class="item-value">¥{{ (repayment.amount || 0).toFixed(2) }}</span>
                  </div>
                  <div class="transaction-item">
                    <span class="item-label">还本金</span>
                    <span class="item-value">¥{{ (repayment.principal_amount || 0).toFixed(2) }}</span>
                  </div>
                  <div class="transaction-item">
                    <span class="item-label">还利息</span>
                    <span class="item-value">¥{{ (repayment.interest_amount || 0).toFixed(2) }}</span>
                  </div>
                  <div class="transaction-item" v-if="repayment.remark">
                    <span class="item-label">备注</span>
                    <span class="item-value">{{ repayment.remark }}</span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </el-tab-pane>
      </el-tabs>
    </div>

    <!-- 悬浮操作按钮 -->
    <FloatingActionMenu v-if="liabilityInfo.status !== '已结清'" :buttons="actionButtons" />

    <!-- 还款对话框 -->
    <el-dialog v-model="repayDialogVisible" title="还款" width="90%">
      <el-form :model="repayForm" label-width="80px">
        <el-form-item label="还款金额" required>
          <el-input v-model.number="repayForm.amount" placeholder="请输入还款金额" type="number" min="0" step="0.01" />
        </el-form-item>
        <el-form-item label="还款类型">
          <el-select v-model="repayForm.type" placeholder="请选择还款类型">
            <el-option v-for="item in repaymentTypes" :key="item.value" :label="item.label" :value="item.value" />
          </el-select>
        </el-form-item>
        <el-form-item label="备注">
          <el-input v-model="repayForm.remark" placeholder="请输入备注" />
        </el-form-item>
      </el-form>
      <template #footer>
        <span class="dialog-footer">
          <el-button @click="repayDialogVisible = false">取消</el-button>
          <el-button type="primary" @click="confirmRepayment">确定</el-button>
        </span>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, computed } from 'vue';
import dayjs from 'dayjs';
import { ArrowLeft, Money, Delete } from '@element-plus/icons-vue';
import { ElMessageBox, ElMessage } from 'element-plus';
import FloatingActionMenu from '../../../components/common/FloatingActionMenu.vue';
import {
  getLiabilityById,
  getRepayments,
  getPendingRepayments,
  makeRepayment,
  deleteLiability
} from '../../../services/liability/liabilityService';
import { repaymentTypes } from '../../../utils/dictionaries';
import type { Liability, Repayment, PendingRepayment } from '../../../types/liability/liability';

const props = defineProps({
  liabilityId: {
    type: String,
    required: true
  }
});

const emit = defineEmits(['navigate']);

const liabilityInfo = ref<Liability>({
  id: '',
  name: '',
  type: '',
  principal: 0,
  remaining_principal: 0,
  remaining_total_interest: 0,
  is_interest: false,
  interest_rate: 0,
  start_date: '',
  repayment_method: '',
  repayment_day: undefined,
  period: undefined,
  account_id: '',
  remark: '',
  status: '未结清'
});

const repayments = ref<Repayment[]>([]);
const pendingRepayments = ref<PendingRepayment[]>([]);
const repayDialogVisible = ref(false);
const activeTag = ref('pending');

const repayForm = ref({
  amount: 0,
  type: '正常还款',
  remark: ''
});

const progressPercent = computed(() => {
  const p = liabilityInfo.value.principal;
  const r = liabilityInfo.value.remaining_principal;
  if (p <= 0) return 0;
  return Math.min(100, Math.max(0, ((p - r) / p) * 100));
});

const goBack = () => {
  emit('navigate', 'liability');
};

const formatDate = (dateValue: string | dayjs.Dayjs | undefined) => {
  if (!dateValue) return '-';
  return dayjs(dateValue).format('YYYY/MM/DD');
};

const openRepayDialog = () => {
  repayForm.value = {
    amount: 0,
    type: '正常还款',
    remark: ''
  };
  repayDialogVisible.value = true;
};

const confirmRepayment = async () => {
  if (!repayForm.value.amount || repayForm.value.amount <= 0) {
    alert('请输入有效的还款金额');
    return;
  }
  if (repayForm.value.amount > liabilityInfo.value.remaining_principal) {
    alert('还款金额不能超过剩余本金');
    return;
  }

  try {
    await makeRepayment({
      liabilityId: props.liabilityId,
      amount: repayForm.value.amount,
      type: repayForm.value.type as '正常还款' | '提前还款',
      remark: repayForm.value.remark
    });
    ElMessage.success('还款成功');
    repayDialogVisible.value = false;
    await loadLiabilityDetail();
  } catch (error: any) {
    console.error('还款失败:', error);
    ElMessage.error(error.message || '还款失败');
  }
};

const loadPendingRepayments = async () => {
  try {
    pendingRepayments.value = await getPendingRepayments(props.liabilityId);
  } catch (error) {
    console.error('加载待还记录失败:', error);
  }
};

const handleDelete = async () => {
  try {
    await ElMessageBox.confirm(
      `确定要删除负债"${liabilityInfo.value.name}"吗？`,
      '删除负债',
      {
        confirmButtonText: '确认删除',
        cancelButtonText: '取消',
        type: 'warning'
      }
    );
    await deleteLiability(props.liabilityId);
    ElMessage.success('负债已删除');
    emit('navigate', 'liability');
  } catch (error: any) {
    if (error !== 'cancel') {
      console.error('删除负债失败:', error);
      ElMessage.error(error.message || '删除失败');
    }
  }
};

const actionButtons = [
  {
    text: '还款',
    icon: Money,
    action: openRepayDialog
  },
  {
    text: '删除',
    icon: Delete,
    action: handleDelete
  }
];

const loadLiabilityDetail = async () => {
  try {
    const liability = await getLiabilityById(props.liabilityId);
    if (liability) {
      liabilityInfo.value = liability;
      repayments.value = await getRepayments(props.liabilityId);
      await loadPendingRepayments();
    } else {
      ElMessage.error('未找到该负债');
      emit('navigate', 'liability');
    }
  } catch (error) {
    console.error('加载负债详情失败:', error);
    ElMessage.error('加载负债详情失败');
  }
};

onMounted(() => {
  loadLiabilityDetail();
});
</script>

<style scoped>
.liability-detail-page {
  height: 100%;
  background-color: #f5f7fa;
  display: flex;
  flex-direction: column;
  overflow-y: auto;
}

/* 顶部导航栏 */
.liability-detail-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 15px;
  background-color: #ffffff;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
  flex-shrink: 0;
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

/* 负债基本信息 */
.liability-basic-info {
  padding: 16px 20px;
  background-color: #ffffff;
  margin-bottom: 10px;
  flex-shrink: 0;
}

.liability-name {
  font-size: 18px;
  font-weight: 600;
  color: #333333;
  margin: 0 0 10px 0;
}

.liability-type-row {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 20px;
}

.liability-type-tag {
  font-size: 13px;
  color: #ff6b6b;
  background-color: #fff5f5;
  padding: 2px 10px;
  border-radius: 10px;
}

.liability-status-tag {
  font-size: 12px;
  padding: 2px 8px;
  border-radius: 10px;
}

.liability-status-tag.settled {
  color: #67c23a;
  background-color: #f0f9eb;
}

.liability-status-tag.unsettled {
  color: #e6a23c;
  background-color: #fdf6ec;
}

.liability-amount {
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
  color: #ff6b6b;
}

.liability-meta {
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

.progress-section {
  margin-top: 15px;
  padding-top: 15px;
  border-top: 1px solid #f0f0f0;
}

.progress-bar {
  height: 6px;
  background-color: #f0f0f0;
  border-radius: 3px;
  overflow: hidden;
  margin-bottom: 8px;
}

.progress-fill {
  height: 100%;
  background: linear-gradient(90deg, #ff6b6b, #ffa07a);
  border-radius: 3px;
  transition: width 0.3s ease;
}

.progress-text {
  font-size: 12px;
  color: #666666;
  text-align: center;
}

/* 还款与待还记录明细 */
.liability-transactions {
  padding: 15px;
  background-color: #ffffff;
  margin-bottom: 80px;
  flex-shrink: 0;
}

/* Tab样式 */
.transaction-tabs {
  margin-bottom: 15px;
}

.transaction-tabs :deep(.el-tabs__nav) {
  width: 100%;
  display: flex;
}

.transaction-tabs :deep(.el-tabs__item) {
  flex: 1;
  text-align: center;
}

.no-transactions {
  padding: 20px 0;
  text-align: center;
}

.transaction-list {
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.transaction-card {
  background-color: #f9f9f9;
  border-radius: 8px;
  padding: 15px;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.05);
}

.transaction-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 10px;
  padding-bottom: 10px;
  border-bottom: 1px solid #f0f0f0;
}

.transaction-type {
  padding: 2px 8px;
  border-radius: 10px;
  font-size: 12px;
  font-weight: 600;
}

.transaction-type.pending {
  background-color: #fff7e6;
  color: #fa8c16;
}

.transaction-type.normal {
  background-color: #e6f7ff;
  color: #1890ff;
}

.transaction-type.early {
  background-color: #fff1f0;
  color: #ff4d4f;
}

.transaction-date {
  font-size: 12px;
  color: #999999;
}

.transaction-content {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.transaction-item {
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

.dialog-footer {
  display: flex;
  justify-content: flex-end;
  gap: 10px;
}
</style>
