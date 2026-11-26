import 'package:sqflite/sqflite.dart';

import '../../database/account/account_record.dart';
import '../account_controller.dart';
import '../core/account_ledger.dart';
import '../core/unit_of_work.dart';
import 'az_controller.dart';

/// 「还一期贷款」的跨接口事务编排（项目检查第 3 条的直接落点）。
///
/// 债务处理接口 [AzWriteController.markPlanPaidIn] 与账户出账接口
/// [AccountLedger.debit] 放在**同一个** [UnitOfWork.run] 里：
/// 出账任一步失败 → 债务侧已执行的 UPDATE 一并回滚；
/// 两侧快照刷新都挂在 `afterCommit`，回滚时页面保持旧值。
/// 【所属模块】service/ledger · 跨模块编排
/// 【实现功能】「还一期贷款」的跨接口事务编排示例：债务处理接口 markPlanPaidIn 与账户出账接口 ledger.debit 放进同一个 UnitOfWork.run，后者失败回滚前者。
/// 【使用限制】必须注入与其它模块同一个 UnitOfWork 实例；两侧刷新只挂 afterCommit；不得在事务内 refresh / notifyListeners；负债页还款按钮尚未接入，属新编排入口。
/// 【入参与结果】构造收 uow / azWrite / ledger / accountCatalog / azLedger；方法收 planId / fromAccountId / amount / reason / occurredAt / refId。返回 Future<void>。
/// 【异常与调用方处理】参数校验失败抛 ArgumentError；债务侧或出账侧任一异常导致整体回滚并原样上抛；afterCommit 刷新异常也会上抛。调用方需自行 try/catch 提示用户、保持两个账本的旧快照。
class AzRepaymentService {
  /// 【所属模块】service/ledger · 跨模块编排
  /// 【实现功能】用共享的事务入口、债务接口、资金门面与两个共享账本创建编排器。
  /// 【使用限制】uow 必须是全局那一份，否则跨模块事务不成立；由 components.dart 建且只建一份并注册 Provider。
  /// 【入参与结果】uow / azWrite / ledger / accountCatalog / azLedger 均必填；无返回值（const 构造）。
  /// 【异常与调用方处理】构造不抛异常；依赖未就绪会在调用方法时暴露，调用方需保证装配顺序。
  const AzRepaymentService({
    required this.uow,
    required this.azWrite,
    required this.ledger,
    required this.accountCatalog,
    required this.azLedger,
  });

  final UnitOfWork uow;
  final AzWriteController azWrite;
  final AccountLedger ledger;
  final AccountController accountCatalog;
  final AzController azLedger;

  /// 【所属模块】service/ledger · 跨模块编排
  /// 【实现功能】在同一事务里先调 azWrite.markPlanPaidIn(txn,…) 处理债务，再调 ledger.debit(txn,…) 出账；提交后刷新资债与账户两个快照。
  /// 【使用限制】amount 必须 > 0、reason 不得为空；出账失败必须让债务侧已执行的 UPDATE 一并回滚；不得把两步拆成两个独立 uow.run。
  /// 【入参与结果】planId / fromAccountId / amount / reason 必填；occurredAt / refId 可选。返回 Future<void>，调用方必须 await；返回时事务已提交或已回滚。
  /// 【异常与调用方处理】amount<=0 / reason 空抛 ArgumentError；markPlanPaidIn 或 ledger.debit 的 StateError / DAO 异常导致整体回滚并原样上抛；刷新异常上抛。调用方需自行 try/catch 提示用户，不要吞掉异常后继续展示"已还"。
  Future<void> repayLoanInstallment({
    required int planId,
    required int fromAccountId,
    required double amount,
    required String reason,
    DateTime? occurredAt,
    int? refId,
  }) async {
    if (amount <= 0) throw ArgumentError('还了多少要填正数');
    if (reason.trim().isEmpty) throw ArgumentError('请填写还款说明');

    await uow.run(
      (DatabaseExecutor txn) async {
        // ① 债务处理接口：收 txn、不自建事务。
        await azWrite.markPlanPaidIn(
          txn,
          planId: planId,
          actualAmount: amount,
          reason: reason,
        );
        // ② 账户出账接口：同一个 txn、唯一出账接口。
        await ledger.debit(
          txn,
          accountId: fromAccountId,
          amount: amount,
          entryType: AccountEntryType.creditRepay,
          occurredAt: occurredAt,
          note: reason,
          refType: 'liability_repay',
          refId: refId,
        );
      },
      afterCommit: () async {
        await azLedger.refresh();
        await accountCatalog.refresh(touched: <int>{fromAccountId});
      },
    );
  }
}
