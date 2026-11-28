import 'package:sqflite/sqflite.dart';

import '../../database/account/account_record.dart';
import '../core/account_ledger.dart';
import '../core/unit_of_work.dart';
import 'az_controller.dart';
import 'az_liability_service.dart';

/// IF-10：跨模块编排「债务还款 + 账户出账」，两者同处一个 UnitOfWork.run。
///
/// 账户出账失败 → 债务侧已写的还款状态 / 次表进度 / 下一条待还一并回滚，
/// 满足硬-19 / 契-18；提交成功后才刷新资债与账户两侧快照。
/// 【所属模块】service/ledger · 跨模块编排
/// 【实现功能】全库唯一还款编排入口：组合 AzWriteController.markPlanPaidIn（IF-Z16）与 AccountLedger.debit/credit（IF-05/06）；挂卡分期同事务写 2 条等值 credit_repay 流水。
/// 【使用限制】必须经 uow.run；页面不得分别调债务与账户两个接口；不得在 body 内刷新快照；不得用本类返回值写 accounts.balance；软件不判断用户是否一次性还清。
/// 【入参与结果】构造收 uow / azWrite / ledger / 可选 refreshAccounts；repayLoanInstallment 收 liabilityId / planId / 实还金额 / 还款时间 / 还款账户 / 是否分期，返回 AzRepayOutcome，必须 await。
/// 【异常与调用方处理】金额 <= 0、账户非法、无 pending、DAO/CHECK 异常均导致整体回滚并原样上抛；调用方自行 try/catch 提示「还款未生效」，保持旧快照与旧余额，不得吞异常后当成功。
class AzRepaymentService {
  const AzRepaymentService({
    required this.uow,
    required this.azWrite,
    required this.ledger,
    this.refreshAccounts,
  });

  final UnitOfWork uow;
  final AzWriteController azWrite;
  final AccountLedger ledger;

  /// 账户侧快照刷新（装配点传入）；只在事务提交后执行。
  final Future<void> Function()? refreshAccounts;

  /// IF-10 正名入口：还一期贷款 / 分期。
  /// 【所属模块】service/ledger · 跨模块编排
  /// 【实现功能】同事务先写债务侧完整还款（含下一条 pending 与总亏损），再由付款储蓄卡写一条 credit_repay 出账；挂卡分期额外给挂载信用卡写一条等值入账。
  /// 【使用限制】repayAccountId 为空时由负债服务回落主表 link_account_id；2 条等值流水只对挂卡分期生效；两侧刷新只挂 afterCommit。
  /// 【入参与结果】收 liabilityId / planId / amount / repaidAt / repayAccountId / isInstallment / fee；返回 AzRepayOutcome，调用方必须 await。
  /// 【异常与调用方处理】任一步抛异常整体回滚、afterCommit 不执行；调用方需自行 try/catch 提示用户并保持旧数据。
  Future<AzRepayOutcome> repayLoanInstallment({
    required int liabilityId,
    required int planId,
    required double amount,
    required DateTime repaidAt,
    int? repayAccountId,
    bool isInstallment = false,
    double? fee,
    String note = '',
  }) async {
    if (amount <= 0) throw ArgumentError('还款金额必须大于 0');
    late AzRepayOutcome outcome;
    await uow.run(
      (DatabaseExecutor txn) async {
        // ① 债务侧 IF-Z16：当期改已还、写还后剩余本金、次表进度、总亏损、下一条 pending。
        outcome = await azWrite.markPlanPaidIn(
          txn,
          liabilityId: liabilityId,
          planId: planId,
          repaidAmount: amount,
          repaidAt: repaidAt,
          repayAccountId: repayAccountId,
          fee: fee,
          isInstallment: isInstallment,
        );
        // ② 账户侧 IF-05：付款存储账户留一条出账，金额是实还总额（含本息费）。
        await ledger.debit(
          txn,
          accountId: outcome.repayAccountId,
          amount: amount,
          entryType: AccountEntryType.creditRepay,
          occurredAt: repaidAt,
          note: note,
          refType: 'liability_repay',
          refId: outcome.repayId,
        );
        // ③ 契-1：挂卡分期同事务再写一条等值入账腿，卡上欠款随之下降；
        //    卡欠款与分期剩余本金是同一笔钱，两边各减一次、永不相加。
        final int? creditCardId = outcome.mountCreditcardId;
        if (creditCardId != null) {
          await ledger.credit(
            txn,
            accountId: creditCardId,
            amount: amount,
            entryType: AccountEntryType.creditRepay,
            occurredAt: repaidAt,
            note: note,
            refType: 'liability_repay',
            refId: outcome.repayId,
          );
        }
      },
      afterCommit: () async {
        await azWrite.catalog.load();
        if (refreshAccounts != null) await refreshAccounts!();
      },
    );
    return outcome;
  }

  /// IF-Z17 / IF-Z18 的编排入口：用户主动提前还款 / 分期提前结清。
  /// 【所属模块】service/ledger · 跨模块编排
  /// 【实现功能】按是否分期分派 prepayLoanIn / settleInstallmentIn，同事务写付款卡出账（挂卡分期再写等值入账），提交后刷新两侧。
  /// 【使用限制】软件不判断「该不该收违约金」与「是不是一次性还清」，由调用方给动作输入；规则校验在负债服务内完成；必须经 uow.run。
  /// 【入参与结果】收 prepay 参数对象；返回 AzRepayOutcome，调用方必须 await。
  /// 【异常与调用方处理】规则非法 / 金额不一致 / DAO 异常整体回滚并上抛；调用方自行 try/catch 提示用户。
  Future<AzRepayOutcome> prepay(AzPrepayRequest request) async {
    if (request.amount <= 0) throw ArgumentError('还款金额必须大于 0');
    late AzRepayOutcome outcome;
    await uow.run(
      (DatabaseExecutor txn) async {
        if (request.isInstallment) {
          outcome = await azWrite.liability.settleInstallmentIn(
            txn,
            liabilityId: request.liabilityId,
            repaidAmount: request.amount,
            repaidAt: request.repaidAt,
            repayAccountId: request.repayAccountId,
            settleAll: request.settleAll,
            settleRule: request.settleRule,
            ruleRatio: request.ruleRatio,
            serviceFee: request.serviceFee,
            partialMode: request.partialMode,
          );
        } else {
          outcome = await azWrite.liability.prepayLoanIn(
            txn,
            liabilityId: request.liabilityId,
            repaidAmount: request.amount,
            repaidAt: request.repaidAt,
            repayAccountId: request.repayAccountId,
            payCurrentTerm: request.payCurrentTerm,
            hasPenalty: request.hasPenalty,
            penaltyOverride: request.penaltyOverride,
          );
        }
        await ledger.debit(
          txn,
          accountId: outcome.repayAccountId,
          amount: request.amount,
          entryType: AccountEntryType.creditRepay,
          occurredAt: request.repaidAt,
          refType: 'liability_repay',
          refId: outcome.repayId,
        );
        final int? creditCardId = outcome.mountCreditcardId;
        if (creditCardId != null) {
          await ledger.credit(
            txn,
            accountId: creditCardId,
            amount: request.amount,
            entryType: AccountEntryType.creditRepay,
            occurredAt: request.repaidAt,
            refType: 'liability_repay',
            refId: outcome.repayId,
          );
        }
      },
      afterCommit: () async {
        await azWrite.catalog.load();
        if (refreshAccounts != null) await refreshAccounts!();
      },
    );
    return outcome;
  }
}

/// 提前还款动作输入（只装用户填的动作，不装软件算出的金额）。
/// 【所属模块】service/ledger · 动作契约
/// 【实现功能】承载主动提前还款 / 分期结清的全部用户输入，供 AzRepaymentService.prepay 分派。
/// 【使用限制】不可变；金额单位元；settleRule 为 null 时表示部分提前还；软件不判断规则是否适用。
/// 【入参与结果】构造收 liabilityId / amount / repaidAt / 各动作开关；消费方只读字段。
/// 【异常与调用方处理】不抛异常；非法值由负债服务在事务内校验并上抛。
class AzPrepayRequest {
  const AzPrepayRequest({
    required this.liabilityId,
    required this.amount,
    required this.repaidAt,
    this.repayAccountId,
    this.isInstallment = false,
    this.settleAll = false,
    this.settleRule,
    this.ruleRatio,
    this.serviceFee,
    this.partialMode = 'B',
    this.payCurrentTerm = true,
    this.hasPenalty = false,
    this.penaltyOverride,
  });

  final int liabilityId;
  final double amount;
  final DateTime repaidAt;
  final int? repayAccountId;
  final bool isInstallment;
  final bool settleAll;
  final String? settleRule;
  final double? ruleRatio;
  final double? serviceFee;
  final String partialMode;
  final bool payCurrentTerm;
  final bool hasPenalty;
  final double? penaltyOverride;
}
