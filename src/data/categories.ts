export interface Category {
  id: string
  name: string
  icon: string
  iconText: string
  type: string
}

// 支出分类数据，仅用于初始化
// 实际使用时应从数据库获取
export const expenseCategories: Category[] = [
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
  { id: 'cat_21', name: '其它', icon: 'other-icon', iconText: '📦', type: 'expense' }
]

// 收入分类数据，仅用于初始化
// 实际使用时应从数据库获取
export const incomeCategories: Category[] = [
  { id: 'cat_23', name: '工资', icon: 'salary-icon', iconText: '💰', type: 'income' },
  { id: 'cat_24', name: '奖金', icon: 'bonus-icon', iconText: '🎊', type: 'income' },
  { id: 'cat_26', name: '兼职', icon: 'parttime-icon', iconText: '💼', type: 'income' },
  { id: 'cat_29', name: '副业', icon: 'sidejob-icon', iconText: '💡', type: 'income' },
  { id: 'cat_27', name: '礼金', icon: 'gift-icon', iconText: '🎁', type: 'income' },
  { id: 'cat_28', name: '其他', icon: 'other-icon', iconText: '📦', type: 'income' }
]