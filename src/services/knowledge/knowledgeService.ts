import db from '../../database/index.js'
import { getCurrentDate } from '../../utils/timezone.ts'
import categoriesData from '../../assets/knowledge/category.json'
import articlesData from '../../assets/knowledge/articles.json'

export interface KnowledgeCategory {
  id: string
  name: string
  icon: string
  description: string
}

export interface KnowledgeArticle {
  id: string
  categoryId: string
  title: string
  summary: string
  corePoints: string[]
  content?: string[]
  contentPath?: string
  contentFormat: string
  contentPreview?: string[]
  targetAudience: string
  relatedPage: string
  readTime: string
  createTime: string
  isTop: boolean
  bookInfo?: {
    bookName: string
    author: string
    coreValue: string
  },
  type: string
}

// 获取所有分类
export function getCategories(): KnowledgeCategory[] {
  return categoriesData as KnowledgeCategory[]
}

// 获取所有文章
export function getArticles(): KnowledgeArticle[] {
  return articlesData as KnowledgeArticle[]
}

// 根据分类获取文章
export function getArticlesByCategory(categoryId: string): KnowledgeArticle[] {
  return (articlesData as KnowledgeArticle[]).filter(a => a.categoryId === categoryId)
}

// 获取置顶文章
export function getTopArticles(): KnowledgeArticle[] {
  return (articlesData as KnowledgeArticle[]).filter(a => a.isTop)
}

// 根据ID获取文章
export function getArticleById(articleId: string): KnowledgeArticle | undefined {
  return (articlesData as KnowledgeArticle[]).find(a => a.id === articleId)
}

// 预加载所有 markdown 文件内容（Vite 构建时打包，确保生产环境可用）
const markdownModules = import.meta.glob('../../assets/knowledge/content/*.md', {
  eager: true,
  query: '?raw',
  import: 'default'
})

const markdownContentMap = new Map<string, string>()
Object.entries(markdownModules).forEach(([path, content]) => {
  // 将 ../../assets/... 转换为 src/assets/... 以匹配 articles.json 中的 contentPath
  const normalizedPath = path.replace(/^\.\.\/\.\.\//, 'src/')
  markdownContentMap.set(normalizedPath, content as string)
})

// 获取文章内容（如果是contentPath则加载外部文件，否则返回content数组）
export async function getArticleContent(article: KnowledgeArticle): Promise<string> {
  if (article.type === 'file' && article.contentPath) {
    // 优先从预加载的模块读取（适用于生产环境）
    const preloaded = markdownContentMap.get(article.contentPath)
    if (preloaded) {
      return preloaded
    }

    // 回退：尝试 fetch（适用于开发环境）
    try {
      const response = await fetch(article.contentPath)
      if (response.ok) {
        return await response.text()
      }
    } catch (e) {
      console.warn('Failed to load article content from path:', article.contentPath, e)
    }

    // 最终回退：预览内容拼接
    return article.contentPreview?.join('\n\n') || ''
  }
  return article.content?.join('\n\n') || ''
}

// 添加收藏
export async function addFavorite(articleId: string): Promise<void> {
  const now = getCurrentDate().format('YYYY-MM-DD')
  await db.run(
    `INSERT OR REPLACE INTO knowledge_favorite (article_id, create_time) VALUES (?, ?)`,
    [articleId, now]
  )
}

// 取消收藏
export async function removeFavorite(articleId: string): Promise<void> {
  await db.run(
    `DELETE FROM knowledge_favorite WHERE article_id = ?`,
    [articleId]
  )
}

// 检查是否已收藏
export async function isFavorite(articleId: string): Promise<boolean> {
  const result = await db.query(
    `SELECT 1 FROM knowledge_favorite WHERE article_id = ?`,
    [articleId]
  )
  return result.length > 0
}

// 获取所有收藏
export async function getFavorites(): Promise<string[]> {
  const result = await db.query(
    `SELECT article_id FROM knowledge_favorite ORDER BY create_time DESC`
  )
  return result.map((row: any) => row.article_id)
}

// 记录阅读历史
export async function recordRead(articleId: string): Promise<void> {
  const now = getCurrentDate().format('YYYY-MM-DD HH:mm')
  await db.run(
    `INSERT OR REPLACE INTO knowledge_read_history (article_id, read_time, is_read) VALUES (?, ?, 1)`,
    [articleId, now]
  )
}

// 获取阅读历史
export async function getReadHistory(): Promise<{ articleId: string; readTime: string }[]> {
  const result = await db.query(
    `SELECT article_id, read_time FROM knowledge_read_history ORDER BY read_time DESC`
  )
  return result.map((row: any) => ({
    articleId: row.article_id,
    readTime: row.read_time
  }))
}

// 检查是否已读
export async function isRead(articleId: string): Promise<boolean> {
  const result = await db.query(
    `SELECT 1 FROM knowledge_read_history WHERE article_id = ?`,
    [articleId]
  )
  return result.length > 0
}

// 清空阅读历史
export async function clearReadHistory(): Promise<void> {
  await db.run(`DELETE FROM knowledge_read_history`)
}

// 获取最近阅读的文章ID列表
export async function getRecentReadArticleIds(limit: number = 5): Promise<string[]> {
  const result = await db.query(
    `SELECT article_id FROM knowledge_read_history ORDER BY read_time DESC LIMIT ?`,
    [limit]
  )
  return result.map((row: any) => row.article_id)
}
