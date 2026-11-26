import 'dart:async';

import 'package:sqflite/sqflite.dart';

/// 全库**唯一**的事务入口，也是「跨接口事务一致性」的保证点。
///
/// 【为什么必须收口】整改前 26 个写动作各自 `db.transaction`：债务处理
/// 接口与账户出账接口组合时，要么两个事务互不覆盖（后者失败回滚不了
/// 前者），要么依赖驱动的嵌套事务语义；而且各接口成功后立刻
/// `refresh/notifyListeners()`，外层还没提交就把中间态推给了页面。
///
/// 【三条契约】
///   1. 所有功能接口**不自建事务**，第一参数统一收 [DatabaseExecutor]；
///      既可以是本类传入的 `Transaction`，也可以是 `Database`。
///   2. **嵌套自动并入外层事务**：A 接口内部调 B 接口时，B 的 `run`
///      通过 `Zone` 拿到同一个 txn，不再新开事务。任一步抛异常 →
///      最外层事务整体回滚，已执行的 SQL 全部撤销。
///   3. [afterCommit] 只在事务**成功提交之后**执行（刷新快照 / 通知页面
///      / 删旧图）；[onRollback] 只在回滚时执行（回滚新落盘的图片）。
///      两者都挂在最外层一次执行，嵌套层只登记、不重复触发。
///
/// 页面换掉不影响本类：它不 import 任何 screens、不持有 BuildContext。
class UnitOfWork {
  UnitOfWork(this.db);

  final Database db;

  /// Zone 里传递「当前事务的 executor」，供嵌套调用复用。
  static const Object _txnKey = #yuanUowTxn;
  static const Object _postKey = #yuanUowPost;
  static const Object _rollbackKey = #yuanUowRollback;

  /// 当前调用栈是否处于某个事务中（供功能接口自查，不强制使用）。
  DatabaseExecutor? get currentTxn => Zone.current[_txnKey] as DatabaseExecutor?;

  /// 在**一个**事务里编排任意多个功能接口。
  ///
  /// ```dart
  /// await uow.run((txn) async {
  ///   await debtService.markPaidIn(txn, ...);   // 债务处理接口
  ///   await ledger.debit(txn, ...);             // 账户出账接口
  /// }, afterCommit: () async { await catalog.refresh(); });
  /// ```
  /// `debit` 失败 → `markPaidIn` 已执行的 UPDATE 一并回滚，页面不刷新。
  Future<void> run(
    Future<void> Function(DatabaseExecutor txn) body, {
    Future<void> Function()? afterCommit,
    Future<void> Function()? onRollback,
  }) async {
    final DatabaseExecutor? outer = Zone.current[_txnKey] as DatabaseExecutor?;
    if (outer != null) {
      // ── 嵌套：复用外层 txn，绝不新开事务 ──────────────────────────
      final List<Future<void> Function()>? post =
          Zone.current[_postKey] as List<Future<void> Function()>?;
      final List<Future<void> Function()>? rollbacks =
          Zone.current[_rollbackKey] as List<Future<void> Function()>?;
      if (afterCommit != null) post?.add(afterCommit);
      if (onRollback != null) rollbacks?.add(onRollback);
      await body(outer); // 异常冒泡 → 外层事务整体回滚
      return;
    }

    final List<Future<void> Function()> post = <Future<void> Function()>[];
    final List<Future<void> Function()> rollbacks = <Future<void> Function()>[];
    if (afterCommit != null) post.add(afterCommit);
    if (onRollback != null) rollbacks.add(onRollback);

    try {
      await db.transaction((Transaction txn) async {
        await runZoned(
          () async {
            await body(txn);
          },
          zoneValues: <Object?, Object?>{
            _txnKey: txn,
            _postKey: post,
            _rollbackKey: rollbacks,
          },
        );
      });
      // 事务提交成功才执行；回滚路径根本走不到这里。
      for (final Future<void> Function() f in post) {
        await f();
      }
    } catch (_) {
      for (final Future<void> Function() f in rollbacks) {
        await f();
      }
      rethrow;
    }
  }

  /// 只读动作也统一从这里取 executor：不在事务里就用 [db]，
  /// 在事务里则用同一个 txn，避免「读到未提交数据 / 读到旧快照」。
  DatabaseExecutor executor(DatabaseExecutor? given) =>
      given ?? currentTxn ?? db;
}
