<template>
  <div class="financial-knowledge">
    <el-card>
      <template #header>
        <div class="card-header">
          <span>财商知识</span>
        </div>
      </template>
      
      <el-tabs v-model="activeTab">
        <el-tab-pane label="书籍精华" name="books">
          <div class="knowledge-list">
            <el-card v-for="book in books" :key="book.id" class="knowledge-item">
              <h3>{{ book.title }}</h3>
              <p class="author">{{ book.author }}</p>
              <div class="content">{{ book.content }}</div>
              <div class="actions">
                <el-button size="small" @click="toggleFavorite(book.id)">
                  <el-icon v-if="book.isFavorite"><StarFilled /></el-icon>
                  <el-icon v-else><Star /></el-icon>
                  {{ book.isFavorite ? '已收藏' : '收藏' }}
                </el-button>
              </div>
            </el-card>
          </div>
        </el-tab-pane>
        
        <el-tab-pane label="科普内容" name="science">
          <div class="knowledge-list">
            <el-card v-for="article in scienceArticles" :key="article.id" class="knowledge-item">
              <h3>{{ article.title }}</h3>
              <div class="content">{{ article.content }}</div>
              <div class="actions">
                <el-button size="small" @click="toggleFavorite(article.id)">
                  <el-icon v-if="article.isFavorite"><StarFilled /></el-icon>
                  <el-icon v-else><Star /></el-icon>
                  {{ article.isFavorite ? '已收藏' : '收藏' }}
                </el-button>
              </div>
            </el-card>
          </div>
        </el-tab-pane>
        
        <el-tab-pane label="观点内容" name="opinions">
          <div class="knowledge-list">
            <el-card v-for="opinion in opinions" :key="opinion.id" class="knowledge-item">
              <h3>{{ opinion.title }}</h3>
              <div class="content">{{ opinion.content }}</div>
              <div class="actions">
                <el-button size="small" @click="toggleFavorite(opinion.id)">
                  <el-icon v-if="opinion.isFavorite"><StarFilled /></el-icon>
                  <el-icon v-else><Star /></el-icon>
                  {{ opinion.isFavorite ? '已收藏' : '收藏' }}
                </el-button>
              </div>
            </el-card>
          </div>
        </el-tab-pane>
        
        <el-tab-pane label="低费率教育" name="fees">
          <div class="knowledge-list">
            <el-card v-for="fee in feeArticles" :key="fee.id" class="knowledge-item">
              <h3>{{ fee.title }}</h3>
              <div class="content">{{ fee.content }}</div>
              <div class="actions">
                <el-button size="small" @click="toggleFavorite(fee.id)">
                  <el-icon v-if="fee.isFavorite"><StarFilled /></el-icon>
                  <el-icon v-else><Star /></el-icon>
                  {{ fee.isFavorite ? '已收藏' : '收藏' }}
                </el-button>
              </div>
            </el-card>
          </div>
        </el-tab-pane>
        
        <el-tab-pane label="基础术语" name="terms">
          <div class="knowledge-list">
            <el-card v-for="term in terms" :key="term.id" class="knowledge-item">
              <h3>{{ term.term }}</h3>
              <div class="content">{{ term.definition }}</div>
            </el-card>
          </div>
        </el-tab-pane>
        
        <el-tab-pane label="我的收藏" name="favorites">
          <div class="knowledge-list">
            <el-card v-for="item in favoriteItems" :key="item.id" class="knowledge-item">
              <h3>{{ item.title || item.term }}</h3>
              <div class="content">{{ item.content || item.definition }}</div>
              <div class="actions">
                <el-button size="small" @click="toggleFavorite(item.id)">
                  <el-icon><StarFilled /></el-icon>
                  取消收藏
                </el-button>
              </div>
            </el-card>
            <div v-if="favoriteItems.length === 0" class="empty-state">
              暂无收藏内容
            </div>
          </div>
        </el-tab-pane>
      </el-tabs>
    </el-card>
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { Star, StarFilled } from '@element-plus/icons-vue'

const activeTab = ref('books')

const books = ref([
  {
    id: '1',
    title: '穷爸爸富爸爸',
    author: '罗伯特·清崎',
    content: '富人买入资产，穷人只有支出，中产阶级买入他们以为是资产的负债。',
    isFavorite: false
  },
  {
    id: '2',
    title: '小狗钱钱',
    author: '博多·舍费尔',
    content: '如果你想变得富有，你需要学会储蓄和投资，让钱为你工作。',
    isFavorite: false
  }
])

const scienceArticles = ref([
  {
    id: '3',
    title: '现金流管理的重要性',
    content: '现金流是财务健康的核心指标，正数现金流能让你有更多机会投资和积累财富。',
    isFavorite: false
  },
  {
    id: '4',
    title: '负债优化策略',
    content: '高利率负债应优先偿还，合理利用低利率负债可以提高资金使用效率。',
    isFavorite: false
  }
])

const opinions = ref([
  {
    id: '5',
    title: '长期投资的力量',
    content: '复利是第八大奇迹，长期投资能让你的资产实现指数级增长。',
    isFavorite: false
  },
  {
    id: '6',
    title: '风险与收益的平衡',
    content: '投资需要在风险和收益之间找到平衡，分散投资是降低风险的有效方法。',
    isFavorite: false
  }
])

const feeArticles = ref([
  {
    id: '7',
    title: '基金手续费对比',
    content: '不同基金的申购、赎回费率差异很大，长期投资中手续费对收益的影响不可忽视。',
    isFavorite: false
  },
  {
    id: '8',
    title: '股票交易成本分析',
    content: '频繁交易的成本会吞噬大量收益，长期持有策略可以有效降低交易成本。',
    isFavorite: false
  }
])

const terms = ref([
  {
    id: '9',
    term: '成本价',
    definition: '投资的平均成本，计算方式为总投入金额除以总持有数量。'
  },
  {
    id: '10',
    term: '净值',
    definition: '基金单位份额的价值，等于基金资产总值减去负债后的余额除以总份额。'
  },
  {
    id: '11',
    term: '等额本息',
    definition: '贷款还款方式，每月还款额固定，其中利息比例逐渐减少，本金比例逐渐增加。'
  },
  {
    id: '12',
    term: '年化利率',
    definition: '将短期利率转换为年度利率的计算方式，便于比较不同期限的投资收益。'
  },
  {
    id: '13',
    term: '净资产',
    definition: '总资产减去总负债的差额，反映个人或企业的实际财富水平。'
  }
])

const favoriteItems = computed(() => {
  const allItems = [...books.value, ...scienceArticles.value, ...opinions.value, ...feeArticles.value]
  return allItems.filter(item => item.isFavorite)
})

const toggleFavorite = (id: string) => {
  const allItems = [...books.value, ...scienceArticles.value, ...opinions.value, ...feeArticles.value]
  const item = allItems.find(item => item.id === id)
  if (item) {
    item.isFavorite = !item.isFavorite
  }
}
</script>

<style scoped>
.financial-knowledge {
  padding: 0;
}

.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.knowledge-list {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
  gap: 20px;
  margin-top: 20px;
}

.knowledge-item {
  transition: all 0.3s ease;
}

.knowledge-item:hover {
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
}

.knowledge-item h3 {
  margin: 0 0 10px 0;
  font-size: 16px;
  color: #303133;
}

.knowledge-item .author {
  margin: 0 0 15px 0;
  font-size: 14px;
  color: #909399;
}

.knowledge-item .content {
  margin: 0 0 20px 0;
  font-size: 14px;
  line-height: 1.5;
  color: #606266;
}

.knowledge-item .actions {
  display: flex;
  justify-content: flex-end;
}

.empty-state {
  grid-column: 1 / -1;
  text-align: center;
  padding: 40px;
  color: #909399;
  background-color: #f5f7fa;
  border-radius: 8px;
}
</style>