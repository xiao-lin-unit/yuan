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
class AzRepaymentService {
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
