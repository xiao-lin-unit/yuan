<template>
  <PageTemplate :title="categoryName" @back="goBack">
    <div class="category-page">
      <div class="article-list">
        <div
          v-for="article in articles"
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
              <span v-if="article.isTop" class="top-badge">置顶</span>
            </div>
          </div>
          <el-icon class="arrow-icon"><ArrowRight /></el-icon>
        </div>
      </div>

      <div v-if="articles.length === 0" class="empty-state">
        <el-icon :size="48" color="#c0c4cc"><Document /></el-icon>
        <p>该分类暂无文章</p>
      </div>
    </div>
  </PageTemplate>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { ArrowRight, Document } from '@element-plus/icons-vue'
import PageTemplate from '../../common/PageTemplate.vue'
import {
  getCategories, getArticlesByCategory,
  isRead, type KnowledgeArticle
} from '../../../services/knowledge/knowledgeService.ts'

const props = defineProps<{
  categoryId: string
}>()

const emit = defineEmits(['navigate'])

const articles = ref<KnowledgeArticle[]>([])
const categoryName = ref('')
const readStatus = ref<Record<string, boolean>>({})

const goBack = () => {
  emit('navigate', 'knowledge')
}

const goToArticle = (articleId: string) => {
  emit('navigate', { key: 'knowledgeArticle', params: { articleId } })
}

onMounted(async () => {
  const categories = getCategories()
  const cat = categories.find(c => c.id === props.categoryId)
  categoryName.value = cat?.name || '分类列表'

  articles.value = getArticlesByCategory(props.categoryId)

  // 检查已读状态
  for (const article of articles.value) {
    readStatus.value[article.id] = await isRead(article.id)
  }
})
</script>

<style scoped>
.category-page {
  padding: 12px;
  min-height: 100%;
  background-color: #f5f7fa;
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

.top-badge {
  font-size: 11px;
  color: #e6a23c;
  background: #fdf6ec;
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
