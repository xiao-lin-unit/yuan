/**
 * 数据库版本迁移脚本
 *
 * 新增版本迁移时，只需在 MIGRATIONS 数组末尾追加一条记录即可，
 * versionUpdate() 会自动按顺序执行所有未应用的迁移。
 *
 * 约定：
 * - version 字段必须与 package.json 中的版本号一致（纯数字，不含 'v' 前缀）
 * - migrate 函数接收 db 实例，可在其中执行任意 SQL
 * - migrate 函数必须是幂等的（重复调用不会产生副作用）
 */

import type DatabaseManager from './index.js'

interface Migration {
  version: string
  description: string
  migrate: (db: DatabaseManager) => Promise<void>
}

export const MIGRATIONS: Migration[] = [
  {
    version: '1.0.0',
    description: '初始版本',
    migrate: async (_db) => {
      // 初始版本无迁移操作
    }
  },
  // ── 新版本迁移在此处追加 ──────────────────────────
  // {
  //   version: '1.0.1',
  //   description: '例如：为 accounts 表添加新字段',
  //   migrate: async (db) => {
  //     await db.run('ALTER TABLE accounts ADD COLUMN new_field TEXT')
  //   }
  // },
]

/** 获取最新版本号 */
export function getLatestVersion(): string {
  return MIGRATIONS[MIGRATIONS.length - 1].version
}

/** 比较语义化版本号，返回 -1 / 0 / 1 */
export function compareVersions(a: string, b: string): number {
  const pa = a.split('.').map(Number)
  const pb = b.split('.').map(Number)
  for (let i = 0; i < 3; i++) {
    if ((pa[i] || 0) < (pb[i] || 0)) return -1
    if ((pa[i] || 0) > (pb[i] || 0)) return 1
  }
  return 0
}
