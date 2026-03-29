/**
 * 数据库适配器
 * 处理不同平台的SQLite实现差异
 */
import { Capacitor } from '@capacitor/core'

// 检查是否为原生平台
const isNative = Capacitor.isNativePlatform()

/**
 * 获取数据库实例
 * @returns {Object} 数据库实例
 */
export const getDatabase = () => {
  if (isNative) {
    // 原生平台使用Capacitor SQLite插件
    // 这里需要安装 @capacitor-community/sqlite 插件
    // 暂时返回模拟实现
    return require('./index.js')
  } else {
    // Web平台使用Node.js SQLite3
    return require('./index.js')
  }
}

/**
 * 平台特定的数据库初始化
 */
export const initializeDatabase = async () => {
  const db = getDatabase()
  await db.connect()
  return db
}
