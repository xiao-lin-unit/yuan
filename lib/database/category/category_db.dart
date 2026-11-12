import 'package:flutter/cupertino.dart';
import 'package:sqflite/sqflite.dart';

import '../db_module.dart';
import 'category_record.dart';

/// 一条系统预设分类（名字 + 内置图标语义 key + 顺序）。
///
/// 图标 key 只描述语义，真正的 IconData 由 [AppIcons.categoryIcon] 解析，
/// 数据库里不存字体码点 / 颜色 / emoji，换图标体系时不用迁移数据。
@immutable
class CategorySeed {
  const CategorySeed(this.name, this.iconKey, this.kind, this.order);

  final String name;
  final String iconKey;
  final CategoryKind kind;
  final int order;
}

/// `categories` 表：**一张表同时存支出与收入分类**，用 `kind` 区分。
///
/// ── 为什么这样建，能覆盖哪些后续业务 ────────────────────────────
/// 目标是一次定死，不因为「业务没变」而二次 ALTER TABLE。所有字段都
/// 对应《软件设计想法》里已经写明的功能，不是随手预留：
///
/// | 字段 | 出处 |
/// |---|---|
/// | kind / name / icon_kind / icon_value | 原型分类管理页；10.5 扁平一层 |
/// | sort_order | 原型拖拽排序 / 填序号；4.6「快速记」按序展示 |
/// | preset / hidden | 10.5「预设不能删，但可以不显示」 |
/// | necessity | 4.2 必须花的 / 可省的；8.2 失业推演只用「必须花的」 |
/// | stability | 5.2 每月都有 / 偶尔才有；8.1 固定收入 |
/// | budget_limit | 4.6 预算提醒；十一章「预算（高）」 |
/// | book_id | 十一章「多个账本：个人 / 全家」 |
/// | created_at / updated_at / revision | 10.2 公共字段、10.9 变更留痕 |
/// | deleted_at / delete_reason | 10.2 删除标记、10.7 回收站 30 天、10.9 留痕「为什么」 |
///
/// ── 明确不放进这张表的东西（避免把表做成垃圾桶）────────────────
/// · parent_id：10.5 规定「只有一层，不分级」，加了就是给未来的错误开口；
/// · last_used_at / use_count：4.6 最近用过的分类由流水聚合，不冗余；
/// · 受限账户绑定用途（3.5）：账户↔分类是**多对多**，将来新增
///   `account_category_bindings` 关联表，属于新增业务表，不是修改本表；
/// · 每月自动记（4.6）：是 `recurring_rules` 记录模板，独立表；
/// · 完整变更历史（10.9「改了什么」）：将来做全局 `change_log` 审计表，
///   `revision` 只提供版本号，不把 JSON 快照塞进主表。
///
/// ── 约束 ────────────────────────────────────────────────────────
/// · CHECK 锁死所有枚举取值，脏数据进不来；
/// · 部分唯一索引 `(book_id, kind, name) WHERE deleted_at IS NULL`：
///   同一账本同一类型下不能重名；回收站里的旧名不占用名额，允许重建；
/// · 列表索引覆盖 `(book_id, kind, deleted_at, sort_order, id)`，
///   记账选择器 / 管理页列表都走它，不需要全表扫描。
class CategoryDb implements DbModule {
  static const tableName = 'categories';

  @override
  String get name => 'category';

  /// 预设支出分类（4.1，31 条）与收入分类（5.1，10 条），顺序即原型顺序。
  /// 图标 key 见 AppIcons.categoryIcons；同一图标可被多个语义相近的分类复用，
  /// 这是矢量图标语言相对 emoji 的正常取舍（线宽统一、随主题取色）。
  static const List<CategorySeed> seeds = <CategorySeed>[
    // ── 支出 4.1 ──
    CategorySeed('三餐', 'meal', CategoryKind.expense, 0),
    CategorySeed('零食饮料', 'drink', CategoryKind.expense, 1),
    CategorySeed('水果', 'fruit', CategoryKind.expense, 2),
    CategorySeed('外卖', 'takeout', CategoryKind.expense, 3),
    CategorySeed('买菜做饭', 'grocery', CategoryKind.expense, 4),
    CategorySeed('水电燃气', 'utility', CategoryKind.expense, 5),
    CategorySeed('物业', 'property', CategoryKind.expense, 6),
    CategorySeed('房租', 'rent', CategoryKind.expense, 7),
    CategorySeed('话费网费', 'phone', CategoryKind.expense, 8),
    CategorySeed('看病买药', 'medical', CategoryKind.expense, 9),
    CategorySeed('日用品', 'daily', CategoryKind.expense, 10),
    CategorySeed('交通', 'transport', CategoryKind.expense, 11),
    CategorySeed('加油', 'fuel', CategoryKind.expense, 12),
    CategorySeed('打车', 'taxi', CategoryKind.expense, 13),
    CategorySeed('衣服鞋帽', 'apparel', CategoryKind.expense, 14),
    CategorySeed('美容护肤', 'beauty', CategoryKind.expense, 15),
    CategorySeed('教育学习', 'study', CategoryKind.expense, 16),
    CategorySeed('书报杂志', 'books', CategoryKind.expense, 17),
    CategorySeed('孩子花销', 'child', CategoryKind.expense, 18),
    CategorySeed('孝敬长辈', 'elders', CategoryKind.expense, 19),
    CategorySeed('宠物', 'pet', CategoryKind.expense, 20),
    CategorySeed('人情往来', 'gift', CategoryKind.expense, 21),
    CategorySeed('娱乐休闲', 'entertainment', CategoryKind.expense, 22),
    CategorySeed('旅游出行', 'travel', CategoryKind.expense, 23),
    CategorySeed('烟酒', 'tobacco', CategoryKind.expense, 24),
    CategorySeed('健身运动', 'fitness', CategoryKind.expense, 25),
    CategorySeed('家居装修', 'homeImprovement', CategoryKind.expense, 26),
    CategorySeed('电器数码', 'digital', CategoryKind.expense, 27),
    CategorySeed('保险', 'insurance', CategoryKind.expense, 28),
    CategorySeed('税费', 'tax', CategoryKind.expense, 29),
    CategorySeed('其他', 'other', CategoryKind.expense, 30),
    // ── 收入 5.1 ──
    CategorySeed('工资', 'salary', CategoryKind.income, 0),
    CategorySeed('奖金', 'bonus', CategoryKind.income, 1),
    CategorySeed('兼职外快', 'sideJob', CategoryKind.income, 2),
    CategorySeed('投资收益', 'investment', CategoryKind.income, 3),
    CategorySeed('退款退货', 'refund', CategoryKind.income, 4),
    CategorySeed('报销到账', 'reimbursement', CategoryKind.income, 5),
    CategorySeed('礼金红包', 'giftMoney', CategoryKind.income, 6),
    CategorySeed('二手变卖', 'secondHand', CategoryKind.income, 7),
    CategorySeed('中奖', 'lottery', CategoryKind.income, 8),
    CategorySeed('其他', 'other', CategoryKind.income, 9),
  ];

  /// 建表 + 索引 + 预设种子。
  ///
  /// 幂等：全新安装走 `_onCreate`，v2→v3 升级走 `_onUpgrade`，
  /// 两边都调这里；`IF NOT EXISTS` + `INSERT OR IGNORE` 保证重复执行不炸。
  /// 不自己开 transaction —— DatabaseService._onCreate 已经把整个模块
  /// 列表包在一个事务里，sqflite 不支持嵌套 transaction。
  @override
  Future<void> onCreate(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableName (
        id            INTEGER PRIMARY KEY ,
        book_id       TEXT    NOT NULL DEFAULT 'default',
        kind          TEXT    NOT NULL CHECK (kind IN ('expense','income')),
        name          TEXT    NOT NULL,
        icon_kind     TEXT    NOT NULL DEFAULT 'icon'
                      CHECK (icon_kind IN ('icon','image','text')),
        icon_value    TEXT    NOT NULL DEFAULT '',
        sort_order    INTEGER NOT NULL DEFAULT 0,
        preset        INTEGER NOT NULL DEFAULT 0 CHECK (preset IN (0,1)),
        hidden        INTEGER NOT NULL DEFAULT 0 CHECK (hidden IN (0,1)),
        necessity     TEXT    NOT NULL DEFAULT 'unset'
                      CHECK (necessity IN ('unset','must','flex')),
        stability     TEXT    NOT NULL DEFAULT 'unset'
                      CHECK (stability IN ('unset','fixed','occasional')),
        budget_limit  REAL,
        deleted_at    INTEGER,
        delete_reason TEXT,
        created_at    INTEGER NOT NULL,
        updated_at    INTEGER NOT NULL,
        revision      INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS uq_categories_active_name
        ON $tableName (book_id, kind, name) WHERE deleted_at IS NULL
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_categories_list
        ON $tableName (book_id, kind, deleted_at, sort_order, id)
    ''');

    final int now = DateTime.now().millisecondsSinceEpoch;
    for (final CategorySeed seed in seeds) {
      await db.rawInsert(
        'INSERT OR IGNORE INTO $tableName '
        '(book_id, kind, name, icon_kind, icon_value, sort_order, preset, '
        ' hidden, necessity, stability, created_at, updated_at, revision) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        <Object?>[
          'default',
          seed.kind.dbValue,
          seed.name,
          'icon',
          seed.iconKey,
          seed.order,
          1, // preset
          0, // hidden
          'unset',
          'unset',
          now,
          now,
          1,
        ],
      );
    }
  }
}
