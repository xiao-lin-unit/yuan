<template>
  <PageTemplate title="我的知识" @back="goBack">
    <div class="profile-page">
      <el-tabs v-model="activeTab" class="profile-tabs">
        <!-- 收藏列表 -->
        <el-tab-pane label="我的收藏" name="favorites">
          <div class="article-list" v-if="favoriteArticles.length > 0">
            <div
              v-for="article in favoriteArticles"
              :key="article.id"
              class="article-card"
              @click="goToArticle(article.id)"
            >
              <div class="article-info">
                <h4 class="article-title">{{ article.title }}</h4>
                <p class="article-summary">{{ article.summary }}</p>
                <div class="article-meta">
                  <span class="category-tag">{{ getCategoryName(article.categoryId) }}</span>
                  <span class="read-time">{{ article.readTime }}</span>
                </div>
              </div>
              <div class="article-actions">
                <el-button
                  size="small"
                  circle
                  type="warning"
                  @click.stop="removeFav(article.id)"
                >
                  <el-icon><StarFilled /></el-icon>
                </el-button>
              </div>
            </div>
          </div>
          <div v-else class="empty-state">
            <el-icon :size="48" color="#c0c4cc"><Star /></el-icon>
            <p>暂无收藏内容</p>
            <el-button type="primary" size="small" @click="goToKnowledge">去浏览</el-button>
          </div>
        </el-tab-pane>

        <!-- 阅读历史 -->
        <el-tab-pane label="阅读历史" name="history">
          <div class="history-header" v-if="historyList.length > 0">
            <el-button size="small" type="danger" plain @click="clearHistory">
              <el-icon><Delete /></el-icon>
              清空历史
            </el-button>
          </div>
          <div class="article-list" v-if="historyList.length > 0">
            <div
              v-for="item in historyList"
              :key="item.article.id"
              class="article-card"
              @click="goToArticle(item.article.id)"
            >
              <div class="article-info">
                <h4 class="article-title">{{ item.article.title }}</h4>
                <p class="article-summary">{{ item.article.summary }}</p>
                <div class="article-meta">
                  <span class="category-tag">{{ getCategoryName(item.article.categoryId) }}</span>
                  <span class="read-time">{{ item.readTime }}</span>
                </div>
              </div>
              <el-icon class="arrow-icon"><ArrowRight /></el-icon>
            </div>
          </div>
          <div v-else class="empty-state">
            <el-icon :size="48" color="#c0c4cc"><Clock /></el-icon>
            <p>暂无阅读记录</p>
            <el-button type="primary" size="small" @click="goToKnowledge">去浏览</el-button>
          </div>
        </el-tab-pane>
      </el-tabs>
    </div>
  </PageTemplate>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import {
  Star, StarFilled, ArrowRight, Delete, Clock
} from '@element-plus/icons-vue'
import PageTemplate from '../../common/PageTemplate.vue'
import {
  getFavorites, removeFavorite, getReadHistory, clearReadHistory,
  getArticles, getCategories, type KnowledgeArticle
} from '../../../services/knowledge/knowledgeService.ts'

const emit = defineEmits(['navigate'])

const activeTab = ref('favorites')
const favoriteArticles = ref<KnowledgeArticle[]>([])
const historyList = ref<{ article: KnowledgeArticle; readTime: string }[]>([])

const allArticles = ref<KnowledgeArticle[]>([])
const categories = ref(getCategories())

const getCategoryName = (categoryId: string) => {
  const cat = categories.value.find(c => c.id === categoryId)
  return cat?.name || ''
}

const goBack = () => {
  emit('navigate', 'knowledge')
}

const goToArticle = (articleId: string) => {
  emit('navigate', { key: 'knowledgeArticle', params: { articleId } })
}

const goToKnowledge = () => {
  emit('navigate', 'knowledge')
}

const removeFav = async (articleId: string) => {
  await removeFavorite(articleId)
  favoriteArticles.value = favoriteArticles.value.filter(a => a.id !== articleId)
}

const clearHistory = async () => {
  try {
    await clearReadHistory()
    historyList.value = []
  } catch (e) {
    console.error('Clear history failed:', e)
  }
}

onMounted(async () => {
  allArticles.value = getArticles()

  // 加载收藏
  const favIds = await getFavorites()
  favoriteArticles.value = favIds
    .map(id => allArticles.value.find(a => a.id === id))
    .filter(Boolean) as KnowledgeArticle[]

  // 加载历史
  const history = await getReadHistory()
  historyList.value = history
    .map(h => {
      const article = allArticles.value.find(a => a.id === h.articleId)
      return article ? { article, readTime: h.readTime } : null
    })
    .filter(Boolean) as { article: KnowledgeArticle; readTime: string }[]
})
</script>

<style scoped>
.profile-page {
  background-color: #f5f7fa;
  min-height: 100%;
}

.profile-tabs :deep(.el-tabs__header) {
  margin-bottom: 0;
  background: #fff;
  padding: 0 12px;
}

.profile-tabs :deep(.el-tabs__content) {
  padding: 12px;
}

.history-header {
  display: flex;
  justify-content: flex-end;
  margin-bottom: 12px;
}

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

.category-tag {
  font-size: 11px;
  color: #409eff;
  background: #ecf5ff;
  padding: 1px 6px;
  border-radius: 4px;
}

.read-time {
  font-size: 11px;
  color: #c0c4cc;
}

.article-actions {
  flex-shrink: 0;
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
  margin: 12px 0 16px 0;
  font-size: 14px;
}
</style>
