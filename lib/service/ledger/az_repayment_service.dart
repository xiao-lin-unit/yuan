import 'package:sqflite/sqflite.dart';

import '../../database/account/account_record.dart';
import '../core/account_ledger.dart';
import '../core/unit_of_work.dart';
import 'az_controller.dart';

/// 跨模块编排：债务还款 + 账户出账，同一个 UnitOfWork.run 事务。
///
/// 账户侧出账失败 → 债务侧已写的还款状态一并回滚，满足硬-19 / 契-18。
/// 【所属模块】service/ledger · 跨模块编排
/// 【实现功能】把「还款附表标记已还 + 付款储蓄卡出账」组合成一个原子动作，供还款按钮调用。
/// 【使用限制】全库唯一还款编排入口；必须经 uow.run；页面不得分别调债务与账户两个接口；不得在 body 内刷新快照。
/// 【入参与结果】构造收 uow / azWrite / ledger / accountCatalog / azLedger（装配点各一份）；repayInstallment 收还款记录 id / 付款账户 id / 金额 / 还后剩余本金 / 还款附表名，返回 Future<void>。
/// 【异常与调用方处理】任一接口抛异常整体回滚并原样上抛；调用方必须自行 try/catch 提示用户「还款未生效」，保持旧快照与旧余额，不得吞异常后当成功。
class AzRepaymentService {
  const AzRepaymentService({
    required this.uow,
    required this.azWrite,
    required this.ledger,
    this.accountCatalog,
    this.azLedger,
  });

  final UnitOfWork uow;
  final AzWriteController azWrite;
  final AccountLedger ledger;
  // 装配点传入的共享账本，仅保留引用，事务 body 内不读取（避免读未提交数据）。
  final Object? accountCatalog;
  final Object? azLedger;

  /// 【所属模块】service/ledger · 跨模块编排
  /// 【实现功能】在一个事务里先由债务接口标记还款记录已还，再由 AccountLedger 从付款储蓄卡出账；提交后刷新快照。
  /// 【使用限制】amount / remainingAfter 传十进制字符串（账户侧由 ledger 自行解析 double 入参时调用方负责转）；repayTable 必须是草案的两张还款附表之一；不得拆成两次 uow.run。
  /// 【入参与结果】收 repayTable / repayId / fromAccountId / amount / remainingAfter / note；返回 Future<void>，调用方必须 await；返回时事务已提交。
  /// 【异常与调用方处理】金额非法、账户不存在、CHECK 失败、SQL 异常均导致整体回滚并上抛；调用方需自行 try/catch 提示用户，并保持页面旧数据不变。
  Future<void> repayInstallment({
    required String repayTable,
    required int repayId,
    required int fromAccountId,
    required double amount,
    required String remainingAfter,
    String note = '',
  }) async {
    if (amount <= 0) throw ArgumentError('还款金额必须大于 0');
    await uow.run(
      (DatabaseExecutor txn) async {
        await azWrite.markRepayPaidIn(
          txn,
          repayTable,
          repayId,
          repaidAmount: amount.toStringAsFixed(2),
          remainingAfter: remainingAfter,
        );
        await ledger.debit(
          txn,
          accountId: fromAccountId,
          amount: amount,
          entryType: AccountEntryType.creditRepay,
          note: note,
          refType: 'liability_repay',
          refId: repayId,
        );
      },
      afterCommit: () => azWrite.catalog.load(),
    );
  }
}
