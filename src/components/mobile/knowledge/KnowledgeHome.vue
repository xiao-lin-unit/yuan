<template>
  <div class="knowledge-home">
    <!-- 顶部标题 -->
    <div class="home-header">
      <h2>财商知识</h2>
      <div class="header-actions">
        <el-button size="small" circle @click="goToProfile">
          <el-icon><User /></el-icon>
        </el-button>
      </div>
    </div>

    <!-- 6大分类入口 -->
    <div class="category-grid">
      <div
        v-for="cat in categories"
        :key="cat.id"
        class="category-card"
        @click="goToCategory(cat.id)"
      >
        <div class="category-icon" :class="cat.icon">
          <el-icon :size="22">
            <component :is="getIcon(cat.icon)" />
          </el-icon>
        </div>
        <div class="category-name">{{ cat.name }}</div>
      </div>
    </div>

    <!-- 置顶推荐 -->
    <div class="section" v-if="topArticles.length > 0">
      <div class="section-header">
        <span class="section-title">置顶推荐</span>
      </div>
      <div class="article-list">
        <div
          v-for="article in topArticles"
          :key="article.id"
          class="article-card"
          @click="goToArticle(article.id)"
        >
          <div class="article-info">
            <h4 class="article-title">{{ article.title }}</h4>
            <p class="article-summary">{{ article.summary }}</p>
            <div class="article-meta">
              <span class="read-time">{{ article.readTime }}</span>
              <span v-if="readStatus[article.id]" class="read-badge">已读</span>
            </div>
          </div>
          <el-icon class="arrow-icon"><ArrowRight /></el-icon>
        </div>
      </div>
    </div>

    <!-- 最近阅读 -->
    <div class="section" v-if="recentArticles.length > 0">
      <div class="section-header">
        <span class="section-title">最近阅读</span>
      </div>
      <div class="article-list">
        <div
          v-for="article in recentArticles"
          :key="article.id"
          class="article-card"
          @click="goToArticle(article.id)"
        >
          <div class="article-info">
            <h4 class="article-title">{{ article.title }}</h4>
            <p class="article-summary">{{ article.summary }}</p>
            <div class="article-meta">
              <span class="read-time">{{ article.readTime }}</span>
              <span class="category-tag">{{ getCategoryName(article.categoryId) }}</span>
            </div>
          </div>
          <el-icon class="arrow-icon"><ArrowRight /></el-icon>
        </div>
      </div>
    </div>

    <!-- 空状态 -->
    <div v-if="topArticles.length === 0 && recentArticles.length === 0" class="empty-state">
      <el-icon :size="48" color="#c0c4cc"><Document /></el-icon>
      <p>暂无知识内容</p>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import {
  User, ArrowRight, Document,
  Wallet, Warning, TrendCharts,
  House, Lock, Reading
} from '@element-plus/icons-vue'
import {
  getCategories, getTopArticles, getArticles,
  getRecentReadArticleIds, type KnowledgeArticle
} from '../../../services/knowledge/knowledgeService.ts'

const emit = defineEmits(['navigate'])

const categories = ref(getCategories())
const topArticles = ref<KnowledgeArticle[]>([])
const recentArticles = ref<KnowledgeArticle[]>([])
const readStatus = ref<Record<string, boolean>>({})

const iconMap: Record<string, any> = {
  basic: Wallet,
  risk: Warning,
  invest: TrendCharts,
  decision: House,
  trap: Lock,
  book: Reading
}

const getIcon = (iconKey: string) => iconMap[iconKey] || Document

const getCategoryName = (categoryId: string) => {
  const cat = categories.value.find(c => c.id === categoryId)
  return cat?.name || ''
}

const goToCategory = (categoryId: string) => {
  emit('navigate', { key: 'knowledgeCategory', params: { categoryId } })
}

const goToArticle = (articleId: string) => {
  emit('navigate', { key: 'knowledgeArticle', params: { articleId } })
}

const goToProfile = () => {
  emit('navigate', { key: 'knowledgeProfile' })
}

onMounted(async () => {
  topArticles.value = getTopArticles()
  const allArticles = getArticles()

  const recentIds = await getRecentReadArticleIds(5)
  recentArticles.value = recentIds
    .map(id => allArticles.find(a => a.id === id))
    .filter(Boolean) as KnowledgeArticle[]
})
</script>

<style scoped>
.knowledge-home {
  padding: 12px;
  padding-bottom: 80px;
  min-height: 100%;
  background-color: #f5f7fa;
}

.home-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 16px;
}

.home-header h2 {
  margin: 0;
  font-size: 20px;
  color: #303133;
}

/* 分类网格 */
.category-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 10px;
  margin-bottom: 20px;
}

.category-card {
  background: #fff;
  border-radius: 12px;
  padding: 14px 8px;
  text-align: center;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.05);
  cursor: pointer;
  transition: all 0.2s ease;
}

.category-card:active {
  transform: scale(0.96);
}

.category-icon {
  width: 44px;
  height: 44px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  margin: 0 auto 8px;
}

.category-icon.basic { background: #ecf5ff; color: #409eff; }
.category-icon.risk { background: #fdf6ec; color: #e6a23c; }
.category-icon.invest { background: #f0f9eb; color: #67c23a; }
.category-icon.decision { background: #f4f4f5; color: #909399; }
.category-icon.trap { background: #fef0f0; color: #f56c6c; }
.category-icon.book { background: #f5f0ff; color: #9254de; }

.category-name {
  font-size: 13px;
  font-weight: 500;
  color: #303133;
}

/* 区块 */
.section {
  margin-bottom: 20px;
}

.section-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 10px;
}

.section-title {
  font-size: 16px;
  font-weight: 600;
  color: #303133;
}

/* 文章列表 */
.article-list {
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.article-card {
  background: #fff;
  border-radius: 10px;
  padding: 14px;
  display: flex;
  align-items: center;
  gap: 10px;
  box-shadow: 0 1px 4px rgba(0, 0, 0, 0.04);
  cursor: pointer;
  transition: all 0.2s ease;
}

.article-card:active {
  background: #f5f7fa;
}

.article-info {
  flex: 1;
  min-width: 0;
}

.article-title {
  margin: 0 0 6px 0;
  font-size: 15px;
  font-weight: 600;
  color: #303133;
  line-height: 1.4;
  overflow: hidden;
  text-overflow: ellipsis;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
}

.article-summary {
  margin: 0 0 8px 0;
  font-size: 12px;
  color: #909399;
  line-height: 1.4;
  overflow: hidden;
  text-overflow: ellipsis;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
}

.article-meta {
  display: flex;
  align-items: center;
  gap: 8px;
}

.read-time {
  font-size: 11px;
  color: #c0c4cc;
}

.read-badge {
  font-size: 11px;
  color: #67c23a;
  background: #f0f9eb;
  padding: 1px 6px;
  border-radius: 4px;
}

.category-tag {
  font-size: 11px;
  color: #409eff;
  background: #ecf5ff;
  padding: 1px 6px;
  border-radius: 4px;
}

.arrow-icon {
  color: #c0c4cc;
  flex-shrink: 0;
}

.empty-state {
  text-align: center;
  padding: 60px 20px;
  color: #c0c4cc;
}

.empty-state p {
  margin-top: 12px;
  font-size: 14px;
}
</style>
