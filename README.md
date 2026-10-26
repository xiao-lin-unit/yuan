# yuan - 记账软件

一个面向大众的个人财务管理软件。数据全部保存在本地，不上传任何远程服务器。

## 技术栈

- Flutter 3.x + Dart 3.x
- 状态管理：StatefulWidget + FutureBuilder（轻量场景，未引入三方状态库）
- 本地存储：SQLite（`sqflite`，当前由 DAO 层模拟，接入真实数据库只需替换 DAO 实现）
- 金额精度：`Money` 值对象，内部以"分"为单位整数存储，杜绝 double 累加误差

## 项目结构

```
lib/
├── main.dart                    # 入口
├── app.dart                     # MaterialApp + 主题
├── models/                      # 领域模型（纯 Dart，业务语言）
│   ├── money.dart               # 金额值对象
│   ├── category.dart            # 收支分类（扁平一层）
│   ├── account.dart             # 账户（3类 + 受限账户绑定用途）
│   ├── transaction.dart         # 收支/转账记录
│   ├── asset.dart               # 资产（普通/股票/基金/借出）
│   └── liability.dart           # 负债 + 还款计划自动生成
├── services/                    # 业务层
│   ├── result.dart              # Result<T> 统一返回类型
│   ├── services.dart            # 服务门面（单例）
│   ├── account_service.dart     # 账户业务
│   ├── transaction_service.dart # 收支业务
│   ├── asset_service.dart       # 资产业务
│   ├── liability_service.dart   # 负债业务
│   ├── summary_service.dart     # 汇总统计
│   ├── health_service.dart      # 财务健康分析
│   ├── simulation_service.dart  # 情景推演
│   ├── database_service.dart    # 数据库建表 + 完整性校验
│   └── dao/                    # 数据访问对象
│       ├── account_dao.dart
│       ├── account_flow_dao.dart
│       ├── transaction_dao.dart
│       ├── asset_dao.dart
│       ├── liability_dao.dart
│       ├── repayment_record_dao.dart
│       ├── expense_category_dao.dart
│       └── income_category_dao.dart
├── screens/                     # 5 大模块页面（已接通真数据）
│   ├── home_screen.dart         # 底部 5 Tab
│   ├── transaction/             # 收支录入
│   ├── ledger/                 # 资债 + 明细页
│   ├── accounts/               # 账户列表 + 账户操作
│   ├── analysis/               # 分析 + 情景推演
│   └── profile/
└── utils/
    ├── amount_formatter.dart    # 金额格式化（千分位、符号、红绿色）
    └── date_utils.dart
```

## 架构说明

### 分层

```
UI 层（screens/）
   ↓ 调用
业务服务层（services/，除 dao 与 database_service）
   ↓ 调用
数据访问层（services/dao/）
   ↓ 对接
数据库（SQLite / sqflite）
```

### 数据流

1. UI 层只调用 `Services.instance.xxx`，不直接接触 DAO
2. 所有业务操作通过 `Result<T>` 返回，UI 层据此决定提示成功还是失败
3. DAO 层当前使用内存种子数据（`seed*` 常量），接入真实数据库时只需替换 DAO 实现类，无需改动服务层与 UI 层

### 接入真实数据库

在 `pubspec.yaml` 添加 `sqflite` 依赖，然后：

```dart
// 1. 新建 sqflite 实现类
class AccountDaoSqflite implements AccountDao { ... }

// 2. 在 Services 门面中注入
final Services services = Services.instance;
```

服务层与 UI 层无需任何改动。

## 运行

```bash
flutter pub get
flutter run
```

## 当前状态

- [x] 领域模型（6 个）
- [x] 数据访问层（8 个 DAO + 内存种子数据）
- [x] 业务服务层（7 个服务）
- [x] 5 大模块页面接通真数据
- [x] 账户/资产/负债明细页出入记录
- [x] 转账与余额调整的业务校验
- [x] 财务健康评分
- [x] 情景推演（14 种情景 + 冲突检测）
- [ ] 接入 sqflite 真实数据库
- [ ] 图表库（fl_chart）接入分析页
- [ ] 数据加密与应用锁
- [ ] 导入导出
