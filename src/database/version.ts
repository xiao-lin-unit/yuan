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

interface Migration {
  version: string
  description: string
  migrate: (db: any) => Promise<void>
}

/**
 * 辅助函数：检查表是否存在某列
 */
async function hasColumn(db: any, table: string, column: string): Promise<boolean> {
  const columns = await db.query(`PRAGMA table_info(${table})`)
  return columns.some((c: any) => c.name === column)
}

/**
 * 辅助函数：重建表（用于删除列等 SQLite 不直接支持的操作）
 * 使用 create-new → copy-data → drop-old → rename 模式
 */
async function rebuildTable(db: any, tableName: string, createSql: string, columnsToKeep: string[]): Promise<void> {
  const tempTable = `${tableName}_migration_temp`
  const tempCreateSql = createSql.replace(
    `CREATE TABLE IF NOT EXISTS ${tableName}`,
    `CREATE TABLE IF NOT EXISTS ${tempTable}`
  )
  await db.run(tempCreateSql)
  const colList = columnsToKeep.join(', ')
  await db.run(`INSERT INTO ${tempTable} (${colList}) SELECT ${colList} FROM ${tableName}`)
  await db.run(`DROP TABLE ${tableName}`)
  await db.run(`ALTER TABLE ${tempTable} RENAME TO ${tableName}`)
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
  {
    version: '1.0.1',
    description: 'stocks/funds 表确保 status 列存在（兼容 ended 列迁移）',
    migrate: async (db) => {
      // ── funds 表迁移 ──
      const fundsHasStatus = await hasColumn(db, 'funds', 'status')
      const fundsHasEnded = await hasColumn(db, 'funds', 'ended')

      if (!fundsHasStatus) {
        // status 列不存在，需要添加
        await db.run(`ALTER TABLE funds ADD COLUMN status TEXT DEFAULT '开启'`)
        if (fundsHasEnded) {
          // 从 ended 列迁移数据
          await db.run(`UPDATE funds SET status = CASE WHEN ended = 1 THEN '结束' ELSE '开启' END`)
        }
      } else if (fundsHasEnded) {
        // 两列都存在（中间状态），同步空值
        await db.run(`UPDATE funds SET status = CASE WHEN ended = 1 THEN '结束' ELSE '开启' END WHERE status IS NULL OR status = ''`)
      }

      // ── stocks 表迁移 ──
      const stocksHasStatus = await hasColumn(db, 'stocks', 'status')
      const stocksHasEnded = await hasColumn(db, 'stocks', 'ended')

      if (!stocksHasStatus) {
        // status 列不存在，需要添加
        await db.run(`ALTER TABLE stocks ADD COLUMN status TEXT DEFAULT '开启'`)
        if (stocksHasEnded) {
          // 从 ended 列迁移数据
          await db.run(`UPDATE stocks SET status = CASE WHEN ended = 1 THEN '结束' ELSE '开启' END`)
        }
      } else if (stocksHasEnded) {
        // 两列都存在（中间状态），同步空值
        await db.run(`UPDATE stocks SET status = CASE WHEN ended = 1 THEN '结束' ELSE '开启' END WHERE status IS NULL OR status = ''`)
      }
    }
  },
  {
    version: '1.0.2',
    description: 'stocks/funds 表确保 status 列存在（兼容 ended 列迁移）',
    migrate: async (db) => {
      // 将系统中所有表的时间字段进行统一，将原本表中不同格式的时间日期改为统一的YYYY-MM-DD HH:mm:ss格式

      // 1. 获取系统中的所有表
      const tables = await db.query(`SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name`)
      for (const table of tables) {
        if (table.name === 'sqlite_sequence') continue
        if (table.name.indexOf('_new') > -1) {
          db.run(`DROP TABLE ${table.name}`)
        }
        // 2. 获取表中的所有字段
        const columns = await db.query(`PRAGMA table_info(${table.name})`)
        for (const column of columns) {
          // 3. 判断字段类型是否为时间字段
          if (column.name === 'created_at' || column.name === 'updated_at' || column.name.indexOf('_time') > -1) {
            // 4. 更新时间字段为统一格式
            await db.run(`UPDATE ${table.name} SET ${column.name} = strftime('%Y-%m-%d %H:%M:%S', ${column.name}) WHERE ${column.name} IS NOT NULL`);
          } else if (column.name.indexOf('_date') > -1) {
            // 5. 更新日期字段为统一格式
            await db.run(`UPDATE ${table.name} SET ${column.name} = strftime('%Y-%m-%d 00:00:00', ${column.name}) WHERE ${column.name} IS NOT NULL`);
          }
        }
      }

    }
  }
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
