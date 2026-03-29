/**
 * 数据库管理类
 * 负责SQLite数据库的连接、初始化和CRUD操作
 * 使用sql.js，纯JavaScript实现，无需编译
 */
import initSqlJs from 'sql.js'

class DatabaseManager {
  constructor() {
    // 数据库连接实例
    this.db = null
    // SQL.js模块
    this.SQL = null
    // 数据库名称（用于localStorage）
    this.dbName = 'finance-app-db'
  }

  /**
   * 初始化SQL.js
   * @returns {Promise} 初始化结果
   */
  async initSQL() {
    if (!this.SQL) {
      this.SQL = await initSqlJs()
    }
    return this.SQL
  }

  /**
   * 连接数据库
   * @returns {Promise} 连接成功返回数据库实例，失败返回错误
   */
  async connect() {
    try {
      // 如果数据库已经连接，直接返回
      if (this.db) {
        return this.db
      }
      
      // 初始化SQL.js
      await this.initSQL()
      
      // 读取现有数据库或创建新数据库
      let dbBuffer
      try {
        // 在浏览器环境中使用localStorage
        if (typeof window !== 'undefined' && window.localStorage) {
          const savedDb = localStorage.getItem(this.dbName)
          if (savedDb) {
            // 从localStorage加载数据库
            const binaryString = atob(savedDb)
            const len = binaryString.length
            dbBuffer = new Uint8Array(len)
            for (let i = 0; i < len; i++) {
              dbBuffer[i] = binaryString.charCodeAt(i)
            }
          } else {
            // 创建新数据库
            dbBuffer = new Uint8Array()
          }
        } else {
          // 在Node.js环境中使用内存数据库
          dbBuffer = new Uint8Array()
        }
      } catch (err) {
        // 读取失败，创建新数据库
        dbBuffer = new Uint8Array()
      }
      
      // 创建数据库实例
      this.db = new this.SQL.Database(dbBuffer)
      console.log('Connected to SQLite database')
      
      // 初始化数据库表结构
      this.initialize()
      
      // 保存数据库
      this.saveDatabase()
      
      return this.db
    } catch (err) {
      console.error('Error opening database:', err)
      throw err
    }
  }

  /**
   * 初始化数据库表结构
   * 创建所有必要的表
   */
  initialize() {
    // 创建账户表
    this.run(`
      CREATE TABLE IF NOT EXISTS accounts (
        id TEXT PRIMARY KEY,           -- 账户ID
        name TEXT NOT NULL UNIQUE,     -- 账户名称
        type TEXT NOT NULL,            -- 账户类型
        balance REAL DEFAULT 0,        -- 账户余额
        used_limit REAL DEFAULT 0,     -- 已用额度（信用卡）
        total_limit REAL DEFAULT 0,    -- 总额度（信用卡）
        is_liquid INTEGER DEFAULT 1,   -- 是否为流动资金
        remark TEXT,                   -- 备注
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, -- 创建时间
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP  -- 更新时间
      )
    `)

    // 创建流水表
    this.run(`
      CREATE TABLE IF NOT EXISTS transactions (
        id TEXT PRIMARY KEY,           -- 流水ID
        type TEXT NOT NULL,            -- 流水类型
        amount REAL NOT NULL,          -- 金额
        account_id TEXT,               -- 关联账户ID
        related_id TEXT,               -- 关联业务ID
        balance_after REAL NOT NULL,   -- 变动后余额
        remark TEXT,                   -- 备注
        status TEXT DEFAULT '正常',    -- 状态
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, -- 创建时间
        FOREIGN KEY (account_id) REFERENCES accounts(id) -- 外键关联
      )
    `)

    // 创建资产表
    this.run(`
      CREATE TABLE IF NOT EXISTS assets (
        id TEXT PRIMARY KEY,           -- 资产ID
        type TEXT NOT NULL,            -- 资产类型
        name TEXT NOT NULL,            -- 资产名称
        amount REAL DEFAULT 0,         -- 资产金额
        account_id TEXT,               -- 关联账户ID
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, -- 创建时间
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, -- 更新时间
        FOREIGN KEY (account_id) REFERENCES accounts(id) -- 外键关联
      )
    `)

    // 创建股票表
    this.run(`
      CREATE TABLE IF NOT EXISTS stocks (
        id TEXT PRIMARY KEY,           -- 股票交易ID
        name TEXT NOT NULL,            -- 股票名称
        code TEXT,                     -- 股票代码
        price REAL NOT NULL,           -- 交易价格
        quantity INTEGER NOT NULL,     -- 交易股数
        fee REAL DEFAULT 0,            -- 手续费
        transaction_time TIMESTAMP NOT NULL, -- 交易时间
        type TEXT NOT NULL,            -- 交易类型（买入/卖出）
        account_id TEXT,               -- 关联账户ID
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, -- 创建时间
        FOREIGN KEY (account_id) REFERENCES accounts(id) -- 外键关联
      )
    `)

    // 创建基金表
    this.run(`
      CREATE TABLE IF NOT EXISTS funds (
        id TEXT PRIMARY KEY,           -- 基金交易ID
        name TEXT NOT NULL,            -- 基金名称
        code TEXT,                     -- 基金代码
        nav REAL NOT NULL,             -- 单位净值
        shares REAL NOT NULL,          -- 交易份额
        fee REAL DEFAULT 0,            -- 手续费
        has_lock BOOLEAN DEFAULT 0,    -- 是否有锁定期
        transaction_time TIMESTAMP NOT NULL, -- 交易时间
        type TEXT NOT NULL,            -- 交易类型（买入/卖出）
        account_id TEXT,               -- 关联账户ID
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, -- 创建时间
        FOREIGN KEY (account_id) REFERENCES accounts(id) -- 外键关联
      )
    `)

    // 创建负债表
    this.run(`
      CREATE TABLE IF NOT EXISTS liabilities (
        id TEXT PRIMARY KEY,           -- 负债ID
        name TEXT NOT NULL,            -- 负债名称
        type TEXT NOT NULL,            -- 负债类型
        principal REAL NOT NULL,       -- 本金
        remaining_principal REAL NOT NULL, -- 剩余本金
        is_interest BOOLEAN DEFAULT 1, -- 是否计息
        interest_rate REAL DEFAULT 0,   -- 年化利率
        start_date DATE NOT NULL,      -- 借款日期
        repayment_method TEXT NOT NULL, -- 还款方式
        repayment_day INTEGER,         -- 还款日
        period INTEGER,                -- 期数
        account_id TEXT,               -- 关联账户ID
        remark TEXT,                   -- 备注
        status TEXT DEFAULT '未结清',  -- 状态
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, -- 创建时间
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, -- 更新时间
        FOREIGN KEY (account_id) REFERENCES accounts(id) -- 外键关联
      )
    `)

    // 创建财务目标表
    this.run(`
      CREATE TABLE IF NOT EXISTS financial_goals (
        id TEXT PRIMARY KEY,           -- 目标ID
        name TEXT NOT NULL,            -- 目标名称
        type TEXT NOT NULL,            -- 目标类型
        target_amount REAL NOT NULL,   -- 目标金额
        monthly_amount REAL NOT NULL,  -- 每月投入金额
        period INTEGER NOT NULL,       -- 期限（月）
        account_id TEXT,               -- 关联账户ID
        status TEXT DEFAULT '未开始',  -- 状态
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, -- 创建时间
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, -- 更新时间
        FOREIGN KEY (account_id) REFERENCES accounts(id) -- 外键关联
      )
    `)

    // 创建财务健康报告表
    this.run(`
      CREATE TABLE IF NOT EXISTS financial_health (
        id TEXT PRIMARY KEY,           -- 报告ID
        liabilities_income_ratio REAL, -- 负债收入比
        emergency_fund_ratio REAL,     -- 应急金充足率
        asset_liability_ratio REAL,    -- 资产负债率
        savings_rate REAL,             -- 储蓄率
        net_asset_growth REAL,         -- 净资产增长率
        total_score INTEGER,           -- 总评分
        report_date DATE NOT NULL,      -- 报告日期
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP -- 创建时间
      )
    `)
  }

  /**
   * 通用查询方法
   * @param {string} sql - SQL查询语句
   * @param {Array} params - 查询参数
   * @returns {Array} 查询结果
   */
  async query(sql, params = []) {
    try {
      // 确保数据库已经连接
      await this.connect()
      const stmt = this.db.prepare(sql)
      const result = stmt.all(params)
      return result || []
    } catch (err) {
      console.error('Error executing query:', err)
      throw err
    }
  }

  /**
   * 通用执行方法
   * @param {string} sql - SQL执行语句
   * @param {Array} params - 执行参数
   * @returns {Object} 执行结果
   */
  async run(sql, params = []) {
    try {
      // 确保数据库已经连接
      await this.connect()
      const stmt = this.db.prepare(sql)
      stmt.run(params)
      this.saveDatabase() // 每次修改后保存数据库
      return { lastID: 0, changes: 1 } // sql.js不提供详细的执行结果
    } catch (err) {
      console.error('Error executing statement:', err)
      throw err
    }
  }

  /**
   * 保存数据库
   */
  saveDatabase() {
    if (this.db) {
      const data = this.db.export()
      // 在浏览器环境中使用localStorage
      if (typeof window !== 'undefined' && window.localStorage) {
        // 将Uint8Array转换为base64字符串存储
        const binaryString = String.fromCharCode.apply(null, Array.from(data))
        const base64String = btoa(binaryString)
        localStorage.setItem(this.dbName, base64String)
      }
    }
  }

  /**
   * 关闭数据库连接
   */
  close() {
    if (this.db) {
      this.db.close()
    }
  }
}

// 导出数据库实例
export default new DatabaseManager()
