/**
 * 数据库管理类 - 优化版本
 * 负责SQLite数据库的连接、初始化和CRUD操作
 * 支持Capacitor SQLite（移动环境）和 sql.js（Web环境）
 * 所有数据持久化都使用SQLite数据库，不使用内存模式
 * 性能优化：连接池管理、批处理、索引优化、缓存机制
 */
import initSqlJs from 'sql.js'
import { Capacitor } from '@capacitor/core'
import { CapacitorSQLite, SQLiteConnection, SQLiteDBConnection } from '@capacitor-community/sqlite'

// 性能配置
const PERFORMANCE_CONFIG = {
  // Web环境持久化节流时间（毫秒）
  SAVE_THROTTLE_MS: 1000,
  // 启用详细日志
  DEBUG: false
}

// 数据库管理（单例模式）
class DatabaseManager {
  constructor() {
    this.db = null           // SQLiteDBConnection 实例
    this.SQL = null          // SQL.js 模块
    this.isNative = Capacitor.isNativePlatform()
    this.sqlite = null       // SQLiteConnection 实例
    this.initialized = false // 是否已初始化
    this.dbName = 'finance-app-db'
    this.connecting = false  // 是否正在连接中
    this.saveTimer = null    // Web环境持久化定时器
    this.cache = new Map()   // 查询缓存
  }

  /**
   * 初始化 SQL.js（Web环境）
   */
  async initSQL() {
    if (!this.SQL) {
      try {
        this.SQL = await initSqlJs()
        if (PERFORMANCE_CONFIG.DEBUG) {
          console.log('SQL.js initialized successfully')
        }
      } catch (err) {
        console.error('Error initializing SQL.js:', err)
        throw new Error('无法初始化SQL.js数据库引擎: ' + (err.message || err.toString()))
      }
    }
    return this.SQL
  }

  /**
   * 获取数据库连接（单例，确保只有一个连接）
   * @returns {Promise} 数据库实例
   */
  async getDB() {
    // 如果已经有连接，直接返回
    if (this.db) {
      if (PERFORMANCE_CONFIG.DEBUG) {
        console.log('Reusing existing database connection')
      }
      return this.db
    }

    // 如果正在连接中，等待连接完成
    if (this.connecting) {
      if (PERFORMANCE_CONFIG.DEBUG) {
        console.log('Waiting for existing connection attempt...')
      }
      while (this.connecting) {
        await new Promise(resolve => setTimeout(resolve, 50)) // 减少等待时间
      }
      if (this.db) {
        return this.db
      }
    }

    this.connecting = true

    try {
      if (this.isNative) {
        // 使用 Capacitor SQLite（移动环境）
        if (PERFORMANCE_CONFIG.DEBUG) {
          console.log('Using Capacitor SQLite for native platform')
        }
        
        // 初始化 SQLiteConnection
        if (!this.sqlite) {
          this.sqlite = new SQLiteConnection(CapacitorSQLite)
        }

        // 检查连接一致性
        let consistencyResult
        try {
          consistencyResult = await this.sqlite.checkConnectionsConsistency()
          if (PERFORMANCE_CONFIG.DEBUG) {
            console.log('Connection consistency check:', consistencyResult)
          }
        } catch (e) {
          if (PERFORMANCE_CONFIG.DEBUG) {
            console.log('Check connections consistency warning:', e)
          }
        }

        // 检查连接是否已存在
        let isConn
        try {
          isConn = await this.sqlite.isConnection(this.dbName, false)
          if (PERFORMANCE_CONFIG.DEBUG) {
            console.log('Is connection exists:', isConn)
          }
        } catch (e) {
          if (PERFORMANCE_CONFIG.DEBUG) {
            console.log('isConnection check failed:', e)
          }
        }

        // 获取或创建连接
        try {
          if (consistencyResult?.result && isConn?.result) {
            // 连接已存在，获取现有连接
            this.db = await this.sqlite.retrieveConnection(this.dbName, false)
            if (PERFORMANCE_CONFIG.DEBUG) {
              console.log('Retrieved existing Capacitor SQLite connection')
            }
          } else {
            // 创建新连接 - 注意：使用位置参数！
            this.db = await this.sqlite.createConnection(
              this.dbName, 
              false, 
              'no-encryption', 
              1, 
              false
            )
            if (PERFORMANCE_CONFIG.DEBUG) {
              console.log('Created new Capacitor SQLite connection')
            }

            // 打开数据库
            await this.db.open()
            if (PERFORMANCE_CONFIG.DEBUG) {
              console.log('Database opened successfully')
            }
          }
        } catch (connErr) {
          console.error('Connection error:', connErr)
          throw connErr
        }
      } else {
        // 使用 SQL.js（Web环境）
        if (PERFORMANCE_CONFIG.DEBUG) {
          console.log('Using SQL.js for web environment')
        }
        await this.initSQL()

        // 尝试从 localStorage 加载已持久化的数据
        const savedData = localStorage.getItem(`sqlite_${this.dbName}`)
        if (savedData) {
          try {
            const buf = Uint8Array.from(JSON.parse(savedData))
            this.db = new this.SQL.Database(buf)
            if (PERFORMANCE_CONFIG.DEBUG) {
              console.log('Database loaded from localStorage, size:', buf.length)
            }
          } catch (loadErr) {
            console.error('Error loading database from localStorage:', loadErr)
            this.db = new this.SQL.Database()
            if (PERFORMANCE_CONFIG.DEBUG) {
              console.log('Creating new database due to load error')
            }
          }
        } else {
          this.db = new this.SQL.Database()
          if (PERFORMANCE_CONFIG.DEBUG) {
            console.log('Creating new database')
          }
        }
      }

      if (PERFORMANCE_CONFIG.DEBUG) {
        console.log('Database connection established')
      }
      return this.db
    } catch (err) {
      console.error('Failed to establish database connection:', err)
      throw err
    } finally {
      this.connecting = false
    }
  }

  /**
   * 执行 SQL 查询
   * @param {string} sql - SQL查询语句
   * @param {Array} params - 查询参数
   * @param {boolean} useCache - 是否使用缓存
   * @returns {Array} 查询结果
   */
  async query(sql, params = [], useCache = false) {
    // 生成缓存键
    const cacheKey = `${sql}_${JSON.stringify(params)}`
    
    // 检查缓存
    if (useCache && this.cache.has(cacheKey)) {
      if (PERFORMANCE_CONFIG.DEBUG) {
        console.log('Using cached query result')
      }
      return this.cache.get(cacheKey)
    }

    const db = await this.getDB()

    try {
        let result
        if (this.isNative) {
          // Capacitor SQLite 查询 - 注意：使用位置参数！
          const queryResult = await db.query(sql, params)
          console.log('SQL Query Result:', JSON.stringify(queryResult))
          const values = queryResult.values || []
          console.log('Values:', JSON.stringify(values))
          
          // 检查values是否已经是对象数组
          if (values.length > 0 && typeof values[0] === 'object' && values[0] !== null) {
            // 如果已经是对象数组，直接使用原始字段名
            result = values
          } else {
            // 如果是二维数组，转换为对象数组并使用原始字段名
            const columns = queryResult.columns || []
            console.log('Columns:', columns)
            result = values.map(row => {
              const obj = {}
              columns.forEach((column, index) => {
                // 使用原始字段名
                obj[column] = row[index]
              })
              return obj
            })
          }
          console.log('Transformed result:', JSON.stringify(result))
        } else {
          // SQL.js 查询
          const stmt = db.prepare(sql)
          stmt.bind(params)
          const queryResult = []
          while (stmt.step()) {
            // 直接使用原始字段名
            const obj = stmt.getAsObject()
            queryResult.push(obj)
          }
          stmt.free()
          result = queryResult
        }

      // 缓存结果
      if (useCache) {
        this.cache.set(cacheKey, result)
      }

      return result
    } catch (e) {
      console.error('SQL Query Error:', e)
      throw new Error('SQL查询失败: ' + (e.message || e.toString()))
    }
  }

  /**
   * 执行 SQL 语句
   * @param {string} sql - SQL执行语句
   * @param {Array} params - 执行参数
   * @returns {Object} 执行结果
   */
  async run(sql, params = []) {
    const db = await this.getDB()

    if (PERFORMANCE_CONFIG.DEBUG) {
      console.log('Executing SQL:', sql, 'with params:', params)
    }

    try {
      let result
      if (this.isNative) {
        // Capacitor SQLite 执行 - 注意：使用位置参数！
        const runResult = await db.run(sql, params)
        result = { lastID: runResult.lastId || 0, changes: runResult.changes || 1 }
        if (PERFORMANCE_CONFIG.DEBUG) {
          console.log('SQL executed successfully with Capacitor SQLite')
        }
      } else {
        // SQL.js 执行
        const stmt = db.prepare(sql)
        stmt.run(params)
        stmt.free()
        result = { lastID: 0, changes: 1 }
        if (PERFORMANCE_CONFIG.DEBUG) {
          console.log('SQL executed successfully with SQL.js')
        }
        // 延迟持久化到 localStorage
        this.debouncedSave()
      }

      // 清除缓存
      this.clearCache()

      return result
    } catch (e) {
      console.error('SQL Run Error:', e)
      throw new Error('SQL执行失败: ' + (e.message || e.toString()))
    }
  }

  /**
   * 批处理执行多个 SQL 语句
   * @param {Array} statements - SQL语句数组 [{sql, params}]
   * @returns {Array} 执行结果数组
   */
  async batch(statements) {
    const db = await this.getDB()
    const results = []

    try {
      if (this.isNative) {
        // Capacitor SQLite 批处理
        for (const { sql, params = [] } of statements) {
          const result = await db.run(sql, params)
          results.push({ lastID: result.lastId || 0, changes: result.changes || 1 })
        }
      } else {
        // SQL.js 批处理
        for (const { sql, params = [] } of statements) {
          const stmt = db.prepare(sql)
          stmt.run(params)
          stmt.free()
          results.push({ lastID: 0, changes: 1 })
        }
        // 延迟持久化
        this.debouncedSave()
      }

      // 清除缓存
      this.clearCache()

      return results
    } catch (e) {
      console.error('Batch SQL Error:', e)
      throw new Error('批处理SQL失败: ' + (e.message || e.toString()))
    }
  }

  /**
   * 执行事务
   * @param {Function} statements - 接收一个事务执行语句,格式为capSQLiteSet | capSQLiteSet[]
   * @returns {Promise<any>} 回调函数的返回值
   */
  async executeTransaction(statements) {
    const db = await this.getDB()

    try {
      // 直接使用executeSet的自动事务功能（transaction默认为true）
      const result = await db.executeSet(statements)
      
      // 清除缓存
      this.clearCache()
      
      // Web环境延迟持久化
      if (!this.isNative) {
        this.debouncedSave()
      }
      
      return result
    } catch (e) {
      console.error('Transaction Error:', e)
      throw new Error('事务执行失败: ' + (e.message || e.toString()))
    }
  }

  /**
   * 延迟持久化到本地（Web环境）
   */
  debouncedSave() {
    if (this.isNative || !this.db) return

    // 清除之前的定时器
    if (this.saveTimer) {
      clearTimeout(this.saveTimer)
    }

    // 设置新的定时器
    this.saveTimer = setTimeout(() => {
      this.save()
    }, PERFORMANCE_CONFIG.SAVE_THROTTLE_MS)
  }

  /**
   * 持久化到本地（Web环境）
   */
  save() {
    if (this.isNative || !this.db) return

    try {
      const buf = this.db.export()
      localStorage.setItem(`sqlite_${this.dbName}`, JSON.stringify(Array.from(buf)))
      if (PERFORMANCE_CONFIG.DEBUG) {
        console.log('Database saved to localStorage')
      }
    } catch (err) {
      console.error('Error saving database:', err)
    }
  }

  /**
   * 清除缓存
   */
  clearCache() {
    this.cache.clear()
  }

  /**
   * 获取建表语句
   */
  getCreateStatements() {
    return [
      // 创建账户表
      {
        sql: `
          CREATE TABLE IF NOT EXISTS accounts (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL UNIQUE,
            type TEXT NOT NULL,
            balance REAL DEFAULT 0,
            used_limit REAL DEFAULT 0,
            total_limit REAL DEFAULT 0,
            is_liquid INTEGER DEFAULT 1,
            status TEXT DEFAULT '启用',
            asset_id TEXT,
            remark TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
          )
        `
      },
      // 创建流水表
      {
        sql: `
          CREATE TABLE IF NOT EXISTS transactions (
            id TEXT PRIMARY KEY,
            type TEXT NOT NULL,
            sub_type TEXT,
            amount REAL NOT NULL,
            account_id TEXT,
            related_id TEXT,
            balance_after REAL NOT NULL,
            remark TEXT,
            status TEXT DEFAULT '正常',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (account_id) REFERENCES accounts(id)
          )
        `
      },
      // 创建账户交易流水表（记录账户余额变动）
      {
        sql: `
          CREATE TABLE IF NOT EXISTS account_transactions (
            id TEXT PRIMARY KEY,
            account_id TEXT NOT NULL,
            type TEXT NOT NULL,
            amount REAL NOT NULL,
            balance_after REAL NOT NULL,
            description TEXT,
            transaction_time TIMESTAMP NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (account_id) REFERENCES accounts(id)
          )
        `
      },
      // 创建资产表
      {
        sql: `
          CREATE TABLE IF NOT EXISTS assets (
            id TEXT PRIMARY KEY,
            type TEXT NOT NULL,
            name TEXT NOT NULL,
            amount REAL DEFAULT 0,
            account_id TEXT,
            period TEXT,
            period_count INTEGER DEFAULT 0,
            income_date TEXT,
            next_income_date TEXT,
            calculation_type TEXT,
            income_amount REAL DEFAULT 0,
            annual_yield_rate REAL DEFAULT 0,
            ended INTEGER DEFAULT 0,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (account_id) REFERENCES accounts(id)
          )
        `
      },
      // 创建股票表
      {
        sql: `
          CREATE TABLE IF NOT EXISTS stocks (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            code TEXT,
            quantity INTEGER DEFAULT 0,
            current_price REAL DEFAULT 0,
            cost_price REAL DEFAULT 0,
            confirmed_profit REAL DEFAULT 0,
            first_buy_date TIMESTAMP,
            account_id TEXT,
            ended INTEGER DEFAULT 0,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (account_id) REFERENCES accounts(id)
          )
        `
      },
      // 创建股票持有记录表
      {
        sql: `
          CREATE TABLE IF NOT EXISTS stock_holdings (
            id TEXT PRIMARY KEY,
            stock_id TEXT NOT NULL,
            price REAL NOT NULL,
            quantity INTEGER NOT NULL,
            remaining_quantity INTEGER NOT NULL,
            sell_status TEXT DEFAULT '未卖出',
            fee REAL DEFAULT 0,
            transaction_time TIMESTAMP NOT NULL,
            account_id TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (stock_id) REFERENCES stocks(id),
            FOREIGN KEY (account_id) REFERENCES accounts(id)
          )
        `
      },
      // 创建股票交易记录表
      {
        sql: `
          CREATE TABLE IF NOT EXISTS stock_transactions (
            id TEXT PRIMARY KEY,
            stock_id TEXT NOT NULL,
            price REAL NOT NULL,
            quantity INTEGER NOT NULL,
            type TEXT NOT NULL,
            hold_ids TEXT,
            fee REAL DEFAULT 0,
            transaction_time TIMESTAMP NOT NULL,
            account_id TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (stock_id) REFERENCES stocks(id),
            FOREIGN KEY (account_id) REFERENCES accounts(id)
          )
        `
      },
      // 创建基金表
      {
        sql: `
          CREATE TABLE IF NOT EXISTS funds (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            code TEXT,
            shares REAL DEFAULT 0,
            current_nav REAL DEFAULT 0,
            cost_nav REAL DEFAULT 0,
            confirmed_profit REAL DEFAULT 0,
            total_fee REAL DEFAULT 0,
            first_buy_date TIMESTAMP,
            has_lock BOOLEAN DEFAULT 0,
            lock_period INTEGER DEFAULT 0,
            account_id TEXT,
            ended INTEGER DEFAULT 0,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (account_id) REFERENCES accounts(id)
          )
        `
      },
      // 创建基金持有记录表
      {
        sql: `
          CREATE TABLE IF NOT EXISTS fund_holdings (
            id TEXT PRIMARY KEY,
            fund_id TEXT NOT NULL,
            nav REAL NOT NULL,
            shares REAL NOT NULL,
            remaining_shares REAL NOT NULL,
            sell_status TEXT DEFAULT '未卖出',
            fee REAL DEFAULT 0,
            lock_period INTEGER DEFAULT 0,
            lock_end_date TIMESTAMP,
            transaction_time TIMESTAMP NOT NULL,
            account_id TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (fund_id) REFERENCES funds(id),
            FOREIGN KEY (account_id) REFERENCES accounts(id)
          )
        `
      },
      // 创建基金交易记录表
      {
        sql: `
          CREATE TABLE IF NOT EXISTS fund_transactions (
            id TEXT PRIMARY KEY,
            fund_id TEXT NOT NULL,
            transaction_nav REAL NOT NULL,
            shares REAL NOT NULL,
            type TEXT NOT NULL,
            hold_ids TEXT,
            fee REAL DEFAULT 0,
            transaction_time TIMESTAMP NOT NULL,
            account_id TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (fund_id) REFERENCES funds(id),
            FOREIGN KEY (account_id) REFERENCES accounts(id)
          )
        `
      },
      // 创建负债表
      {
        sql: `
          CREATE TABLE IF NOT EXISTS liabilities (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            type TEXT NOT NULL,
            principal REAL NOT NULL,
            remaining_principal REAL NOT NULL,
            remaining_total_interest REAL DEFAULT 0,
            is_interest BOOLEAN DEFAULT 1,
            interest_rate REAL DEFAULT 0,
            start_date DATE NOT NULL,
            repayment_method TEXT NOT NULL,
            repayment_day INTEGER,
            period INTEGER,
            account_id TEXT,
            remark TEXT,
            status TEXT DEFAULT '未结清',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (account_id) REFERENCES accounts(id)
          )
        `
      },
      // 创建还款记录表
      {
        sql: `
          CREATE TABLE IF NOT EXISTS repayments (
            id TEXT PRIMARY KEY,
            liability_id TEXT NOT NULL,
            period_number INTEGER,
            amount REAL NOT NULL,
            principal_amount REAL DEFAULT 0,
            interest_amount REAL DEFAULT 0,
            type TEXT NOT NULL,
            remark TEXT,
            repayment_time TIMESTAMP NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (liability_id) REFERENCES liabilities(id)
          )
        `
      },
      // 创建待还记录表
      {
        sql: `
          CREATE TABLE IF NOT EXISTS pending_repayments (
            id TEXT PRIMARY KEY,
            liability_id TEXT NOT NULL,
            period_number INTEGER NOT NULL,
            due_date DATE NOT NULL,
            principal_amount REAL NOT NULL,
            interest_amount REAL NOT NULL,
            total_amount REAL NOT NULL,
            status TEXT DEFAULT '未还',
            paid_date DATE,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (liability_id) REFERENCES liabilities(id)
          )
        `
      },
      // 创建财务目标表
      {
        sql: `
          CREATE TABLE IF NOT EXISTS financial_goals (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            type TEXT NOT NULL,
            target_amount REAL NOT NULL,
            monthly_amount REAL NOT NULL,
            period INTEGER NOT NULL,
            account_id TEXT,
            status TEXT DEFAULT '未开始',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (account_id) REFERENCES accounts(id)
          )
        `
      },
      // 创建财务健康报告表
      {
        sql: `
          CREATE TABLE IF NOT EXISTS financial_health (
            id TEXT PRIMARY KEY,
            liabilities_income_ratio REAL,
            emergency_fund_ratio REAL,
            asset_liability_ratio REAL,
            savings_rate REAL,
            net_asset_growth REAL,
            total_score INTEGER,
            report_date DATE NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
          )
        `
      },
      // 创建分类表
      {
        sql: `
          CREATE TABLE IF NOT EXISTS categories (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            icon TEXT,
            iconText TEXT,
            type TEXT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
          )
        `
      },
      // 创建普通资产收益记录表
      {
        sql: `
          CREATE TABLE IF NOT EXISTS asset_income_records (
            id TEXT PRIMARY KEY,
            asset_id TEXT NOT NULL,
            income_amount REAL NOT NULL,
            record_time TIMESTAMP NOT NULL,
            remark TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (asset_id) REFERENCES assets(id)
          )
        `
      },
      // 创建月度资产记录表
      {
        sql: `
          CREATE TABLE IF NOT EXISTS asset_monthly_snapshots (
            id TEXT PRIMARY KEY,
            year INTEGER NOT NULL,
            month INTEGER NOT NULL,
            total_assets REAL DEFAULT 0,
            total_liabilities REAL DEFAULT 0,
            net_worth REAL DEFAULT 0,
            confirmed_profit_stocks REAL DEFAULT 0,
            confirmed_profit_funds REAL DEFAULT 0,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            UNIQUE(year, month)
          )
        `
      },
      // 创建索引（性能优化）
      { sql: 'CREATE INDEX IF NOT EXISTS idx_accounts_type ON accounts(type)' },
      { sql: 'CREATE INDEX IF NOT EXISTS idx_accounts_is_liquid ON accounts(is_liquid)' },
      { sql: 'CREATE INDEX IF NOT EXISTS idx_transactions_account_id ON transactions(account_id)' },
      { sql: 'CREATE INDEX IF NOT EXISTS idx_account_transactions_account_id ON account_transactions(account_id)' },
      { sql: 'CREATE INDEX IF NOT EXISTS idx_transactions_created_at ON transactions(created_at)' },
      { sql: 'CREATE INDEX IF NOT EXISTS idx_assets_account_id ON assets(account_id)' },
      { sql: 'CREATE INDEX IF NOT EXISTS idx_stocks_account_id ON stocks(account_id)' },
      { sql: 'CREATE INDEX IF NOT EXISTS idx_funds_account_id ON funds(account_id)' },
      { sql: 'CREATE INDEX IF NOT EXISTS idx_liabilities_account_id ON liabilities(account_id)' },
      { sql: 'CREATE INDEX IF NOT EXISTS idx_liabilities_status ON liabilities(status)' },
      { sql: 'CREATE INDEX IF NOT EXISTS idx_repayments_liability_id ON repayments(liability_id)' },
      { sql: 'CREATE INDEX IF NOT EXISTS idx_repayments_repayment_time ON repayments(repayment_time)' },
      { sql: 'CREATE INDEX IF NOT EXISTS idx_pending_repayments_liability_id ON pending_repayments(liability_id)' },
      { sql: 'CREATE INDEX IF NOT EXISTS idx_pending_repayments_due_date ON pending_repayments(due_date)' },
      { sql: 'CREATE INDEX IF NOT EXISTS idx_financial_goals_account_id ON financial_goals(account_id)' },
      { sql: 'CREATE INDEX IF NOT EXISTS idx_financial_goals_status ON financial_goals(status)' },
      { sql: 'CREATE INDEX IF NOT EXISTS idx_categories_type ON categories(type)' },
      { sql: 'CREATE INDEX IF NOT EXISTS idx_asset_income_records_asset_id ON asset_income_records(asset_id)' },
      { sql: 'CREATE INDEX IF NOT EXISTS idx_asset_monthly_snapshots_year_month ON asset_monthly_snapshots(year, month)' }
    ]
  }

  /**
   * 初始化数据库表结构（优化版本）
   */
  async initialize() {
    // 如果已经初始化过，直接返回
    if (this.initialized) {
      if (PERFORMANCE_CONFIG.DEBUG) {
        console.log('Database already initialized')
      }
      return
    }

    await this.getDB()

    try {
      // 批量执行建表语句
      const createStatements = this.getCreateStatements()

      // 批量执行
      await this.batch(createStatements)

      this.initialized = true

      if (PERFORMANCE_CONFIG.DEBUG) {
        console.log('Database tables initialized successfully')
      }
    } catch (err) {
      console.error('Error initializing database tables:', err)
      throw new Error('数据库表初始化失败: ' + (err.message || err.toString()))
    }
  }



  /**
   * 获取表的列名
   * @param {string} tableName - 表名
   * @returns {Array} 列名数组
   */
  async getColumns(tableName) {
    const result = await this.query(`PRAGMA table_info(${tableName})`)
    return result.map(row => row.name)
  }

  /**
   * 关闭数据库连接
   */
  async close() {
    if (!this.db) return

    try {
      // 确保保存数据
      if (!this.isNative) {
        this.save()
      }

      if (this.isNative && this.sqlite) {
        await this.db.close()
        await this.sqlite.closeConnection(this.dbName, false)
      } else if (this.db) {
        this.db.close()
      }
      if (PERFORMANCE_CONFIG.DEBUG) {
        console.log('Database connection closed')
      }
    } catch (err) {
      console.error('Error closing database:', err)
    } finally {
      this.db = null
      this.initialized = false
      this.clearCache()
      if (this.saveTimer) {
        clearTimeout(this.saveTimer)
      }
    }
  }

  /**
   * 获取数据库状态信息
   */
  getStatus() {
    return {
      isNative: this.isNative,
      connected: !!this.db,
      initialized: this.initialized,
      connecting: this.connecting,
      cacheSize: this.cache.size
    }
  }

  /**
   * 清空所有数据（使用事务提高性能）
   */
  async clearAllData() {
    const tables = ['accounts', 'transactions', 'assets', 'stocks', 'funds', 'liabilities', 'repayments', 'pending_repayments', 'financial_goals', 'categories']
    
    try {
      // 事务状态
      let transactionStarted = false
      
      try {
        // 开始事务
        await this.run('BEGIN TRANSACTION')
        transactionStarted = true
        
        for (const table of tables) {
          try {
            await this.run(`DELETE FROM ${table}`, [])
          } catch (e) {
            if (PERFORMANCE_CONFIG.DEBUG) {
              console.log(`Table ${table} may not exist`)
            }
          }
        }
        
        try {
          // 提交事务
          await this.run('COMMIT')
          transactionStarted = false
        } catch (commitError) {
          // 提交失败时，事务已经结束，不需要回滚
          transactionStarted = false
          throw commitError
        }
        
        // 清除缓存
        this.clearCache()
        
        return true
      } catch (e) {
        // 回滚事务（只有在事务真正开始后才执行）
        if (transactionStarted) {
          try {
            await this.run('ROLLBACK')
          } catch (rollbackErr) {
            console.error('Rollback error:', rollbackErr)
          }
        }
        throw e
      }
    } catch (e) {
      console.error('Error clearing all data:', e)
      throw e
    }
  }
}

// 全局单例
const dbManager = new DatabaseManager()

// 导出兼容接口
const db = {
  async connect() {
    return await dbManager.initialize()
  },

  async query(sql, params = [], useCache = false) {
    return await dbManager.query(sql, params, useCache)
  },

  async run(sql, params = []) {
    return await dbManager.run(sql, params)
  },

  async batch(statements) {
    return await dbManager.batch(statements)
  },

  async executeTransaction(callback) {
    return await dbManager.executeTransaction(callback)
  },

  async close() {
    return await dbManager.close()
  },

  getStatus() {
    return dbManager.getStatus()
  },

  async clearAllData() {
    return await dbManager.clearAllData()
  }
}

export default db

// 导出管理器供高级用法
export { dbManager }
