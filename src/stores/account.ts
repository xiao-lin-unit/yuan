/**
 * 账户管理Store
 * 负责账户的增删改查、余额调整和内部转账操作
 */
import { defineStore } from 'pinia'
import db from '../database'
import { getCurrentDate } from '../utils/timezone'

/**
 * 账户接口
 */
export interface Account {
  id: string         // 账户ID
  name: string       // 账户名称
  type: string       // 账户类型
  balance: number    // 账户余额
  used_limit?: number // 已用额度（信用卡）
  total_limit?: number // 总额度（信用卡）
  is_liquid?: boolean // 是否为流动资金
  remark: string     // 备注
  created_at?: string // 创建时间
  updated_at?: string // 更新时间
}

/**
 * 账户管理Store
 */
export const useAccountStore = defineStore('account', {
  state: () => ({
    accounts: [] as Account[],  // 账户列表
    loading: false,           // 加载状态
    error: null as string | null // 错误信息
  }),

  actions: {
    /**
     * 加载账户列表
     */
    async loadAccounts() {
      this.loading = true
      try {
        // 连接数据库
        await db.connect()
        // 查询所有账户
        const accounts = await db.query('SELECT * FROM accounts')
        console.log('Loaded accounts:', JSON.stringify(accounts))
        this.accounts = accounts
      } catch (error) {
        this.error = '加载账户失败'
        console.error(error)
      } finally {
        this.loading = false
      }
    },

    /**
     * 添加账户
     * @param account 账户信息
     */
    async addAccount(account: any) {
      try {
        console.log('Starting addAccount process...')
        // 连接数据库
        await db.connect()
        console.log('Database connected')
        
        // 生成账户ID
        const id = getCurrentDate().valueOf().toString()
        console.log('Generated account ID:', id)
        
        // 准备账户数据
        const accountData = {
          id: id,
          name: account.name,
          type: account.type,
          balance: account.balance || 0,
          used_limit: account.used_limit || 0,
          total_limit: account.total_limit || 0,
          is_liquid: account.is_liquid !== undefined ? account.is_liquid : true,
          remark: account.remark || ''
        }
        console.log('Prepared account data:', accountData)
        
        // 插入账户记录
        const result = await db.run(
          'INSERT INTO accounts (id, name, type, balance, used_limit, total_limit, is_liquid, remark) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
          [accountData.id, accountData.name, accountData.type, accountData.balance, accountData.used_limit, accountData.total_limit, accountData.is_liquid, accountData.remark]
        )
        console.log('Add account result:', result)
        
        // 重新加载账户列表
        console.log('Reloading accounts...')
        await this.loadAccounts()
        console.log('Accounts after reload:', this.accounts)
        console.log('Add account process completed successfully')
      } catch (error: any) {
        this.error = '添加账户失败: ' + (error?.message || error?.toString() || '未知错误')
        console.error('Error adding account:', error)
        throw new Error(this.error)
      }
    },

    /**
     * 更新账户信息
     * @param account 账户信息
     */
    async updateAccount(account: any) {
      try {
        // 连接数据库
        await db.connect()
        // 更新账户记录
        await db.run(
          'UPDATE accounts SET name = ?, type = ?, balance = ?, used_limit = ?, total_limit = ?, is_liquid = ?, remark = ? WHERE id = ?',
          [account.name, account.type, account.balance || 0, account.used_limit || 0, account.total_limit || 0, account.is_liquid || true, account.remark, account.id]
        )
        // 重新加载账户列表
        await this.loadAccounts()
      } catch (error) {
        this.error = '更新账户失败'
        console.error(error)
      }
    },

    /**
     * 删除账户
     * @param id 账户ID
     */
    async deleteAccount(id: string) {
      try {
        // 连接数据库
        await db.connect()
        // 删除账户记录
        await db.run('DELETE FROM accounts WHERE id = ?', [id])
        // 重新加载账户列表
        await this.loadAccounts()
      } catch (error) {
        this.error = '删除账户失败'
        console.error(error)
      }
    },

    /**
     * 调整账户余额
     * @param data 调整数据
     */
    async adjustBalance(data: { accountId: string; type: string; amount: number; remark: string }) {
      try {
        // 连接数据库
        await db.connect()
        // 查找账户
        const account = this.accounts.find(a => a.id === data.accountId)
        if (!account) {
          throw new Error('账户不存在')
        }

        // 计算新余额
        const newBalance = account.balance + data.amount
        if (newBalance < 0) {
          throw new Error('余额不足')
        }

        // 准备事务语句
        const transactionId = getCurrentDate().valueOf().toString()
        const statements = [
          // 更新账户余额
          {
            statement: 'UPDATE accounts SET balance = ? WHERE id = ?',
            values: [newBalance, data.accountId]
          },
          // 记录流水
          {
            statement: 'INSERT INTO transactions (id, type, amount, account_id, balance_after, remark) VALUES (?, ?, ?, ?, ?, ?)',
            values: [transactionId, '余额调整', data.amount, data.accountId, newBalance, data.remark]
          }
        ]

        // 使用事务执行所有操作
        await db.executeTransaction(statements)

        // 重新加载账户列表
        await this.loadAccounts()
      } catch (error) {
        this.error = '调整余额失败'
        console.error(error)
      }
    },

    /**
     * 内部转账
     * @param data 转账数据
     */
    async transfer(data: { fromAccountId: string; toAccountId: string; amount: number; remark: string }) {
      try {
        // 连接数据库
        await db.connect()
        // 检查转出账户和转入账户是否相同
        if (data.fromAccountId === data.toAccountId) {
          throw new Error('转出账户和转入账户不能相同')
        }

        // 查找转出账户和转入账户
        const fromAccount = this.accounts.find(a => a.id === data.fromAccountId)
        const toAccount = this.accounts.find(a => a.id === data.toAccountId)

        if (!fromAccount || !toAccount) {
          throw new Error('账户不存在')
        }

        // 检查转出账户余额是否充足
        if (fromAccount.balance < data.amount) {
          throw new Error('转出账户余额不足')
        }

        // 事务状态
        let transactionStarted = false
        
        try {
          // 开始事务
          await db.run('BEGIN TRANSACTION')
          transactionStarted = true
          
          // 更新转出账户余额
          const newFromBalance = fromAccount.balance - data.amount
          await db.run('UPDATE accounts SET balance = ? WHERE id = ?', [newFromBalance, data.fromAccountId])

          // 更新转入账户余额
          const newToBalance = toAccount.balance + data.amount
          await db.run('UPDATE accounts SET balance = ? WHERE id = ?', [newToBalance, data.toAccountId])

          // 记录转出流水
          const transactionId1 = getCurrentDate().valueOf().toString() + '1'
          await db.run(
            'INSERT INTO transactions (id, type, amount, account_id, balance_after, remark) VALUES (?, ?, ?, ?, ?, ?)',
            [transactionId1, '转账支出', -data.amount, data.fromAccountId, newFromBalance, data.remark]
          )

          // 记录转入流水
          const transactionId2 = getCurrentDate().valueOf().toString() + '2'
          await db.run(
            'INSERT INTO transactions (id, type, amount, account_id, balance_after, remark) VALUES (?, ?, ?, ?, ?, ?)',
            [transactionId2, '转账收入', data.amount, data.toAccountId, newToBalance, data.remark]
          )

          try {
            // 提交事务
            await db.run('COMMIT')
            transactionStarted = false
          } catch (commitError) {
            // 提交失败时，事务已经结束，不需要回滚
            transactionStarted = false
            throw commitError
          }

          // 重新加载账户列表
          await this.loadAccounts()
        } catch (error) {
          // 回滚事务（只有在事务真正开始后才执行）
          if (transactionStarted) {
            try {
              await db.run('ROLLBACK')
            } catch (rollbackErr) {
              console.error('回滚错误:', rollbackErr)
            }
          }
          throw error
        }
      } catch (error) {
        this.error = '转账失败'
        console.error(error)
      }
    }
  }
})
