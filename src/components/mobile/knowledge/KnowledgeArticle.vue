<template>
  <PageTemplate :title="article?.title || '文章详情'" @back="goBack" ref="contentRef" @scroll="handleScroll">
    <div class="article-page" v-if="article">
      <!-- 文章头部信息 -->
      <div class="article-header">
        <h1 class="article-title">{{ article.title }}</h1>
        <div class="article-meta">
          <span class="category">{{ categoryName }}</span>
          <span class="read-time">{{ article.readTime }}</span>
          <span class="date">{{ article.createTime }}</span>
        </div>
        <div v-if="article.bookInfo" class="book-info">
          <el-tag size="small" type="warning">书籍</el-tag>
          <span>{{ article.bookInfo.author }}《{{ article.bookInfo.bookName }}》</span>
        </div>
      </div>

      <!-- 核心要点 -->
      <div v-if="article.corePoints?.length" class="core-points">
        <div class="section-label">核心要点</div>
        <ul>
          <li v-for="(point, idx) in article.corePoints" :key="idx">{{ point }}</li>
        </ul>
      </div>

      <!-- Markdown 内容 -->
      <div class="markdown-content" v-html="renderedContent"></div>

      <!-- 联动APP提示 -->
      <div v-if="article.relatedPage" class="related-action">
        <div class="section-label">联动APP功能</div>
        <div class="action-card" @click="goToRelatedPage">
          <el-icon :size="20" color="#409eff"><Link /></el-icon>
          <div class="action-info">
            <div class="action-title">{{ relatedPageTitle }}</div>
            <div class="action-desc">点击跳转至{{ relatedPageTitle }}，将知识转化为实际行动</div>
          </div>
          <el-icon class="arrow"><ArrowRight /></el-icon>
        </div>
      </div>

      <!-- 上下篇导航 -->
      <div class="article-nav">
        <div
          v-if="prevArticle"
          class="nav-card prev"
          @click="goToArticle(prevArticle.id)"
        >
          <el-icon><ArrowLeft /></el-icon>
          <div class="nav-info">
            <div class="nav-label">上一篇</div>
            <div class="nav-title">{{ prevArticle.title }}</div>
          </div>
        </div>
        <div
          v-if="nextArticle"
          class="nav-card next"
          @click="goToArticle(nextArticle.id)"
        >
          <div class="nav-info">
            <div class="nav-label">下一篇</div>
            <div class="nav-title">{{ nextArticle.title }}</div>
          </div>
          <el-icon><ArrowRight /></el-icon>
        </div>
      </div>

      <!-- 底部占位 -->
      <div style="height: 20px;"></div>
    </div>

    <!-- 回到顶部按钮 -->
    <transition name="fade">
      <div v-if="showBackToTop" class="back-to-top" @click="backToTop">
        <el-icon :size="20"><Top /></el-icon>
      </div>
    </transition>

    <!-- 底部操作栏 -->
    <div class="article-actions" v-if="article">
      <div class="action-btn" :class="{ active: isFav }" @click="toggleFavorite">
        <el-icon :size="20">
          <StarFilled v-if="isFav" />
          <Star v-else />
        </el-icon>
        <span>{{ isFav ? '已收藏' : '收藏' }}</span>
      </div>
      <div class="action-btn" @click="shareArticle">
        <el-icon :size="20"><Share /></el-icon>
        <span>分享</span>
      </div>
    </div>
  </PageTemplate>
</template>

<script setup lang="ts">
import { ref, onMounted, computed, watch } from 'vue'
import { marked } from 'marked'
import { ElMessage } from 'element-plus'
import {
  Star, StarFilled, Share, ArrowRight, ArrowLeft, Link, Top
} from '@element-plus/icons-vue'
import PageTemplate from '../../common/PageTemplate.vue'
import {
  getArticleById, getArticleContent, getArticles, getCategories,
  addFavorite, removeFavorite, isFavorite, recordRead, KnowledgeCategory,
  type KnowledgeArticle
} from '../../../services/knowledge/knowledgeService.ts'

const props = defineProps<{
  articleId: string
}>()

const emit = defineEmits(['navigate'])
const contentRef = ref<{
  scrollToTop: (top: number, behavior: ScrollBehavior) => void
} | null>(null);

const article = ref<KnowledgeArticle | null>(null)
const renderedContent = ref('')
const isFav = ref(false)
const categoryName = ref('')
const allArticles = ref<KnowledgeArticle[]>([])
const categories = ref<KnowledgeCategory[]>([])
const articleId = ref<string>(props.articleId)
const showBackToTop = ref(false)

const currentIndex = computed(() => {
  return allArticles.value.findIndex(a => a.id === articleId.value)
})

const prevArticle = computed(() => {
  const idx = currentIndex.value
  return idx > 0 ? allArticles.value[idx - 1] : null
})

const nextArticle = computed(() => {
  const idx = currentIndex.value
  return idx >= 0 && idx < allArticles.value.length - 1 ? allArticles.value[idx + 1] : null
})

watch(() => articleId.value, () => {
  loadArticle()
})

const handleScroll = (scrollTop: number) => {
    console.log('Scrolling:', scrollTop)
  showBackToTop.value = scrollTop > 300
}

const backToTop = () => {
  contentRef.value?.scrollToTop(0, 'smooth' as ScrollBehavior)
}

const relatedPageMap: Record<string, { key: string; title: string }> = {
  asset: { key: 'asset', title: '资产负债' },
  sandbox: { key: 'sandbox', title: '沙盘推演' },
  goal: { key: 'goal', title: '财务目标' },
  expense: { key: 'expense', title: '支出统计' },
  health: { key: 'dashboard', title: '财务健康' }
}

const relatedPageTitle = computed(() => {
  return article.value ? relatedPageMap[article.value.relatedPage]?.title || '相关功能' : ''
})

const goBack = () => {
  emit('navigate', 'knowledge')
}

const goToArticle = (id: string) => {
  articleId.value = id
  contentRef.value?.scrollToTop(0, 'smooth' as ScrollBehavior)

}

const goToRelatedPage = () => {
  if (!article.value) return
  const page = relatedPageMap[article.value.relatedPage]
  if (page) {
    emit('navigate', page.key)
  }
}

const toggleFavorite = async () => {
  if (!article.value) return
  if (isFav.value) {
    await removeFavorite(article.value.id)
    isFav.value = false
  } else {
    await addFavorite(article.value.id)
    isFav.value = true
  }
}

const shareArticle = () => {
  if (!article.value) return
  // 复制链接或标题到剪贴板
  const text = `${article.value.title} - 来自财务APP知识分享`
  if (navigator.clipboard) {
    navigator.clipboard.writeText(text).then(() => {
      ElMessage.success('已复制到剪贴板')
    }).catch(() => {
      alert(text)
    })
  } else {
    alert(text)
  }
}

const loadArticle = async () => {
  const art = getArticleById(articleId.value)
  if (!art) {
    goBack()
    return
  }

  article.value = art

  const cat = categories.value.find(c => c.id === art.categoryId)
  categoryName.value = cat?.name || ''

  // 渲染markdown
  const content = await getArticleContent(art)
  renderedContent.value = await marked(content)

  // 记录阅读历史
  await recordRead(art.id)

  // 检查收藏状态
  isFav.value = await isFavorite(art.id)
}

onMounted(async () => {
  allArticles.value = getArticles()
  categories.value = getCategories()
  await loadArticle()
})
</script>

<style scoped>
.article-page {
  padding: 16px;
  padding-bottom: 80px;
  background-color: #fff;
}

/* 文章头部 */
.article-header {
  margin-bottom: 20px;
  padding-bottom: 16px;
  border-bottom: 1px solid #f0f0f0;
}

.article-title {
  margin: 0 0 12px 0;
  font-size: 20px;
  font-weight: 700;
  color: #303133;
  line-height: 1.5;
}

.article-meta {
  display: flex;
  align-items: center;
  gap: 12px;
  flex-wrap: wrap;
}

.article-meta .category {
  font-size: 12px;
  color: #409eff;
  background: #ecf5ff;
  padding: 2px 8px;
  border-radius: 4px;
}

.article-meta .read-time,
.article-meta .date {
  font-size: 12px;
  color: #909399;
}

.book-info {
  margin-top: 10px;
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 13px;
  color: #606266;
}

/* 核心要点 */
.core-points {
  margin-bottom: 20px;
  padding: 14px;
  background: #f5f7fa;
  border-radius: 8px;
}

.section-label {
  font-size: 14px;
  font-weight: 600;
  color: #303133;
  margin-bottom: 10px;
}

.core-points ul {
  margin: 0;
  padding-left: 18px;
}

.core-points li {
  font-size: 13px;
  color: #606266;
  line-height: 1.8;
  margin-bottom: 4px;
}

/* Markdown 内容 */
.markdown-content {
  font-size: 15px;
  line-height: 1.8;
  color: #303133;
}

.markdown-content :deep(h1) {
  font-size: 18px;
  font-weight: 700;
  margin: 24px 0 12px 0;
  color: #303133;
}

.markdown-content :deep(h2) {
  font-size: 16px;
  font-weight: 700;
  margin: 20px 0 10px 0;
  color: #303133;
  border-bottom: 1px solid #f0f0f0;
  padding-bottom: 6px;
}

.markdown-content :deep(h3) {
  font-size: 15px;
  font-weight: 600;
  margin: 16px 0 8px 0;
  color: #303133;
}

.markdown-content :deep(p) {
  margin: 10px 0;
  color: #606266;
}

.markdown-content :deep(strong) {
  color: #303133;
  font-weight: 600;
}

.markdown-content :deep(ul),
.markdown-content :deep(ol) {
  padding-left: 20px;
  margin: 10px 0;
}

.markdown-content :deep(li) {
  margin-bottom: 6px;
  color: #606266;
}

.markdown-content :deep(blockquote) {
  margin: 12px 0;
  padding: 10px 14px;
  background: #f5f7fa;
  border-left: 4px solid #409eff;
  color: #606266;
}

.markdown-content :deep(code) {
  background: #f5f7fa;
  padding: 2px 6px;
  border-radius: 4px;
  font-size: 13px;
  color: #f56c6c;
}

/* 联动APP */
.related-action {
  margin-top: 24px;
  padding-top: 20px;
  border-top: 1px solid #f0f0f0;
}

.action-card {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 14px;
  background: #ecf5ff;
  border-radius: 10px;
  cursor: pointer;
  transition: all 0.2s ease;
}

.action-card:active {
  background: #d9ecff;
}

.action-info {
  flex: 1;
  min-width: 0;
}

.action-title {
  font-size: 14px;
  font-weight: 600;
  color: #409eff;
  margin-bottom: 2px;
}

.action-desc {
  font-size: 12px;
  color: #909399;
}

.action-card .arrow {
  color: #409eff;
}

/* 上下篇导航 */
.article-nav {
  margin-top: 24px;
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.nav-card {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 12px;
  background: #f5f7fa;
  border-radius: 8px;
  cursor: pointer;
  transition: all 0.2s ease;
}

.nav-card:active {
  background: #e4e7ed;
}

.nav-card.next {
  justify-content: flex-end;
  text-align: right;
}

.nav-info {
  flex: 1;
  min-width: 0;
}

.nav-label {
  font-size: 11px;
  color: #909399;
  margin-bottom: 2px;
}

.nav-title {
  font-size: 13px;
  font-weight: 500;
  color: #303133;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

/* 底部操作栏 */
.article-actions {
  position: fixed;
  bottom: 0;
  left: 0;
  right: 0;
  display: flex;
  justify-content: space-around;
  align-items: center;
  padding: 10px 0;
  background: #fff;
  border-top: 1px solid #e4e7ed;
  z-index: 100;
}

.action-btn {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 4px;
  cursor: pointer;
  color: #606266;
  font-size: 12px;
  transition: all 0.2s ease;
}

.action-btn.active {
  color: #e6a23c;
}

.action-btn:active {
  opacity: 0.7;
}

/* 回到顶部按钮 */
.back-to-top {
  position: fixed;
  right: 16px;
  bottom: 80px;
  width: 44px;
  height: 44px;
  border-radius: 50%;
  background: #409eff;
  color: white;
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: 0 4px 12px rgba(64, 158, 255, 0.4);
  cursor: pointer;
  z-index: 101;
  transition: all 0.3s ease;
}

.back-to-top:active {
  transform: scale(0.92);
  background: #3a8ee6;
}

/* 淡入淡出动画 */
.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.3s ease, transform 0.3s ease;
}

.fade-enter-from,
.fade-leave-to {
  opacity: 0;
  transform: translateY(10px);
}
</style>
