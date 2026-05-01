# 裕安 — 个人财务管理应用

一款跨平台个人财务管理应用，支持 Android、Electron 桌面端和 Web 浏览器运行。提供完整的资产管理、负债追踪、收支记录、金融沙箱模拟及理财知识库等功能。

## 功能模块

### 账户管理 (`src/components/mobile/account/`)

管理各类金融账户，包括现金、储蓄卡、信用卡等。支持账户创建、余额调整、信用卡还款、跨账户转账，以及账户详情页展示入出账流水记录。

- **AccountManagement.vue** — 账户列表总览
- **AccountDetailPage.vue** — 账户详情（含入出账流水、余额调整、信用卡还款）
- **AddAccountPage.vue** — 新增账户
- **TransferForm.vue** — 转账操作
- **RepayCreditCardPage.vue** — 信用卡还款

### 资产管理 (`src/components/mobile/asset/`)

管理普通资产（储蓄、理财等）、股票和基金。支持资产的全生命周期管理——创建、买入、卖出、收益记录和状态切换。股票和基金基于持仓 FIFO 模型计算成本和收益。

- **AssetManagement.vue** — 资产总览（含视图切换：活跃/已结束）
- **AddAssetPage.vue / AddStockPage.vue / AddFundPage.vue** — 新增各类资产
- **AssetDetailPage.vue / StockDetailPage.vue / FundDetailPage.vue** — 资产详情与编辑
- **BuyStockPage.vue / BuyFundPage.vue** — 买入股票/基金
- **SellStockPage.vue / SellFundPage.vue** — 卖出股票/基金

### 负债管理 (`src/components/mobile/liability/`)

管理房贷、消费贷等各类负债。支持等额本息、等额本金、先息后本等多种还款方式，自动计算月供、总利息及还款计划。

- **LiabilityManagement.vue** — 负债列表
- **AddLiabilityPage.vue** — 新增负债
- **LiabilityDetailPage.vue** — 负债详情（还款计划、提前还款、还款记录）

### 收入模块 (`src/components/mobile/income/`)

记录和统计各类收入（工资、奖金等），按日/周/月/年维度展示收入数据，支持分类统计图表。

- **AddIncomePage.vue** — 录入收入
- **DailyIncome.vue / WeeklyIncome.vue** — 日/周收入明细
- **IncomeStats.vue** — 收入统计图表
- **MonthlyStats.vue** — 月度收支概览

### 支出模块 (`src/components/mobile/expense/`)

记录和统计各类消费支出，按日/周/月维度展示支出数据，支持分类占比分析、日历热力图和预算管理。

- **AddExpensePage.vue** — 录入支出
- **DailyExpense.vue / WeeklyExperse.vue** — 日/周支出明细
- **ExpenseStats.vue** — 支出统计图表
- **BudgetComponent.vue** — 预算管理

### 金融沙箱 (`src/components/mobile/sandbox/`)

提供多场景金融模拟，包括失业风险、利率上涨、收入上涨、新增支出、收入下降等。基于用户实际财务数据计算净资产走势、月现金流、负债压力等指标，并以图表展示变化趋势。

- **SandboxSimulationPage.vue** — 模拟参数配置
- **SandboxResultDetail.vue** — 模拟结果详情与图表
- **SandboxHistory.vue** — 历史模拟记录

### 理财知识库 (`src/components/mobile/knowledge/`)

内置金融知识文章，支持分类浏览、收藏和阅读历史记录。

- **KnowledgeHome.vue** — 知识库首页
- **KnowledgeArticle.vue** — 文章详情（Markdown 渲染）
- **KnowledgeCategory.vue** — 分类浏览
- **KnowledgeProfile.vue** — 收藏与阅读历史

### 更多功能 (`src/components/mobile/goal/`, `src/components/mobile/more/`)

- **FinancialGoal.vue** — 财务目标设定与追踪
- **MoreFeatures.vue** — 更多功能入口

### 自动任务系统 (`src/auto/`)

应用启动时自动执行的后台任务：

- **assetTask.ts** — 自动计算资产收益并更新账户余额
- **liabilityTask.ts** — 自动处理到期负债还款
- **snapshotTask.ts** — 自动生成月度财务快照

## 服务层 (`src/services/`)

| 服务 | 文件 | 职责 |
|------|------|------|
| 账户服务 | `account/accountService.ts` | 账户 CRUD、余额出入账、转账、信用卡还款 |
| 资产服务 | `asset/assetService.ts` | 普通资产 CRUD、收益计算 |
| 股票服务 | `asset/stockService.ts` | 股票买卖、持仓 FIFO 计算、盈亏追踪 |
| 基金服务 | `asset/fundService.ts` | 基金买卖、持仓 FIFO 计算、锁定到期处理 |
| 负债服务 | `liability/liabilityService.ts` | 负债 CRUD、还款计划生成、提前还款 |
| 沙箱服务 | `sandbox/sandboxService.ts` | 金融模拟场景计算、历史记录管理 |
| 知识服务 | `knowledge/knowledgeService.ts` | 知识文章获取、收藏与阅读记录 |
| 分类服务 | `categoryService.ts` | 收支分类数据管理 |

## 数据存储

应用使用 **SQLite** 作为本地数据库，通过 `sql.js`（Web/Electron）和 `@capacitor-community/sqlite`（Android）实现跨平台数据持久化。

### 核心数据表

| 表名 | 用途 |
|------|------|
| `accounts` | 账户信息（现金、储蓄卡、信用卡等） |
| `income_expense_records` | 用户收支记录（收入页录入的收入、支出页录入的消费） |
| `account_transactions` | 账户交易流水（所有余额变动：资产收益入账、负债还款出账等） |
| `assets` | 普通资产（储蓄、理财等） |
| `stocks` / `stock_holdings` / `stock_transactions` | 股票持仓与交易记录 |
| `funds` / `fund_holdings` / `fund_transactions` | 基金持仓与交易记录 |
| `liabilities` / `repayments` / `pending_repayments` | 负债、还款记录与待还计划 |
| `asset_income_records` | 资产收益发放记录 |
| `asset_monthly_snapshots` | 月度财务快照 |
| `financial_goals` | 财务目标 |
| `sandbox_history` / `sandbox_result` | 沙箱模拟历史与结果 |
| `categories` | 收支分类 |

## 技术栈

### 前端框架

| 技术 | 版本 | 用途 |
|------|------|------|
| Vue 3 | ^3.5.32 | 前端框架（Composition API） |
| TypeScript | ^5.2.2 | 类型安全 |
| Vite | ^5.3.1 | 构建工具 |
| Pinia | ^2.1.7 | 状态管理 |
| Element Plus | ^2.13.7 | UI 组件库 |

### 跨平台

| 技术 | 版本 | 用途 |
|------|------|------|
| Capacitor | ^6.1.2 | 跨平台运行时（Android） |
| Electron | ^29.3.1 | 桌面端运行时 |

### 数据与可视化

| 技术 | 版本 | 用途 |
|------|------|------|
| sql.js | ^1.10.3 | Web/Electron 端 SQLite 引擎 |
| @capacitor-community/sqlite | ^6.0.1 | Android 端 SQLite 插件 |
| ECharts | ^6.0.0 | 数据可视化图表 |
| Chart.js | ^4.5.1 | 辅助图表 |
| dayjs | ^1.11.20 | 日期处理 |

### Android 构建

| 技术 | 版本 |
|------|------|
| Android Gradle Plugin | 8.2.1 |
| Gradle | 8.2.1 |
| JDK | 17（sourceCompatibility / targetCompatibility） |
| compileSdkVersion | 34 |
| minSdkVersion | 22 |
| targetSdkVersion | 34 |

### 开发与测试

| 技术 | 版本 | 用途 |
|------|------|------|
| Vitest | ^4.1.5 | 单元/集成测试 |
| jsdom | ^29.1.0 | 测试 DOM 环境 |
| @vue/test-utils | ^2.4.9 | Vue 组件测试 |
| electron-builder | ^24.13.3 | Electron 打包 |
| sass-embedded | ^1.99.0 | Sass 样式预处理 |

## 快速开始

### 环境要求

- **Node.js** >= 18
- **JDK 17**（Android 构建需要）
- **Android SDK**（Android 构建需要，API Level 34）
- **Python 3**（部分脚本依赖）

### 安装依赖

```bash
npm install
```

### 开发模式

```bash
# Web 开发服务器
npm run dev
```

### 运行测试

```bash
npm run test
```

### 构建打包

```bash
# Web 构建
npm run build
```

### Android 构建

```bash
# 1. 构建 Web 资源
npm run build

# 2. 同步到 Android 项目
npx cap sync

# 3. 生成 Android 图标（可选）
npm run generate:icons

# 4. 打开 Android Studio 进行构建
npx cap open android
```
### Android 打包

```bash
npm run build:android:apk:release
```

在 Android Studio 中选择 **Build → Generate Signed Bundle / APK** 输出安装包。

> **注意**：Android 构建需要 JDK 17，请确保 `JAVA_HOME` 环境变量指向 JDK 17 安装路径。

## 项目结构

```
src/
├── App.vue                    # 根组件
├── main.ts                    # 入口文件
├── assets/                    # 静态资源
├── auto/                      # 自动任务系统
│   ├── index.ts               # 任务调度器
│   └── tasks/                 # 具体任务
│       ├── assetTask.ts       # 资产收益自动计算
│       ├── liabilityTask.ts   # 负债还款自动处理
│       └── snapshotTask.ts    # 月度快照自动生成
├── components/
│   ├── common/                # 通用组件（Header, Footer, SideMenu 等）
│   └── mobile/                # 业务组件
│       ├── account/           # 账户管理
│       ├── asset/             # 资产管理
│       ├── expense/           # 支出模块
│       ├── goal/              # 财务目标
│       ├── income/            # 收入模块
│       ├── knowledge/         # 知识库
│       ├── liability/         # 负债管理
│       └── sandbox/           # 金融沙箱
├── data/                      # 静态数据（分类字典等）
├── database/
│   ├── index.js               # 数据库管理器（连接、建表、迁移、缓存）
│   └── adapter.js             # 平台适配器
├── services/                  # 业务服务层
│   ├── account/               # 账户服务
│   ├── asset/                 # 资产/股票/基金服务
│   ├── liability/             # 负债服务
│   ├── sandbox/               # 沙箱服务
│   ├── knowledge/             # 知识库服务
│   └── categoryService.ts     # 分类服务
├── stores/                    # Pinia 状态管理
├── types/                     # TypeScript 类型定义
└── utils/                     # 工具函数（时区、ID 生成、字典）
tests/                         # 测试文件
├── utils/testDb.ts            # 测试数据库辅助
├── account.test.ts            # 账户模块测试
├── asset.test.ts              # 资产模块测试
├── expense.test.ts            # 支出模块测试
├── income.test.ts             # 收入模块测试
├── liability.test.ts          # 负债模块测试
├── financialHealth.test.ts    # 财务健康评估测试
└── sandbox.test.ts            # 沙箱模块测试
```

## License

本项目采用 [CC BY-NC 4.0](https://creativecommons.org/licenses/by-nc/4.0/) 许可协议发布。

- ✅ 允许：个人使用、学习、修改、分发
- ❌ 禁止：商业用途

详见 [LICENSE](./LICENSE) 文件。
