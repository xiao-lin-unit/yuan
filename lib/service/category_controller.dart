import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../database/category/category_dao.dart';
import '../database/category/category_record.dart';
import 'image/image_category.dart';
import 'image/image_ref.dart';
import 'image/image_service.dart';

/// 分类管理的唯一状态入口（ChangeNotifier，由 Services.initServices 装配）。
///
/// 【唯一的动态逻辑，工作逻辑写清楚】
/// 为什么动态：分类列表会随用户的「切换收支类型 / 隐藏 / 排序 / 编辑 /
/// 删除」实时变化，构造期定不死。这里用最朴素的 ChangeNotifier：
///   1. `_all` 是数据库里全部未删分类在内存里的一份只读快照；
///   2. 任何写操作都 **先 await 落库 → 再 load() 重读 → notifyListeners()**
///      （10.8 即时保存；失败时内存保持旧值，绝不悄悄改界面）；
///   3. 页面用 `context.watch<CategoryController>()` 读，用 getter 过滤，
///      不在页面里另存一份列表，避免两套真源。
/// 没有 Notifier 嵌套、没有跨帧回调、没有运行时注册。
///
/// 图片沿用统一图片层的两阶段提交：新图先落盘 → await 写 DB →
/// 成功才删旧图 / 失败回滚新图（与 UserController.updateProfile 同一条链路）。
class CategoryController extends ChangeNotifier {
  CategoryController(this.db, this.dao, {ImageService? images})
      : _images = images ?? ImageService.instance;

  final Database db;
  final CategoryDao dao;
  final ImageService _images;

  List<CategoryRecord> _all = <CategoryRecord>[];

  /// 内存快照（只读）。页面不要修改它。
  List<CategoryRecord> get all => List<CategoryRecord>.unmodifiable(_all);

  Future<void> load() async {
    _all = await dao.listAll(db);
    notifyListeners();
  }

  /// 记账选择器用：只看可见分类（hidden=false 且未删），按 sort_order。
  /// 将来「记一笔」页面直接调它，分类管理页的改动立刻生效。
  List<CategoryRecord> visible(CategoryKind kind) => _where(kind)
      .where((CategoryRecord r) => !r.hidden)
      .toList(growable: false);

  /// 管理页列表：是否把隐藏的一起显示由页面决定。
  List<CategoryRecord> managed(
    CategoryKind kind, {
    bool includeHidden = false,
  }) =>
      _where(kind)
          .where((CategoryRecord r) => includeHidden || !r.hidden)
          .toList(growable: false);

  List<CategoryRecord> _where(CategoryKind kind) => _all
      .where((CategoryRecord r) => r.kind == kind && !r.isDeleted)
      .toList()
    ..sort((CategoryRecord a, CategoryRecord b) {
      final int byOrder = a.sortOrder.compareTo(b.sortOrder);
      return byOrder != 0 ? byOrder : (a.id ?? 0).compareTo(b.id ?? 0);
    });

  CategoryStats statsOf(CategoryKind kind) {
    final List<CategoryRecord> rows = _where(kind);
    return CategoryStats(
      active: rows.where((CategoryRecord r) => !r.hidden).length,
      hidden: rows.where((CategoryRecord r) => r.hidden).length,
      custom: rows.where((CategoryRecord r) => !r.preset).length,
    );
  }

  /// 显示 / 隐藏切换：预设也允许（10.5「预设不能删，但可以不显示」）。
  Future<void> toggleHidden(int id) async {
    final CategoryRecord? current = await dao.byId(db, id);
    if (current == null) return;
    final DateTime now = DateTime.now();
    final int affected = await dao.update(
      db,
      current.copyWith(
        hidden: !current.hidden,
        updatedAt: now,
        revision: current.revision + 1,
      ),
    );
    if (affected == 0) throw StateError('分类状态写入未生效');
    await load();
  }

  /// 拖拽 / 填序号后的重排。
  ///
  /// [orderedVisibleIds] 是**当前页面上显示的那几条**的新顺序；隐藏项仍
  /// 留在它们原来的排序槽位里不动，这样「先隐藏几条、再拖剩下的、再
  /// 显示回来」不会把隐藏项挤到末尾。分步：
  ///   1. 取该类型全部未删记录（含隐藏），按现有顺序排好；
  ///   2. 全量列表从头扫，遇到可见槽位就依次填入新顺序的 id，
  ///      遇到隐藏项保留原 id；
  ///   3. 一次事务批量写 sort_order。
  Future<void> reorder(
    CategoryKind kind,
    List<int> orderedVisibleIds,
  ) async {
    final List<CategoryRecord> all = _where(kind);
    final Set<int> visibleIds = orderedVisibleIds.toSet();
    final List<int> result = <int>[];
    int cursor = 0;
    for (final CategoryRecord r in all) {
      final int id = r.id ?? -1;
      if (visibleIds.contains(id)) {
        if (cursor < orderedVisibleIds.length) {
          result.add(orderedVisibleIds[cursor++]);
        }
      } else {
        result.add(id);
      }
    }
    // 新建/异常兜底：没被全量列表覆盖到的可见 id 追加在末尾。
    for (final int id in orderedVisibleIds) {
      if (!result.contains(id)) result.add(id);
    }
    await dao.reorder(db, kind, result);
    await load();
  }

  /// 把某条分类插到 [targetIndex]（0-based），其余顺移。
  /// 列表行的「填序号」按钮走这里。
  Future<void> moveTo(int id, int targetIndex) async {
    final CategoryRecord? target = await dao.byId(db, id);
    if (target == null) return;
    final List<CategoryRecord> rows = managed(target.kind, includeHidden: true);
    final List<int> ids = rows
        .map((CategoryRecord r) => r.id)
        .whereType<int>()
        .where((int v) => v != id)
        .toList();
    final int clamped = targetIndex.clamp(0, ids.length).toInt();
    ids.insert(clamped, id);
    await dao.reorder(db, target.kind, ids);
    await load();
  }

  /// 删除 = 进回收站（10.7）。预设分类禁止删除，只给页面一个明确异常，
  /// 由页面提示「改成隐藏」。
  Future<void> delete(int id, {String reason = '用户在分类管理页删除'}) async {
    final CategoryRecord? current = await dao.byId(db, id);
    if (current == null) return;
    if (current.preset) {
      throw StateError('预设分类不能删除，但可以隐藏');
    }
    final int affected = await dao.softDelete(
      db,
      id,
      at: DateTime.now(),
      reason: reason,
    );
    if (affected == 0) throw StateError('分类删除未生效');
    // 删完把剩余顺序压平，不留下空洞。
    final List<CategoryRecord> rest = managed(current.kind, includeHidden: true);
    await dao.reorder(
      db,
      current.kind,
      rest.map((CategoryRecord r) => r.id).whereType<int>().toList(),
    );
    await load();
  }

  Future<void> restore(int id) async {
    final int affected = await dao.restore(db, id, DateTime.now());
    if (affected == 0) throw StateError('分类恢复未生效');
    await load();
  }

  Future<int> purgeExpired() async {
    final int n = await dao.purgeExpired(db, DateTime.now());
    if (n > 0) await load();
    return n;
  }

  /// 新增 / 编辑一条分类。
  ///
  /// [targetIndex] 是用户填的「排第几」（0-based，来自编辑器排序字段）。
  /// [icon] 描述本次选了内置图标 / 沿用旧图 / 新上传图片；新图落盘由
  /// [ImageService.plan] 统一编排，UI 不碰文件系统。
  ///
  /// 两阶段提交（与 UserController 同构，不能省）：
  ///   plan → 写 DB（检查受影响行数）→ 成功 commit() 删旧图；
  ///   任一步抛异常 → discard() 回滚本次新落盘的图片并上抛，
  ///   界面保持旧值、Sheet 不关闭。
  Future<void> save({
    int? id,
    required CategoryKind kind,
    required String name,
    required CategoryIconInput icon,
    required int targetIndex,
    required bool hidden,
    required CategoryNecessity necessity,
    required CategoryStability stability,
    double? budgetLimit,
    String bookId = CategoryDao.defaultBookId,
  }) async {
    final CategoryRecord? old = id == null ? null : await dao.byId(db, id);
    final ImageRef? existingRef = old?.icon.imageRef;

    // ① 组装图片条目：新图 / 沿用旧图 / 回到内置图标（空列表 = 删旧图）。
    final List<ImageEntry> entries = <ImageEntry>[];
    if (icon.kind == CategoryIconKind.image) {
      if (icon.candidate != null) {
        entries.add(NewImage(icon.candidate!));
      } else if (icon.imageRef != null) {
        entries.add(StoredImage(icon.imageRef!));
      }
    }
    final ImageCommitPlan plan = await _images.plan(
      ImageCategory.categoryIcon,
      entries,
      existing: existingRef == null
          ? <ImageRef>[]
          : <ImageRef>[existingRef],
      ownerId: id?.toString() ?? 'new',
    );

    try {
      // ② 把图片意图解析成最终要写进 DB 的两列。
      final CategoryIcon storedIcon = _resolveIcon(
        icon,
        plan,
        fallbackText: name.isEmpty ? '·' : name.characters.first.toString(),
      );

      final DateTime now = DateTime.now();
      final CategoryRecord record = CategoryRecord(
        id: id,
        bookId: bookId,
        kind: kind,
        name: name,
        icon: storedIcon,
        sortOrder: old?.sortOrder ?? 0,
        preset: old?.preset ?? false,
        hidden: hidden,
        // 另一种类型的标记恒为 unset，同一张表共用列。
        necessity: kind == CategoryKind.expense
            ? necessity
            : CategoryNecessity.unset,
        stability: kind == CategoryKind.income
            ? stability
            : CategoryStability.unset,
        budgetLimit: budgetLimit,
        createdAt: old?.createdAt ?? now,
        updatedAt: now,
        revision: (old?.revision ?? 0) + 1,
      );

      final int affected = id == null
          ? (await dao.insert(db, record)) // 返回新 id，>0 即成功
          : await dao.update(db, record);
      if (affected <= 0) throw StateError('分类写入未生效');

      // ③ 排序：把本条插到目标位置，其余顺移（一次事务）。
      final int savedId = id ?? affected;
      final List<CategoryRecord> rows = (await dao.listAll(db))
          .where((CategoryRecord r) =>
              r.kind == kind && r.bookId == bookId && !r.isDeleted)
          .toList()
        ..sort((CategoryRecord a, CategoryRecord b) {
          final int byOrder = a.sortOrder.compareTo(b.sortOrder);
          return byOrder != 0 ? byOrder : (a.id ?? 0).compareTo(b.id ?? 0);
        });
      final List<int> ids = rows
          .map((CategoryRecord r) => r.id)
          .whereType<int>()
          .where((int v) => v != savedId)
          .toList();
      ids.insert(targetIndex.clamp(0, ids.length).toInt(), savedId);
      await dao.reorder(db, kind, ids);

      // ④ 先把 plan 摘掉：commit 万一抛错，catch 不能再回滚已被 DB
      // 引用的新图（与 UserController 同一处保护）。
      await plan.commit();
      await load();
    } catch (_) {
      await plan.discard();
      rethrow;
    }
  }

  CategoryIcon _resolveIcon(
    CategoryIconInput input,
    ImageCommitPlan plan, {
    required String fallbackText,
  }) {
    switch (input.kind) {
      case CategoryIconKind.icon:
        final String key = input.iconKey ?? 'other';
        return CategoryIcon(kind: CategoryIconKind.icon, value: key);
      case CategoryIconKind.image:
        if (plan.refs.isNotEmpty) {
          return CategoryIcon(
            kind: CategoryIconKind.image,
            value: plan.refs.first.encode(),
          );
        }
        // 用户删掉了图片又没选内置图标 → 回退名称首字，不留悬空引用。
        return CategoryIcon(kind: CategoryIconKind.text, value: fallbackText);
      case CategoryIconKind.text:
        return CategoryIcon(kind: CategoryIconKind.text, value: fallbackText);
    }
  }

  /// 同步重名校验（给编辑器的 validator 用）。
  /// 排除自身、排除回收站里的记录；同一类型内不允许同名。
  bool nameExists(
    CategoryKind kind,
    String name, {
    int? excludeId,
  }) =>
      _where(kind).any((CategoryRecord r) =>
          r.name == name && r.id != excludeId);
}
