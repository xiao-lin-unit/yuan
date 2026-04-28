<template>
  <div class="liability-page">
    <!-- 顶部导航栏 -->
    <div class="top-nav-bar">
      <div class="nav-title"></div>
      <div class="top-icons">
        <el-input
          v-if="isSearchExpanded"
          v-model="searchKeyword"
          class="search-input"
          placeholder="请输入名称"
          clearable
          @blur="onSearchBlur"
        />
        <el-icon class="nav-icon" @click="toggleSearch"><Search /></el-icon>
      </div>
    </div>

    <StatOverview
      v-if="!showSettled"
      :background="image"
      :main="[{title: '剩余待还', value: '￥' + totalRemaining.toFixed(2), color: undefined}]"
      :details="[{title: '剩余本金', value: '￥' + totalPrincipal.toFixed(2), color: undefined}, {title: '负债笔数', value: displayLiabilities.length, color: undefined}]"
    />

    <!-- 负债卡片容器 -->
    <div class="liability-cards-container" :style="{ 'margin-top': !showSettled ? '0' : '20px' }">
      <div v-if="displayLiabilities.length === 0" class="no-liabilities">
        <el-empty :description="showSettled ? '暂无历史负债' : '暂无负债'" />
      </div>
      <template v-else>
        <LiabilityCard
          v-for="liability in displayLiabilities"
          :key="liability.id"
          :title="liability.name"
          :type="liability.type"
          :principal="liability.principal"
          :remaining="liability.remaining_principal"
          :remaining-interest="liability.remaining_total_interest"
          :interest-rate="liability.interest_rate"
          :repayment-method="liability.repayment_method"
          :status="liability.status"
          :color="getLiabilityColor(liability.type)"
          :liability-id="liability.id"
          @click="viewLiabilityDetail"
        />
      </template>
    </div>

    <!-- 切换当前/历史负债按钮 -->
    <div class="toggle-liabilities-button" @click="toggleLiabilitiesView">
      <el-icon style="color: white;"><Switch /></el-icon>
      <span class="toggle-text">{{ showSettled ? '当前负债' : '历史负债' }}</span>
    </div>

    <!-- 浮动操作按钮 -->
    <!-- <div class="floating-action-button" v-if="!showSettled" @click="navigateToAddLiability">
      <el-icon style="color: white;"><Plus /></el-icon>
    </div> -->
    <FloatingActionMenu :buttons="actionButtons" />
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, computed } from 'vue';
import { Plus, Switch, Search } from '@element-plus/icons-vue';
import LiabilityCard from './LiabilityCard.vue';
import { getLiabilities } from '../../../services/liability/liabilityService';
import type { Liability } from '../../../types/liability/liability';
import FloatingActionMenu from '../../../components/common/FloatingActionMenu.vue';
import StatOverview from '../../../components/common/StatOverview.vue';
import image from '@/assets/img/m1.jpg';

const emit = defineEmits(['navigate']);

const liabilities = ref<Liability[]>([]);
const showSettled = ref(false);

// 搜索
const isSearchExpanded = ref(false);
const searchKeyword = ref('');

const toggleSearch = () => {
  isSearchExpanded.value = !isSearchExpanded.value;
};

const onSearchBlur = () => {
  if (!searchKeyword.value.trim()) {
    isSearchExpanded.value = false;
  }
};

const displayLiabilities = computed(() => {
  let list = liabilities.value.filter(liability => {
    const isSettled = liability.status === '已结清';
    return showSettled.value ? isSettled : !isSettled;
  });
  if (searchKeyword.value.trim()) {
    list = list.filter(liability => liability.name.includes(searchKeyword.value.trim()));
  }
  return list;
});

const totalPrincipal = computed(() => {
  return displayLiabilities.value.reduce((sum, l) => sum + l.remaining_principal, 0);
});

const totalRemaining = computed(() => {
  return displayLiabilities.value.reduce((sum, l) => sum + l.remaining_principal + l.remaining_total_interest, 0);
});

const actionButtons = computed(() => {
  const buttons = [
    {
      text: '新增',
      icon: Plus,
      action: navigateToAddLiability
    }
  ];
  return buttons;
});

const liabilityColorMap: Record<string, string> = {
  '房贷': '#ff6b6b',
  '车贷': '#ff9f43',
  '信用卡': '#ee5253',
  '消费贷': '#ff6348',
  '装修贷': '#e67e22',
  '助学贷款': '#f39c12',
  '网贷': '#e74c3c',
  '电商分期': '#d35400',
  '租金分期': '#e67e22',
  '亲友借款': '#c0392b',
  '经营贷': '#a0522d',
  '其他负债': '#7f8c8d'
};

const getLiabilityColor = (type: string) => {
  return liabilityColorMap[type] || '#ff6b6b';
};

const toggleLiabilitiesView = () => {
  showSettled.value = !showSettled.value;
};

const navigateToAddLiability = () => {
  emit('navigate', { key: 'addLiability' });
};

const viewLiabilityDetail = (liabilityId: string) => {
  emit('navigate', { key: 'liabilityDetail', params: { liabilityId } });
};

const loadLiabilityData = async () => {
  try {
    liabilities.value = await getLiabilities();
  } catch (error) {
    console.error('加载负债数据失败:', error);
    // 加载失败时使用模拟数据
    liabilities.value = [
      {
        id: '1',
        name: '招商银行房贷',
        type: '房贷',
        principal: 1000000,
        remaining_principal: 950000,
        remaining_total_interest: 85000,
        is_interest: true,
        interest_rate: 0.049,
        start_date: '2024-01-01',
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
        remaining_total_interest: 0,
        is_interest: false,
        interest_rate: 0,
        start_date: '2024-03-01',
        repayment_method: '随借随还',
        account_id: '2',
        remark: '临时周转',
        status: '未结清'
      }
    ];
  }
};

onMounted(() => {
  loadLiabilityData();
});
</script>

<style scoped>
.liability-page {
  padding: 0;
  background-color: #f5f7fa;
  overflow-y: auto;
  overflow-x: hidden;
  height: 100%;
  min-height: 100%;
}

/* 隐藏滚动条但保留滚动功能 */
.liability-page::-webkit-scrollbar {
  display: none;
}

.liability-page {
  -ms-overflow-style: none;
  scrollbar-width: none;
}

/* 顶部导航栏 */
.top-nav-bar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  height: 50px;
  padding: 0 15px;
  background-color: white;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
}

.nav-title {
  font-size: 16px;
  font-weight: bold;
  color: #303133;
}

.top-icons {
  display: flex;
  align-items: center;
  gap: 8px;
}

.nav-icon {
  font-size: 18px;
  color: #606266;
  cursor: pointer;
}

.search-input {
  width: 140px;
}

.search-input :deep(.el-input__inner) {
  height: 32px;
}

.liability-cards-container {
  padding: 0 16px 10px;
  display: grid;
  grid-template-columns: 1fr;
  gap: 10px;
}

.no-liabilities {
  grid-column: 1 / -1;
  display: flex;
  justify-content: center;
  align-items: center;
  min-height: 50vh;
  background-color: #ffffff;
  border-radius: 8px;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
}

/* 切换负债按钮 */
.toggle-liabilities-button {
  position: fixed;
  bottom: 80px;
  left: 20px;
  z-index: 1000;
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 12px 16px;
  background-color: #67c23a;
  border-radius: 24px;
  box-shadow: 0 4px 12px rgba(103, 194, 58, 0.5);
  cursor: pointer;
  transition: all 0.3s ease;
}

.toggle-liabilities-button:hover {
  transform: scale(1.05);
  box-shadow: 0 6px 16px rgba(103, 194, 58, 0.5);
}

.toggle-text {
  color: white;
  font-size: 14px;
  font-weight: 500;
}

/* 响应式调整 */
@media (min-width: 768px) {
  .liability-cards-container {
    grid-template-columns: repeat(2, 1fr);
  }
}

@media (min-width: 1024px) {
  .liability-cards-container {
    grid-template-columns: repeat(3, 1fr);
  }
}
</style>
