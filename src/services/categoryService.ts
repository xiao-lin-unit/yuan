import dayjs from 'dayjs'
import db from '../database'
import { Category, expenseCategories, incomeCategories } from '../data/categories'

/**
 * 分类管理服务
 * 处理分类的增删改查操作
 */
export class CategoryService {
  /**
   * 获取所有分类
   * @param type 分类类型（可选）
   * @returns 分类列表
   */
  static async getCategories(type?: string): Promise<Category[]> {
    try {
      let sql = 'SELECT id, name, icon, iconText, type FROM categories'
      const params: any[] = []
      
      if (type) {
        sql += ' WHERE type = ?'
        params.push(type)
      }
      
      sql += ' ORDER BY created_at ASC'
      
      const result = await db.query(sql, params)
      
      // 无论数据库是否返回数据，都包含默认分类
      // 但要确保不重复（使用id作为唯一标识）
      const dbCategories = result.map((row: any) => ({
        id: row.id,
        name: row.name,
        icon: row.icon,
        iconText: row.iconText,
        type: row.type
      }))
      
      // 创建一个包含所有分类的集合，使用id去重
      const categoryMap = new Map<string, Category>()
      
      // 先添加默认分类
      expenseCategories.forEach(cat => {
        categoryMap.set(cat.id, cat)
      })
      incomeCategories.forEach(cat => {
        categoryMap.set(cat.id, cat)
      })
      
      // 再添加数据库中的分类（会覆盖重复的默认分类）
      dbCategories.forEach(cat => {
        categoryMap.set(cat.id, cat)
      })
      
      // 转换回数组并按类型过滤
      const allCategories = Array.from(categoryMap.values())
      
      if (type) {
        return allCategories.filter(cat => cat.type === type)
      }
      return allCategories
    } catch (error) {
      console.error('Error getting categories:', error)
      // 出错时返回默认分类
      if (type) {
        return [...expenseCategories, ...incomeCategories].filter(cat => cat.type === type)
      }
      return [...expenseCategories, ...incomeCategories]
    }
  }

  /**
   * 根据ID获取分类
   * @param id 分类ID
   * @returns 分类对象
   */
  static async getCategoryById(id: string): Promise<Category | null> {
    try {
      const result = await db.query('SELECT id, name, icon, iconText, type FROM categories WHERE id = ?', [id])
      if (result.length === 0) {
        return null
      }
      const row = result[0]
      return {
        id: row.id,
        name: row.name,
        icon: row.icon,
        iconText: row.iconText,
        type: row.type
      }
    } catch (error) {
      console.error('Error getting category by id:', error)
      return null
    }
  }

  /**
   * 创建分类
   * @param category 分类对象
   * @returns 创建结果
   */
  static async createCategory(category: Omit<Category, 'id'>): Promise<boolean> {
    try {
      const id = `cat_${dayjs().valueOf()}_${Math.floor(Math.random() * 1000)}`
      await db.run(
        'INSERT INTO categories (id, name, icon, iconText, type) VALUES (?, ?, ?, ?, ?)',
        [id, category.name, category.icon, category.iconText, category.type]
      )
      return true
    } catch (error) {
      console.error('Error creating category:', error)
      return false
    }
  }

  /**
   * 更新分类
   * @param id 分类ID
   * @param category 分类对象
   * @returns 更新结果
   */
  static async updateCategory(id: string, category: Partial<Category>): Promise<boolean> {
    try {
      const fields = []
      const params = []
      
      if (category.name !== undefined) {
        fields.push('name = ?')
        params.push(category.name)
      }
      if (category.icon !== undefined) {
        fields.push('icon = ?')
        params.push(category.icon)
      }
      if (category.iconText !== undefined) {
        fields.push('iconText = ?')
        params.push(category.iconText)
      }
      if (category.type !== undefined) {
        fields.push('type = ?')
        params.push(category.type)
      }
      
      fields.push('updated_at = CURRENT_TIMESTAMP')
      
      if (fields.length === 0) {
        return true
      }
      
      params.push(id)
      
      await db.run(
        `UPDATE categories SET ${fields.join(', ')} WHERE id = ?`,
        params
      )
      return true
    } catch (error) {
      console.error('Error updating category:', error)
      return false
    }
  }

  /**
   * 删除分类
   * @param id 分类ID
   * @returns 删除结果
   */
  static async deleteCategory(id: string): Promise<boolean> {
    try {
      await db.run('DELETE FROM categories WHERE id = ?', [id])
      return true
    } catch (error) {
      console.error('Error deleting category:', error)
      return false
    }
  }

  /**
   * 检查数据库连接状态
   * @returns 数据库连接状态信息
   */
  static async checkDatabaseStatus(): Promise<{ connected: boolean; message: string }> {
    try {
      // 尝试执行一个简单的查询
      await db.connect()
      const result = await db.query('SELECT 1')
      return { connected: true, message: '数据库连接正常' }
    } catch (error) {
      console.error('Database connection error:', error)
      return { 
        connected: false, 
        message: '数据库连接失败，使用内存模式' 
      }
    }
  }

  /**
   * 初始化默认分类
   */
  static async initializeDefaultCategories(): Promise<void> {
    try {
      // 直接检查数据库中是否存在分类
      // 注意：这里不使用this.getCategories()，因为它会返回默认分类
      const result = await db.query('SELECT COUNT(*) as count FROM categories')
      
      // 检查结果
      if (result && result.length > 0 && result[0].count > 0) {
        return
      }
      
      // 默认支出分类
      const defaultExpenseCategories = [
        { id: 'cat_1', name: '三餐', icon: 'food-icon', iconText: '🍽', type: 'expense' },
        { id: 'cat_2', name: '零食', icon: 'snack-icon', iconText: '🍪', type: 'expense' },
        { id: 'cat_3', name: '衣服', icon: 'clothes-icon', iconText: '👔', type: 'expense' },
        { id: 'cat_4', name: '交通', icon: 'transport-icon', iconText: '🚌', type: 'expense' },
        { id: 'cat_5', name: '旅行', icon: 'travel-icon', iconText: '✈️', type: 'expense' },
        { id: 'cat_6', name: '孩子', icon: 'child-icon', iconText: '👶', type: 'expense' },
        { id: 'cat_7', name: '宠物', icon: 'pet-icon', iconText: '🐶', type: 'expense' },
        { id: 'cat_8', name: '话费网费', icon: 'phone-icon', iconText: '📱', type: 'expense' },
        { id: 'cat_9', name: '烟酒', icon: 'alcohol-icon', iconText: '🍷', type: 'expense' },
        { id: 'cat_10', name: '学习', icon: 'study-icon', iconText: '📚', type: 'expense' },
        { id: 'cat_11', name: '日用品', icon: 'daily-icon', iconText: '🧺', type: 'expense' },
        { id: 'cat_12', name: '住房', icon: 'house-icon', iconText: '🏠', type: 'expense' },
        { id: 'cat_13', name: '美妆', icon: 'beauty-icon', iconText: '💄', type: 'expense' },
        { id: 'cat_14', name: '医疗', icon: 'medical-icon', iconText: '🏥', type: 'expense' },
        { id: 'cat_15', name: '发红包', icon: 'redpacket-icon', iconText: '🧧', type: 'expense' },
        { id: 'cat_16', name: '汽车/加油', icon: 'car-icon', iconText: '🚗', type: 'expense' },
        { id: 'cat_17', name: '娱乐', icon: 'entertainment-icon', iconText: '🎮', type: 'expense' },
        { id: 'cat_18', name: '请客送礼', icon: 'gift-icon', iconText: '🎁', type: 'expense' },
        { id: 'cat_19', name: '电器数码', icon: 'digital-icon', iconText: '📱', type: 'expense' },
        { id: 'cat_20', name: '运动', icon: 'sport-icon', iconText: '🏃', type: 'expense' },
        { id: 'cat_22', name: '水电煤', icon: 'utility-icon', iconText: '💧', type: 'expense' },
        { id: 'cat_21', name: '其它', icon: 'other-icon', iconText: '📦', type: 'expense' },
      ]
      
      // 默认收入分类
      const defaultIncomeCategories = [
        { id: 'cat_23', name: '工资', icon: 'salary-icon', iconText: '💰', type: 'income' },
        { id: 'cat_24', name: '奖金', icon: 'bonus-icon', iconText: '🎊', type: 'income' },
        { id: 'cat_26', name: '兼职', icon: 'parttime-icon', iconText: '💼', type: 'income' },
        { id: 'cat_29', name: '副业', icon: 'sidejob-icon', iconText: '💡', type: 'income' },
        { id: 'cat_27', name: '礼金', icon: 'gift-icon', iconText: '🎁', type: 'income' },
        { id: 'cat_28', name: '其他', icon: 'other-icon', iconText: '📦', type: 'income' }
      ]
      
      // 插入默认分类
      const allCategories = [...defaultExpenseCategories, ...defaultIncomeCategories]
      for (const category of allCategories) {
        await db.run(
          'INSERT INTO categories (id, name, icon, iconText, type) VALUES (?, ?, ?, ?, ?)',
          [category.id, category.name, category.icon, category.iconText, category.type]
        )
      }
      
      console.log('Default categories initialized')
    } catch (error) {
      console.error('Error initializing default categories:', error)
    }
  }
}