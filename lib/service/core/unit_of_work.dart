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
/// 【所属模块】service/core · 事务编排
/// 【实现功能】全库唯一业务事务入口：在一个事务里编排任意多个功能接口，嵌套调用自动并入外层事务，提交后统一执行 afterCommit、回滚时统一执行 onRollback，保证跨接口 SQL 共进退。
/// 【使用限制】功能接口与 DAO 不得自建 db.transaction；afterCommit / onRollback 不得再写库；database_shell 的建表事务属 Schema 装配，不走本接口；与页面无关，不 import screens、不持有 BuildContext。
/// 【入参与结果】构造入参为已打开的 Database，全局只建一份实例并由 components.dart 注入所有 Controller；实例方法收 DatabaseExecutor 或异步回调，返回 Future<void> / DatabaseExecutor。
/// 【异常与调用方处理】body 内任一异常原样上抛并整体回滚；onRollback 自身异常也会上抛。调用方必须自行 try/catch 提示用户、保持界面旧值，不要在 catch 里重试写库。
class UnitOfWork {
  /// 【所属模块】service/core · 事务编排
  /// 【实现功能】用已打开的 Database 创建事务编排器。
  /// 【使用限制】应在 Services.initServices 里建且只建一份，注入所有业务处理器；不要在页面或功能接口内部另行 new。
  /// 【入参与结果】入参 db 必须是 DatabaseService 已完成建表的实例；无返回值（构造）。结果为可复用的 UnitOfWork 单例。
  /// 【异常与调用方处理】db 未打开不会在此抛错，后续 run 才会抛；调用方需保证建表完成后再装配。
  UnitOfWork(this.db);

  final Database db;

  /// Zone 里传递「当前事务的 executor」，供嵌套调用复用。
  static const Object _txnKey = #yuanUowTxn;
  static const Object _postKey = #yuanUowPost;
  static const Object _rollbackKey = #yuanUowRollback;

  /// 当前调用栈是否处于某个事务中（供功能接口自查，不强制使用）。
  /// 【所属模块】service/core · 事务编排
  /// 【实现功能】返回当前调用栈所处事务的 executor，供功能接口自查是否已在事务中。
  /// 【使用限制】只读 getter，不能用来"开"事务；未处于事务时返回 null，调用方不得据此自行 db.transaction。
  /// 【入参与结果】无入参；返回 DatabaseExecutor? —— 非 null 表示外层已有事务，null 表示当前不在事务里。
  /// 【异常与调用方处理】不抛异常；返回 null 时调用方应改走 uow.run，而不是把它当 db 用。
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
  /// 【所属模块】service/core · 事务编排
  /// 【实现功能】在一个事务里执行 body；嵌套调用复用同一个 txn 不新开事务；事务提交成功后依次执行 afterCommit，回滚时依次执行 onRollback。
  /// 【使用限制】全库唯一业务事务入口；body 内所有写库必须用传入的 txn；afterCommit 只做刷新 / 通知 / 删旧图，onRollback 只做补偿；不得在 body 里调 refresh / notifyListeners。
  /// 【入参与结果】body 必填，收 DatabaseExecutor txn；afterCommit / onRollback 可选、须为 Future<void> Function()。返回 Future<void>，调用方必须 await；返回时事务已提交（或已回滚并完成补偿）。
  /// 【异常与调用方处理】body 内任一异常导致最外层事务整体回滚并原样上抛，已执行 SQL 全部撤销；onRollback 异常同样上抛。调用方需自行 try/catch 提示用户、保持内存快照旧值，不要吞掉异常后继续用半写状态。
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
  /// 【所属模块】service/core · 事务编排
  /// 【实现功能】为只读动作挑选 executor：显式传入优先，其次当前事务 txn，最后回落到 db。
  /// 【使用限制】只用于"不在事务里也想读库"的功能接口；不能替代 uow.run 的写事务。
  /// 【入参与结果】given 可空；返回 DatabaseExecutor（永不为空）。结果须直接用于查询，不得据此另开事务。
  /// 【异常与调用方处理】不抛异常；若返回的 db 尚未建表，后续查询会抛，调用方需保证装配顺序。
  DatabaseExecutor executor(DatabaseExecutor? given) =>
      given ?? currentTxn ?? db;
}
