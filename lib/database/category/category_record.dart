import 'package:flutter/foundation.dart';

import '../../service/image/image_ref.dart';
import '../../service/image/image_validator.dart';

/// 收支类型。**一张表、用一个字段区分**，不再为收入/支出各建一张表。
///
/// 理由：两者结构完全一致（名称、图标、排序、隐藏、软删、标记），
/// 只是「语义标记」两列各自只对一种类型生效（另一种恒为 unset）。
/// 拆两张表会让记账选择器、回收站、统计、排序逻辑全部写两遍。
enum CategoryKind {
  expense('expense', '支出', '支出分类'),
  income('income', '收入', '收入分类');

  const CategoryKind(this.dbValue, this.label, this.pageTab);

  final String dbValue;
  final String label;
  final String pageTab;

  static CategoryKind fromDb(String value) => value == income.dbValue
      ? income
      : expense;

  /// 语义标记列名：支出用 necessity，收入用 stability。
  String get markColumn => this == expense ? 'necessity' : 'stability';
}

/// 图标形态。原型用 emoji 或上传图片；本项目按「全软件唯一矢量图标语言」
/// 把 emoji 换成内置 Material 图标（[icon]），上传图片走统一图片层
/// （[image]，value 存 ImageRef 编码），[text] 只作为坏数据兜底（名称首字）。
enum CategoryIconKind {
  icon('icon'),
  image('image'),
  text('text');

  const CategoryIconKind(this.dbValue);
  final String dbValue;

  static CategoryIconKind fromDb(String? value) => switch (value) {
        'image' => image,
        'text' => text,
        _ => icon,
      };
}

/// 支出专属：「必须花的 / 可省的」，不打标记就不参与判断（设计文档 4.2）。
enum CategoryNecessity {
  unset('unset', '未标记'),
  must('must', '必须花的'),
  flex('flex', '可省的');

  const CategoryNecessity(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static CategoryNecessity fromDb(String? value) => switch (value) {
        'must' => must,
        'flex' => flex,
        _ => unset,
      };
}

/// 收入专属：「每月都有 / 偶尔才有」，不打标记就不判断（设计文档 5.2）。
enum CategoryStability {
  unset('unset', '未标记'),
  fixed('fixed', '每月都有'),
  occasional('occasional', '偶尔才有');

  const CategoryStability(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static CategoryStability fromDb(String? value) => switch (value) {
        'fixed' => fixed,
        'occasional' => occasional,
        _ => unset,
      };
}

/// 已持久化的图标（DB 里就两列：icon_kind + icon_value）。
@immutable
class CategoryIcon {
  const CategoryIcon({required this.kind, required this.value});

  final CategoryIconKind kind;
  final String value;

  /// image 形态时解析出统一图片层的引用；其它形态返回 null。
  ImageRef? get imageRef =>
      kind == CategoryIconKind.image ? ImageRef.tryDecode(value) : null;

  @override
  String toString() => '${kind.dbValue}:$value';
}

/// 编辑器 → Controller 的「本次选了什么图标」契约。
///
/// 【为什么单独一个类型】编辑器里可选内置图标、可上传新图、也可保留旧图，
/// 而「新图落盘」必须发生在 Controller 的「先写盘 → 写 DB → commit/discard」
/// 事务链路里，不能让 UI 自己去碰文件系统。这里只描述意图，不含样式。
@immutable
class CategoryIconInput {
  const CategoryIconInput({
    required this.kind,
    this.iconKey,
    this.imageRef,
    this.candidate,
  });

  final CategoryIconKind kind;

  /// [icon] 形态：内置图标语义 key（见 AppIcons.categoryIcon）。
  final String? iconKey;

  /// [image] 形态且沿用旧图：已有的 ImageRef。
  final ImageRef? imageRef;

  /// [image] 形态且本次新选：内存字节，待 Controller 落盘。
  final ImageCandidate? candidate;
}

/// 分类主数据：一张 `categories` 表的完整行。
///
/// 字段设计依据（详见《分类表结构与功能页说明》）：
/// - kind / name / icon_* / sort_order / preset / hidden：原型分类管理页；
/// - necessity / stability：设计文档 4.2 / 5.2 / 10.5，两类型共用一张表；
/// - budget_limit：4.6「为某个支出类型设月预算」+ 十一章「预算（高）」；
/// - book_id：十一章「多个账本（个人 / 全家）」，默认 'default'；
/// - created_at / updated_at / revision：10.2 公共字段 + 10.9 变更留痕；
/// - deleted_at / delete_reason：10.2 / 10.7 回收站 30 天、10.9 留痕「为什么」。
///
/// 刻意**不**加 parent_id：10.5 明确「只有一层，不分级」；
/// 刻意**不**加 last_used_at / use_count：4.6「最近用过的 5 个类型」由
/// 流水表聚合得到，不该在分类表冗余一份可能算错的计数。
@immutable
class CategoryRecord {
  const CategoryRecord({
    this.id,
    this.bookId = 'default',
    required this.kind,
    required this.name,
    required this.icon,
    required this.sortOrder,
    this.preset = false,
    this.hidden = false,
    this.necessity = CategoryNecessity.unset,
    this.stability = CategoryStability.unset,
    this.budgetLimit,
    this.deletedAt,
    this.deleteReason,
    required this.createdAt,
    required this.updatedAt,
    this.revision = 1,
  });

  final int? id;
  final String bookId;
  final CategoryKind kind;
  final String name;
  final CategoryIcon icon;
  final int sortOrder;
  final bool preset;
  final bool hidden;

  /// 支出专属；收入记录恒为 unset（同一张表共用列，避免二次改表）。
  final CategoryNecessity necessity;

  /// 收入专属；支出记录恒为 unset。
  final CategoryStability stability;

  /// NULL = 未设置预算。金额只填正数，由业务校验（10.6）。
  final double? budgetLimit;

  /// NULL = 在用；非 NULL = 进回收站的时刻（10.7，30 天后自动清理）。
  final DateTime? deletedAt;
  final String? deleteReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// 每次修改 +1，供以后做变更历史 / 导入导出冲突判断，不参与 UI。
  final int revision;

  bool get isDeleted => deletedAt != null;

  static DateTime _date(Object? v) => v == null
      ? DateTime.fromMillisecondsSinceEpoch(0)
      : DateTime.fromMillisecondsSinceEpoch((v as int));

  factory CategoryRecord.fromMap(Map<String, dynamic> m) => CategoryRecord(
        id: m['id'] as int?,
        bookId: (m['book_id'] as String?) ?? 'default',
        kind: CategoryKind.fromDb(m['kind'] as String? ?? 'expense'),
        name: (m['name'] as String?) ?? '',
        icon: CategoryIcon(
          kind: CategoryIconKind.fromDb(m['icon_kind'] as String?),
          value: (m['icon_value'] as String?) ?? '',
        ),
        sortOrder: (m['sort_order'] as int?) ?? 0,
        preset: (m['preset'] as int?) == 1,
        hidden: (m['hidden'] as int?) == 1,
        necessity: CategoryNecessity.fromDb(m['necessity'] as String?),
        stability: CategoryStability.fromDb(m['stability'] as String?),
        budgetLimit: (m['budget_limit'] as num?)?.toDouble(),
        deletedAt: m['deleted_at'] == null ? null : _date(m['deleted_at']),
        deleteReason: m['delete_reason'] as String?,
        createdAt: _date(m['created_at']),
        updatedAt: _date(m['updated_at']),
        revision: (m['revision'] as int?) ?? 1,
      );

  /// 不含 id：insert 时用；update 由 DAO 单独带 where。
  Map<String, dynamic> toMap() => <String, dynamic>{
        'book_id': bookId,
        'kind': kind.dbValue,
        'name': name,
        'icon_kind': icon.kind.dbValue,
        'icon_value': icon.value,
        'sort_order': sortOrder,
        'preset': preset ? 1 : 0,
        'hidden': hidden ? 1 : 0,
        // 两列双向都写：另一种类型恒为 unset，将来若要把标记跟着类型
        // 迁移也不用 ALTER TABLE。
        'necessity': necessity.dbValue,
        'stability': stability.dbValue,
        'budget_limit': budgetLimit,
        'deleted_at': deletedAt?.millisecondsSinceEpoch,
        'delete_reason': deleteReason,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
        'revision': revision,
      };

  CategoryRecord copyWith({
    String? name,
    CategoryIcon? icon,
    int? sortOrder,
    bool? hidden,
    CategoryNecessity? necessity,
    CategoryStability? stability,
    Object? budgetLimit = _sentinel,
    Object? deletedAt = _sentinel,
    Object? deleteReason = _sentinel,
    DateTime? updatedAt,
    int? revision,
  }) =>
      CategoryRecord(
        id: id,
        bookId: bookId,
        kind: kind,
        name: name ?? this.name,
        icon: icon ?? this.icon,
        sortOrder: sortOrder ?? this.sortOrder,
        preset: preset,
        hidden: hidden ?? this.hidden,
        necessity: necessity ?? this.necessity,
        stability: stability ?? this.stability,
        budgetLimit: identical(budgetLimit, _sentinel)
            ? this.budgetLimit
            : budgetLimit as double?,
        deletedAt: identical(deletedAt, _sentinel)
            ? this.deletedAt
            : deletedAt as DateTime?,
        deleteReason: identical(deleteReason, _sentinel)
            ? this.deleteReason
            : deleteReason as String?,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        revision: revision ?? this.revision,
      );

  static const Object _sentinel = Object();
}

/// 分类管理页顶部三格统计（在用 / 已隐藏 / 自定义）。
@immutable
class CategoryStats {
  const CategoryStats({
    required this.active,
    required this.hidden,
    required this.custom,
  });

  final int active;
  final int hidden;
  final int custom;
}
