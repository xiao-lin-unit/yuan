import 'package:sqflite/sqflite.dart';

import '../../database/ledger/az_dao.dart';

/// 本文件私有：取查询结果首行，避免引入 package:collection 依赖。
/// 【所属模块】service/ledger · 内部工具
/// 【实现功能】为空列表返回 null、非空返回首元素。
/// 【使用限制】只在本文件内使用，不与全库其它扩展同名冲突。
/// 【入参与结果】无入参；返回 T?。
/// 【异常与调用方处理】不抛异常；调用方判空后再读字段。
extension _AzFirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final Iterator<T> it = iterator;
    return it.moveNext() ? it.current : null;
  }
}

/// 一次还款动作在债务侧算出来的结果，供跨模块编排服务写账户流水。
/// 【所属模块】service/ledger · 还款结果契约
/// 【实现功能】承载实还金额、还款账户、挂载信用卡、是否结清与下一条待还 id；账户侧只按本结果写流水，不再读债务表。
/// 【使用限制】不可变；金额单位为元；mountCreditcardId 为 null 表示不挂卡、不写第二条入账腿；nextPendingId 为 null 表示已结清。
/// 【入参与结果】构造收 repayId / amount / repayAccountId / mountCreditcardId / settled / nextPendingId；消费方只读字段。
/// 【异常与调用方处理】不抛异常；调用方须先判 settled / repayAccountId 是否为有效账户再写出账流水。
class AzRepayOutcome {
  const AzRepayOutcome({
    required this.repayId,
    required this.amount,
    required this.repayAccountId,
    required this.mountCreditcardId,
    required this.settled,
    required this.nextPendingId,
  });

  final int repayId;
  final double amount;
  final int repayAccountId;
  final int? mountCreditcardId;
  final bool settled;
  final int? nextPendingId;
}

/// 负债模块功能接口收口（对应《资产表结构草案.md》8.4 IF-Z13~IF-Z23）。
///
/// 所有公开方法第一参数一律收 [DatabaseExecutor]，**不自建事务、不刷新快照**，
/// 由 [AzRepaymentService] / [AzWriteController] 放进 UnitOfWork.run 编排；
/// 账户出账只由 AccountLedger 写，本类不碰 accounts 与 account_entries。
/// 【所属模块】service/ledger · 负债功能
/// 【实现功能】新建首条待还、逐期生成下一条、执行一期还款、提前还款、分期结清、随借随还支取、逾期扫描、总亏损累加、抵押状态同步、还款账户回落。
/// 【使用限制】必须在 UnitOfWork.run 事务内调用；金额列一律 TEXT 十进制字符串写回、内部用 double 计算并向下取整到分；禁止定时生成、禁止一次排满全部期数、禁止预填 remaining_after；软件不判断「该不该收违约金」与「是不是一次性还清」。
/// 【入参与结果】构造收 AzDao；各方法收 txn 与业务参数，返回记录 id / 状态字符串 / AzRepayOutcome，必须 await；结果只用于对账与展示，不得写回 accounts.balance。
/// 【异常与调用方处理】ArgumentError（金额非法、枚举非法、抵押缺资产、规则输入缺失、金额不是整期额）、StateError（无 pending、已结清、非 revolving、账户无效）、DAO/CHECK 异常原样上抛由外层事务整体回滚；调用方自行 try/catch 提示用户并保持旧快照。
class AzLiabilityService {
  const AzLiabilityService(this.dao);

  final AzDao dao;

  static const String _loanSub = 'az_liability_loan';
  static const String _loanRepay = 'az_liability_loan_repay';
  static const String _loanDraw = 'az_liability_loan_draw';
  static const String _instSub = 'az_liability_installment';
  static const String _instRepay = 'az_liability_installment_repay';
  static const String _main = 'az_liabilities';

  static const List<String> _loanMethods = <String>[
    'equal_principal',
    'equal_installment',
    'interest_first',
    'lump_sum',
    'revolving',
  ];

  /// 与 AzSchema.tableColumns 中 settle_rule 的 options 完全一致（英文 code）。
  static const List<String> _settleRules = <String>[
    'waive_unbilled',
    'charge_all_remaining',
    'charge_one_more',
    'ratio_of_remaining',
    'extra_service_fee',
  ];

  /// 【所属模块】service/ledger · 负债功能
  /// 【实现功能】校验贷款新增录入：还款方式封闭枚举、抵押必选、按期类必填期数与起始日、一次性类必填到期日；并算出禁用填写的实收金额与 end_date。
  /// 【使用限制】写库前调用；不写库；service_fee 缺省按 0；loan_amount 必须 > 0；end_date 由起始日 + 总期 × 单位推出并存入。
  /// 【入参与结果】收主表字段与贷款次表字段；返回补好计算列的两份新 Map（不修改入参）。
  /// 【异常与调用方处理】非法枚举 / 金额 / 缺必填抛 ArgumentError；调用方须在事务内使用返回值，不得吞异常后继续写库。
  Map<String, Object?> normalizeLoan(
    Map<String, Object?> mainValues,
    Map<String, Object?> subValues,
  ) {
    final String method = (subValues['repay_method'] ?? '').toString();
    if (!_loanMethods.contains(method)) {
      throw ArgumentError('还款方式只能是五种枚举之一：$method');
    }
    final double loan = _num(subValues['loan_amount']);
    if (loan <= 0) throw ArgumentError('贷款金额必须大于 0');
    final double fee = _num(subValues['service_fee']);
    if (fee < 0) throw ArgumentError('服务费不能为负');
    if (fee > loan) throw ArgumentError('服务费不能超过贷款金额');

    final int hasCollateral = _int(subValues['has_collateral']);
    if (hasCollateral == 1 && _int(subValues['link_asset_id']) <= 0) {
      throw ArgumentError('选择有抵押时必须指定抵押资产');
    }

    final bool installmentLike = method != 'lump_sum' && method != 'revolving';
    final int start = _int(mainValues['start_date']);
    if (start <= 0) throw ArgumentError('开始时间必填');
    final int terms = _int(subValues['total_terms']);
    if (installmentLike && terms <= 0) throw ArgumentError('按期还款必须填总期数');

    final String unit = (subValues['term_unit'] ?? 'month').toString();
    if (!const <String>['day', 'week', 'month', 'quarter', 'year']
        .contains(unit)) {
      throw ArgumentError('期数单位只能是 day/week/month/quarter/year');
    }

    final Map<String, Object?> main = <String, Object?>{...mainValues};
    final Map<String, Object?> sub = <String, Object?>{
      ...subValues,
      'service_fee': _s(fee),
      // 实际到账禁用填写，一律由减法算出。
      'actual_received_amount': _s(loan - fee),
      // DDL 无默认值且 NOT NULL：初始剩余本金由软件按合同本金推出，表单不填。
      'remaining_principal': _s(loan),
      'paid_terms': 0,
      'overdue_penalty_rate': _rate(subValues['overdue_penalty_rate']),
      'prepay_penalty_rate': _rate(subValues['prepay_penalty_rate']),
      'annual_rate': _rate(subValues['annual_rate']),
    };
    if (!installmentLike) {
      final int end = _int(mainValues['end_date']);
      if (end <= 0) throw ArgumentError('一次性还清 / 随借随还必须填结束时间');
      sub['total_terms'] = null;
      sub['term_unit'] = null;
      sub['repay_day'] = null;
    } else {
      final DateTime startAt =
          DateTime.fromMillisecondsSinceEpoch(start);
      main['end_date'] = _lastDue(startAt, unit, terms,
              _int(subValues['repay_day']))
          .millisecondsSinceEpoch;
    }
    return <String, Object?>{'main': main, 'sub': sub};
  }

  /// 【所属模块】service/ledger · 负债功能
  /// 【实现功能】校验分期新增录入：总额 > 0、期数 1..60、恒按月、费率与利率非负；算出 end_date 与首期还款日。
  /// 【使用限制】挂卡校验由账户侧在写负债前完成，本方法不读 accounts；不写库。
  /// 【入参与结果】收主表字段与分期次表字段；返回补好计算列的两份新 Map。
  /// 【异常与调用方处理】金额 / 期数 / 率非法抛 ArgumentError；调用方须在事务内使用返回值。
  Map<String, Object?> normalizeInstallment(
    Map<String, Object?> mainValues,
    Map<String, Object?> subValues,
  ) {
    final double amount = _num(subValues['installment_amount']);
    if (amount <= 0) throw ArgumentError('分期总额必须大于 0');
    final int terms = _int(subValues['total_terms']);
    if (terms <= 0 || terms > 60) {
      throw ArgumentError('分期总期数必须在 1~60 之间');
    }
    final int start = _int(mainValues['start_date']);
    if (start <= 0) throw ArgumentError('开始时间必填');
    final double annual = _rate(subValues['annual_rate']);
    final double feeRate = _rate(subValues['per_term_fee_rate']);
    final DateTime startAt = DateTime.fromMillisecondsSinceEpoch(start);
    final int day = _int(subValues['repay_day']);

    return <String, Object?>{
      'main': <String, Object?>{
        ...mainValues,
        'end_date': _lastDue(startAt, 'month', terms, day)
            .millisecondsSinceEpoch,
      },
      'sub': <String, Object?>{
        ...subValues,
        'paid_terms': 0,
        'remaining_principal': _s(amount),
        'annual_rate': annual,
        'per_term_fee_rate': feeRate,
        'overdue_penalty_rate': _rate(subValues['overdue_penalty_rate']),
      },
    };
  }

  /// IF-Z13 / IF-Z14：新建时只生成**第一条** pending，remaining_after 留空。
  /// 【所属模块】service/ledger · 还款计划
  /// 【实现功能】按次表参数算第 1 期本金 / 利息 / 手续费与应还日，写入一张还款附表；一次性类不排期。
  /// 【使用限制】只在「新建」时机调用；禁止一次生成全部期数；必须在事务内；subId 为次表主键。
  /// 【入参与结果】收 txn / liabilityId / subId / 是否分期 / 次表字段 Map；返回新 pending 记录 id，一次性类返回 -1。
  /// 【异常与调用方处理】参数缺失抛 ArgumentError；DAO/CHECK 异常上抛并回滚；调用方不得用返回值写账户余额。
  Future<int> createFirstPendingIn(
    DatabaseExecutor txn, {
    required int liabilityId,
    required int subId,
    required bool isInstallment,
    required Map<String, Object?> sub,
    required Map<String, Object?> main,
  }) async {
    if (!isInstallment) {
      final String method = (sub['repay_method'] ?? '').toString();
      if (method == 'lump_sum' || method == 'revolving') return -1;
    }
    final String table = isInstallment ? _instRepay : _loanRepay;
    final int start = _int(main['start_date']);
    final DateTime startAt = DateTime.fromMillisecondsSinceEpoch(start);
    final String unit = isInstallment ? 'month' : (sub['term_unit'] ?? 'month').toString();
    final int day = _int(sub['repay_day']);
    final DateTime due = _firstDue(startAt, unit, day);
    final _Period p = _firstPeriod(sub, isInstallment: isInstallment);
    return dao.insert(txn, table, <String, Object?>{
      'liability_id': liabilityId,
      'sub_liability_id': subId,
      'record_source': 'auto',
      'term_no': 1,
      'due_at': due.millisecondsSinceEpoch,
      'principal_part': _s(p.principal),
      'interest_part': _s(p.interest),
      'fee': _s(p.fee),
      'penalty_amount': '0',
      'state': due.isBefore(DateTime.now()) ? 'overdue' : 'pending',
      'remaining_after': null,
      'manual_adjusted': 0,
      'note': '',
      ..._stamp(),
    });
  }

  /// IF-Z15：还完当期后生成**下一条** pending。
  /// 【所属模块】service/ledger · 还款计划
  /// 【实现功能】按上一条到期日顺推一个完整周期，用还后剩余本金重算本息，尾差全放末期；新记录若已过应还日直接标逾期。
  /// 【使用限制】只在「执行还款动作」时机调用；未来永远只有一条 pending；不预填 remaining_after；必须在事务内。
  /// 【入参与结果】收 txn / liabilityId / subId / 上一条记录 / 次表字段 / 还后剩余本金 / 已还期数；返回新 pending id，已结清返回 null。
  /// 【异常与调用方处理】剩余本金 < 0 抛 ArgumentError；已结清或已有 pending 抛 StateError；DAO 异常上抛并回滚。
  Future<int?> generateNextPendingIn(
    DatabaseExecutor txn, {
    required int liabilityId,
    required int subId,
    required Map<String, Object?> previous,
    required Map<String, Object?> sub,
    required double remaining,
    required int paidTerms,
    required bool isInstallment,
    required bool settled,
  }) async {
    if (settled || remaining <= 0) return null;
    final String table = isInstallment ? _instRepay : _loanRepay;
    final int existing = _int((await txn.query(
      table,
      columns: <String>['id'],
      where: 'liability_id = ? AND state IN (?, ?)',
      whereArgs: <Object?>[liabilityId, 'pending', 'overdue'],
      limit: 1,
    )).firstOrNull?['id']);
    if (existing > 0) {
      throw StateError('已有一条待还记录，不能重复生成下一条');
    }
    final int termNo = _int(previous['term_no']) + 1;
    final int totalTerms = _int(sub['total_terms']);
    if (!isInstallment && totalTerms > 0 && termNo > totalTerms) return null;
    if (isInstallment && termNo > totalTerms) return null;

    final String unit = isInstallment ? 'month' : (sub['term_unit'] ?? 'month').toString();
    final int day = _int(sub['repay_day']);
    final DateTime prevDue = DateTime.fromMillisecondsSinceEpoch(
        _int(previous['due_at']));
    final DateTime due = _nextDue(prevDue, unit, day);
    final _Period p = _periodAt(
      sub,
      isInstallment: isInstallment,
      remaining: remaining,
      termNo: termNo,
      totalTerms: totalTerms,
    );
    return dao.insert(txn, table, <String, Object?>{
      'liability_id': liabilityId,
      'sub_liability_id': subId,
      'record_source': 'auto',
      'term_no': termNo,
      'due_at': due.millisecondsSinceEpoch,
      'principal_part': _s(p.principal),
      'interest_part': _s(p.interest),
      'fee': _s(p.fee),
      'penalty_amount': '0',
      'state': due.isBefore(DateTime.now()) ? 'overdue' : 'pending',
      'remaining_after': null,
      'manual_adjusted': 0,
      'note': '',
      ..._stamp(),
    });
  }

  /// IF-Z16：执行一期还款（债务侧完整一步）。
  /// 【所属模块】service/ledger · 还款动作
  /// 【实现功能】写回当期实还 / remaining_after，同步次表 paid_terms 与 remaining_principal、主表 status 与 total_loss，累加总亏损，生成下一条 pending，并在结清时同步抵押状态。
  /// 【使用限制】必须由 AzRepaymentService 经 uow.run 调用；本方法不写账户流水、不刷新快照；remaining_after 只在此时填、末期强制置 0；同一期只留一条 paid。
  /// 【入参与结果】收 txn / liabilityId / planId / 实还金额 / 还款时间 / 还款账户 id / 可选 fee；返回 AzRepayOutcome，调用方必须 await。
  /// 【异常与调用方处理】金额 <= 0、无 pending、账户无效抛 ArgumentError / StateError；DAO/CHECK 异常上抛，账户出账失败时本方法已写 SQL 由外层一并回滚。
  Future<AzRepayOutcome> markPlanPaidIn(
    DatabaseExecutor txn, {
    required int liabilityId,
    required int planId,
    required double repaidAmount,
    required DateTime repaidAt,
    int? repayAccountId,
    double? fee,
    bool isInstallment = false,
  }) async {
    if (repaidAmount <= 0) throw ArgumentError('还款金额必须大于 0');
    final String repayTable = isInstallment ? _instRepay : _loanRepay;
    final String subTable = isInstallment ? _instSub : _loanSub;
    final Map<String, Object?>? plan = (await txn.query(
      repayTable,
      where: 'id = ? AND liability_id = ?',
      whereArgs: <Object?>[planId, liabilityId],
      limit: 1,
    )).firstOrNull;
    if (plan == null) throw StateError('找不到这条待还记录');
    final String state = (plan['state'] ?? '').toString();
    if (state == 'paid' || state == 'cancelled') {
      throw StateError('这一期已经还过或已取消');
    }
    final Map<String, Object?>? subRow = (await txn.query(
      subTable,
      where: 'liability_id = ?',
      whereArgs: <Object?>[liabilityId],
      limit: 1,
    )).firstOrNull;
    if (subRow == null) throw StateError('找不到这笔债的次表记录');
    final Map<String, Object?>? mainRow = (await txn.query(
      _main,
      where: 'id = ?',
      whereArgs: <Object?>[liabilityId],
      limit: 1,
    )).firstOrNull;
    if (mainRow == null) throw StateError('找不到这笔债的主表记录');

    final int accountId =
        await resolveRepayAccountIn(txn, liabilityId: liabilityId,
            preferred: repayAccountId);
    final double before = _num(subRow['remaining_principal']);
    final double principal = _num(plan['principal_part']);
    final double interest = _num(plan['interest_part']);
    final double planFee = fee ?? _num(plan['fee']);
    final double penalty = _num(plan['penalty_amount']);
    final double dueTotal = principal + interest + planFee + penalty;
    // 多还的部分全部冲本金；penalty 已含在 dueTotal 里，不重复减。
    final double extra =
        repaidAmount > dueTotal ? repaidAmount - dueTotal : 0;
    double after = before - principal - extra;
    if (after < 0) after = 0;
    final bool settled = after <= 0;
    final int now = repaidAt.millisecondsSinceEpoch;

    await dao.update(txn, repayTable, planId, <String, Object?>{
      'state': 'paid',
      'repaid_at': now,
      'repaid_amount': _s(repaidAmount),
      'repay_account_id': accountId,
      'remaining_after': _s(after),
      'fee': _s(planFee),
      'updated_at': now,
    });

    final int paidTerms = _int(subRow['paid_terms']) + 1;
    await dao.update(txn, subTable, _int(subRow['id']), <String, Object?>{
      'paid_terms': paidTerms,
      'remaining_principal': _s(after),
      'updated_at': now,
    });

    // total_loss 是 TEXT 列；分期 / 贷款由调用方显式传，不再猜 liability_type
    // 的取值（库里写的是中文 code「分期」，永远不等于 'installment'）。
    final String totalLoss = await recomputeTotalLossIn(
      txn,
      liabilityId: liabilityId,
      isInstallment: isInstallment,
    );
    await dao.update(txn, _main, liabilityId, <String, Object?>{
      'total_loss': totalLoss,
      'status': settled ? 'settled' : 'normal',
      'updated_at': now,
    });

    final int? nextId = await generateNextPendingIn(
      txn,
      liabilityId: liabilityId,
      subId: _int(subRow['id']),
      previous: <String, Object?>{
        'term_no': plan['term_no'],
        'due_at': plan['due_at'],
      },
      sub: subRow,
      remaining: after,
      paidTerms: paidTerms,
      isInstallment: isInstallment,
      settled: settled,
    );
    if (nextId != null && _isOverdue(await _rowById(txn, repayTable, nextId))) {
      await dao.update(txn, _main, liabilityId,
          <String, Object?>{'status': 'overdue', 'updated_at': now});
    }
    if (settled) {
      final int assetId = isInstallment ? 0 : _int(subRow['link_asset_id']);
      if (assetId > 0) {
        await syncMortgageStateIn(txn, assetId: assetId);
      }
    }
    return AzRepayOutcome(
      repayId: planId,
      amount: repaidAmount,
      repayAccountId: accountId,
      mountCreditcardId: isInstallment
          ? _nullableInt(subRow['mount_creditcard_id'])
          : null,
      settled: settled,
      nextPendingId: nextId,
    );
  }

  /// IF-Z17：贷款主动提前还款（record_source='user'）。
  /// 【所属模块】service/ledger · 提前还款
  /// 【实现功能】按「是否还本期」两分支拆分实还金额，算违约金，重算剩余本金与当期待还；同一期只留一条 paid。
  /// 【使用限制】软件不判断该不该收违约金；「有违约金」按提前还本金额 × 率带出默认值；选「还本期」时原 auto 计划改「已取消」；不展示省多少利息一类推演结论。
  /// 【入参与结果】收 txn / liabilityId / 实还金额 / 还款时间 / 还款账户 / 是否还本期 / 是否有违约金 / 用户填的违约金；返回 user 记录 id 与实还金额封装的 AzRepayOutcome。
  /// 【异常与调用方处理】金额 <= 0、当期无 auto 计划可取消抛 ArgumentError / StateError；DAO 异常上抛并回滚。
  Future<AzRepayOutcome> prepayLoanIn(
    DatabaseExecutor txn, {
    required int liabilityId,
    required double repaidAmount,
    required DateTime repaidAt,
    int? repayAccountId,
    required bool payCurrentTerm,
    required bool hasPenalty,
    double? penaltyOverride,
  }) async {
    if (repaidAmount <= 0) throw ArgumentError('还款金额必须大于 0');
    final Map<String, Object?>? sub = (await txn.query(
      _loanSub, where: 'liability_id = ?', whereArgs: <Object?>[liabilityId],
      limit: 1)).firstOrNull;
    if (sub == null) throw StateError('找不到这笔贷款的次表记录');
    final double before = _num(sub['remaining_principal']);
    if (before <= 0) throw StateError('这笔贷款已经结清');
    final int accountId = await resolveRepayAccountIn(txn,
        liabilityId: liabilityId, preferred: repayAccountId);
    final int now = repaidAt.millisecondsSinceEpoch;
    final double rate = _rate(sub['prepay_penalty_rate']);

    Map<String, Object?>? plan;
    double currentTotal = 0;
    double penalty = 0;
    int paidTerms = _int(sub['paid_terms']);
    double after;

    // 一次性还清 / 随借随还**没有自动计划**：找不到 pending 时不能抛错，
    // 否则这两类债永远还不了（文档 IF-Z17：它们是唯一由用户新建记录的情形）。
    if (payCurrentTerm) {
      plan = (await txn.query(
        _loanRepay,
        where: 'liability_id = ? AND state IN (?, ?)',
        whereArgs: <Object?>[liabilityId, 'pending', 'overdue'],
        orderBy: 'term_no ASC',
        limit: 1,
      )).firstOrNull;
      if (plan != null) {
        currentTotal = _num(plan['principal_part']) +
            _num(plan['interest_part']) +
            _num(plan['fee']);
      }
    }
    final double balance = repaidAmount - currentTotal;
    final double prepayPrincipal = balance > 0 ? balance : 0;
    penalty = hasPenalty
        ? (penaltyOverride ?? _floor2(prepayPrincipal * rate))
        : 0;
    final double remainingPayPrincipal = prepayPrincipal - penalty;
    final double planPrincipal = plan == null ? 0 : _num(plan['principal_part']);
    after = before - planPrincipal - remainingPayPrincipal;
    if (plan != null) {
      paidTerms += 1;
      await dao.update(txn, _loanRepay, _int(plan['id']),
          <String, Object?>{'state': 'cancelled', 'updated_at': now});
    } else if (!payCurrentTerm) {
      // 不还本期：当期仍是 pending，只按新剩余本金重算它，不生成下期。
      await _recurrentPending(txn, liabilityId, _loanRepay, sub, after);
    }
    if (after < 0) after = 0;
    final bool settled = after <= 0;

    final int repayId = await dao.insert(txn, _loanRepay, <String, Object?>{
      'liability_id': liabilityId,
      'sub_liability_id': _int(sub['id']),
      'record_source': 'user',
      'term_no': plan == null ? null : _int(plan['term_no']),
      'due_at': now,
      'principal_part': _s(before - after),
      'interest_part': _s(plan == null ? 0 : _num(plan['interest_part'])),
      'fee': '0',
      'penalty_amount': _s(penalty),
      'state': 'paid',
      'repaid_at': now,
      'repaid_amount': _s(repaidAmount),
      'repay_account_id': accountId,
      'remaining_after': _s(after),
      'manual_adjusted': 0,
      'note': penalty > 0 ? '提前还款违约金 ${_s(penalty)} 元' : '',
      ..._stamp(),
    });
    await dao.update(txn, _loanSub, _int(sub['id']), <String, Object?>{
      'paid_terms': paidTerms,
      'remaining_principal': _s(after),
      'updated_at': now,
    });
    await dao.update(txn, _main, liabilityId, <String, Object?>{
      'total_loss': await recomputeTotalLossIn(
          txn, liabilityId: liabilityId, isInstallment: false),
      'status': settled ? 'settled' : 'normal',
      'updated_at': now,
    });
    // 还完本期后必须生成下一条 pending，否则未来没有任何待还记录，
    // 「还本期」入口会永久失效（运行模型硬-2）。
    int? nextId;
    if (!settled && plan != null) {
      nextId = await generateNextPendingIn(
        txn,
        liabilityId: liabilityId,
        subId: _int(sub['id']),
        previous: <String, Object?>{
          'term_no': plan['term_no'],
          'due_at': plan['due_at'],
        },
        sub: sub,
        remaining: after,
        paidTerms: paidTerms,
        isInstallment: false,
        settled: false,
      );
    }
    if (settled && _int(sub['link_asset_id']) > 0) {
      await syncMortgageStateIn(txn, assetId: _int(sub['link_asset_id']));
    }
    return AzRepayOutcome(
      repayId: repayId,
      amount: repaidAmount,
      repayAccountId: accountId,
      mountCreditcardId: null,
      settled: settled,
      nextPendingId: nextId,
    );
  }

  /// IF-Z18：分期提前结清 / 部分提前还。
  /// 【所属模块】service/ledger · 分期结清
  /// 【实现功能】先选「是否提前结清」；结清按 settle_rule 五值算应还总额并与实还金额比对，部分还按 I6 两模式重算；当期 auto 计划改「已取消」。
  /// 【使用限制】settle_rule 五值必须校验；模式 A 要求实还金额 = 每期应还额 × 正整数 k，不满足拒绝保存；已收手续费不退；同一次收费只进 fee 或 penalty_amount 一列。
  /// 【入参与结果】收 txn / liabilityId / 实还金额 / 时间 / 账户 / 是否提前结清 / 规则 / 比例 / 服务费 / 部分还模式；返回 AzRepayOutcome。
  /// 【异常与调用方处理】规则非法、输入缺失、模式 A 金额不是整期额、实还与结清总额不一致抛 ArgumentError；DAO 异常上抛并回滚。
  Future<AzRepayOutcome> settleInstallmentIn(
    DatabaseExecutor txn, {
    required int liabilityId,
    required double repaidAmount,
    required DateTime repaidAt,
    int? repayAccountId,
    required bool settleAll,
    String? settleRule,
    double? ruleRatio,
    double? serviceFee,
    String partialMode = 'B',
  }) async {
    if (repaidAmount <= 0) throw ArgumentError('还款金额必须大于 0');
    final Map<String, Object?>? sub = (await txn.query(
      _instSub, where: 'liability_id = ?', whereArgs: <Object?>[liabilityId],
      limit: 1)).firstOrNull;
    if (sub == null) throw StateError('找不到这笔分期的次表记录');
    final double before = _num(sub['remaining_principal']);
    if (before <= 0) throw StateError('这笔分期已经结清');
    final int accountId = await resolveRepayAccountIn(txn,
        liabilityId: liabilityId, preferred: repayAccountId);
    final int now = repaidAt.millisecondsSinceEpoch;
    final int paidTerms = _int(sub['paid_terms']);
    final int totalTerms = _int(sub['total_terms']);
    final List<Map<String, Object?>> plans = await txn.query(
      _instRepay,
      where: 'liability_id = ? AND state IN (?, ?)',
      whereArgs: <Object?>[liabilityId, 'pending', 'overdue'],
      orderBy: 'term_no ASC',
      limit: 1,
    );
    final Map<String, Object?>? plan = plans.firstOrNull;
    final double perTermPrincipal = before / (totalTerms - paidTerms);
    final double perTermFee = before * _rate(sub['per_term_fee_rate']);
    final double perTermInterest = before * _rate(sub['annual_rate']) / 12;
    final double perTermTotal =
        perTermPrincipal + perTermFee + perTermInterest;

    double fee = 0;
    double penalty = 0;
    double after = before;
    double effectiveAmount = repaidAmount;
    int newTerms = totalTerms;
    String note = '';

    if (settleAll) {
      final String rule = (settleRule ?? '').toString();
      if (!_settleRules.contains(rule)) {
        throw ArgumentError('提前结清规则只能是五种之一：$rule');
      }
      final int restTerms = totalTerms - paidTerms - 1;
      switch (rule) {
        case 'waive_unbilled':
          break;
        case 'charge_all_remaining':
          fee = perTermFee * restTerms;
          break;
        case 'charge_one_more':
          fee = perTermFee;
          break;
        case 'ratio_of_remaining':
          if (ruleRatio == null || ruleRatio < 0) {
            throw ArgumentError('按剩余本金比例必须填比例');
          }
          penalty = _floor2(before * ruleRatio);
          break;
        case 'extra_service_fee':
          if (serviceFee == null || serviceFee < 0) {
            throw ArgumentError('另收服务费必须填金额');
          }
          penalty = serviceFee;
          break;
      }
      final double expected =
          before + perTermInterest + perTermFee + fee + penalty;
      if ((_floor2(repaidAmount) - _floor2(expected)).abs() > 0.01) {
        // 文档 IF-Z18：不一致时提示核对、确认后「以规则算出的金额为准」写回。
        // 这里不再抛错回滚——用户不可能凭空填中软件算出的总额，硬校验会让
        // 全额结清永远办不成。债务侧与账户出账统一用 effectiveAmount。
        effectiveAmount = expected;
        note = '提前结清规则：$rule；剩余手续费 ${_s(fee)} 元、额外费用 ${_s(penalty)} 元；'
            '用户填 ${_s(repaidAmount)} 元，按规则以 ${_s(expected)} 元为准';
      } else {
        note = '提前结清规则：$rule；剩余手续费 ${_s(fee)} 元、额外费用 ${_s(penalty)} 元';
      }
      after = 0;
    } else {
      if (partialMode == 'A') {
        if (perTermTotal <= 0 ||
            (repaidAmount / perTermTotal -
                    (repaidAmount / perTermTotal).roundToDouble())
                .abs() >
                0.001) {
          throw ArgumentError(
              '缩期模式要求还款金额必须是每期应还额 ${_s(perTermTotal)} 元的整数倍');
        }
        final int k = (repaidAmount / perTermTotal).round();
        newTerms = totalTerms - k;
        if (newTerms < paidTerms + 1) newTerms = paidTerms + 1;
        after = before - perTermPrincipal * k;
        if (after < 0) after = 0;
      } else {
        after = before - repaidAmount;
        if (after < 0) after = 0;
      }
      note = '部分提前还：模式 $partialMode，剩余本金 ${_s(after)} 元';
    }
    final bool settled = after <= 0;
    if (plan != null) {
      await dao.update(txn, _instRepay, _int(plan['id']),
          <String, Object?>{'state': 'cancelled', 'updated_at': now});
    }
    final int repayId = await dao.insert(txn, _instRepay, <String, Object?>{
      'liability_id': liabilityId,
      'sub_liability_id': _int(sub['id']),
      'record_source': 'user',
      'term_no': paidTerms + 1,
      'due_at': now,
      'principal_part': _s(before - after),
      'interest_part': _s(settleAll ? perTermInterest : 0),
      'fee': _s(fee),
      'penalty_amount': _s(penalty),
      'settle_rule': settleAll ? settleRule : null,
      'settle_rule_ratio': settleAll && settleRule == 'ratio_of_remaining'
          ? ruleRatio
          : null,
      'settle_service_fee': settleAll && settleRule == 'extra_service_fee'
          ? _s(serviceFee ?? 0)
          : null,
      'state': 'paid',
      'repaid_at': now,
      'repaid_amount': _s(effectiveAmount),
      'repay_account_id': accountId,
      'remaining_after': _s(after),
      'manual_adjusted': 0,
      'note': note,
      ..._stamp(),
    });
    await dao.update(txn, _instSub, _int(sub['id']), <String, Object?>{
      'total_terms': newTerms,
      'remaining_principal': _s(after),
      'updated_at': now,
    });
    if (!settled) {
      await _recurrentPending(
          txn, liabilityId, _instRepay, sub, after, isInstallment: true);
    }
    await dao.update(txn, _main, liabilityId, <String, Object?>{
      'total_loss': await recomputeTotalLossIn(
          txn, liabilityId: liabilityId, isInstallment: true),
      'status': settled ? 'settled' : 'normal',
      'updated_at': now,
    });
    return AzRepayOutcome(
      repayId: repayId,
      amount: effectiveAmount,
      repayAccountId: accountId,
      mountCreditcardId: _nullableInt(sub['mount_creditcard_id']),
      settled: settled,
      nextPendingId: null,
    );
  }

  /// IF-Z19：随借随还支取。
  /// 【所属模块】service/ledger · 贷款支取
  /// 【实现功能】写一条支取记录并同步增加 remaining_principal，为按日单利分段计息提供日期与金额载体。
  /// 【使用限制】只给 revolving 用；累计支取不超过 loan_amount；不写账户流水。
  /// 【入参与结果】收 txn / liabilityId / 支取金额 / 时间 / 备注；返回支取记录 id。
  /// 【异常与调用方处理】金额 <= 0、超额、非 revolving、已结清抛 ArgumentError / StateError；DAO 异常上抛并回滚。
  Future<int> loanDrawIn(
    DatabaseExecutor txn, {
    required int liabilityId,
    required double drawAmount,
    required DateTime drawnAt,
    String note = '',
  }) async {
    if (drawAmount <= 0) throw ArgumentError('支取金额必须大于 0');
    final Map<String, Object?>? sub = (await txn.query(
      _loanSub, where: 'liability_id = ?', whereArgs: <Object?>[liabilityId],
      limit: 1)).firstOrNull;
    if (sub == null) throw StateError('找不到这笔贷款的次表记录');
    if ((sub['repay_method'] ?? '').toString() != 'revolving') {
      throw StateError('只有随借随还才能登记支取');
    }
    final double limit = _num(sub['loan_amount']);
    final double used = _num(sub['remaining_principal']);
    if (used + drawAmount > limit + 0.001) {
      throw ArgumentError('累计支取不能超过循环额度 ${_s(limit)} 元');
    }
    final int now = drawnAt.millisecondsSinceEpoch;
    final int id = await dao.insert(txn, _loanDraw, <String, Object?>{
      'liability_id': liabilityId,
      'sub_liability_id': _int(sub['id']),
      'draw_amount': _s(drawAmount),
      'drawn_at': now,
      'note': note,
      ..._stamp(),
    });
    await dao.update(txn, _loanSub, _int(sub['id']), <String, Object?>{
      'remaining_principal': _s(used + drawAmount),
      'updated_at': now,
    });
    return id;
  }

  /// IF-Z20：逾期扫描（用户打开 / 操作时现算现标）。
  /// 【所属模块】service/ledger · 逾期状态机
  /// 【实现功能】过 due_at 未还的记录改「逾期」、主表改「逾期」，按逾期本金与未付期内利息算罚息 + 复利写 penalty_amount 并计入 total_loss。
  /// 【使用限制】不做定时跨天累计；该记录还款前不生成下一条；直到生成正常 pending 主表才回「正常」；两张还款附表共用。
  /// 【入参与结果】收 txn / liabilityId / 当前时间 / 是否分期；返回本次标逾期条数，必须 await。
  /// 【异常与调用方处理】时间非法抛 ArgumentError；DAO 异常上抛并回滚；调用方不得把结果写回账户余额。
  Future<int> overdueScanIn(
    DatabaseExecutor txn, {
    required int liabilityId,
    required DateTime now,
    bool isInstallment = false,
  }) async {
    final String repayTable = isInstallment ? _instRepay : _loanRepay;
    final String subTable = isInstallment ? _instSub : _loanSub;
    final Map<String, Object?>? sub = (await txn.query(
      subTable, where: 'liability_id = ?', whereArgs: <Object?>[liabilityId],
      limit: 1)).firstOrNull;
    if (sub == null) return 0;
    final double rate = _rate(sub['overdue_penalty_rate']);
    final List<Map<String, Object?>> rows = await txn.query(
      repayTable,
      where: 'liability_id = ? AND state IN (?, ?) AND due_at < ?',
      whereArgs: <Object?>[liabilityId, 'pending', 'overdue',
          now.millisecondsSinceEpoch],
    );
    int changed = 0;
    for (final Map<String, Object?> row in rows) {
      final DateTime due = DateTime.fromMillisecondsSinceEpoch(
          _int(row['due_at']));
      final int days = now.difference(due).inDays;
      if (days < 0) continue;
      final double principal = _num(row['principal_part']);
      final double unpaidInterest = _num(row['interest_part']);
      final double penalty = _floor2(principal * rate / 365 * days) +
          _floor2(unpaidInterest * rate / 365 * days);
      // 罚息按「截至当前的总天数」重算覆盖，不逐日累加；
      // 旧的构成说明先删掉再写新的，避免每次打开都堆一行 / 天数过时。
      final String oldNote = (row['note'] ?? '').toString().replaceAll(
          RegExp(r'；?逾期 \d+ 天罚息\+复利 [\d.]+ 元'), '').trim();
      final String note = penalty > 0
          ? <String>[
              oldNote,
              '逾期 $days 天罚息+复利 ${_s(penalty)} 元',
            ].where((String s) => s.isNotEmpty).join('；')
          : oldNote;
      await dao.update(txn, repayTable, _int(row['id']), <String, Object?>{
        'state': 'overdue',
        'penalty_amount': _s(penalty),
        'note': note,
        'updated_at': now.millisecondsSinceEpoch,
      });
      changed++;
    }
    if (changed > 0) {
      await dao.update(txn, _main, liabilityId, <String, Object?>{
        'status': 'overdue',
        'total_loss': await recomputeTotalLossIn(
          txn, liabilityId: liabilityId, isInstallment: isInstallment),
        'updated_at': now.millisecondsSinceEpoch,
      });
    }
    return changed;
  }

  /// IF-Z21：总亏损累加（每次还款后全量重算，避免逐笔累加漂移）。
  /// 【所属模块】service/ledger · 债务统计写回
  /// 【实现功能】贷款 = Σ 已还各期(interest_part + fee + penalty_amount) + 次表 service_fee；分期同式但无 service_fee 项。
  /// 【使用限制】主表只存结果、由软件累加、用户不手填；只做这一笔债维度展示，不进账户侧三个统计视图、与账户流水不相加；必须在事务内。
  /// 【入参与结果】收 txn / liabilityId / isInstallment；返回新的 total_loss 十进制字符串，必须 await。
  /// 【异常与调用方处理】DAO 异常上抛并回滚；调用方不得拿返回值写账户余额或支出统计。
  Future<String> recomputeTotalLossIn(
    DatabaseExecutor txn, {
    required int liabilityId,
    required bool isInstallment,
  }) async {
    final String repayTable = isInstallment ? _instRepay : _loanRepay;
    final List<Map<String, Object?>> rows = await txn.query(
      repayTable,
      where: 'liability_id = ? AND state = ?',
      whereArgs: <Object?>[liabilityId, 'paid'],
    );
    double total = 0;
    for (final Map<String, Object?> r in rows) {
      total += _num(r['interest_part']) +
          _num(r['fee']) +
          _num(r['penalty_amount']);
    }
    // 逾期罚息已经实际发生，也要计入「一共多付了多少钱」；
    // 记录还完后会变成 paid，penalty 已在上面累加过，不会双计。
    final List<Map<String, Object?>> overdue = await txn.query(
      repayTable,
      where: 'liability_id = ? AND state = ?',
      whereArgs: <Object?>[liabilityId, 'overdue'],
    );
    for (final Map<String, Object?> r in overdue) {
      total += _num(r['penalty_amount']);
    }
    if (!isInstallment) {
      final Map<String, Object?>? sub = (await txn.query(
        _loanSub, where: 'liability_id = ?', whereArgs: <Object?>[liabilityId],
        limit: 1)).firstOrNull;
      if (sub != null) total += _num(sub['service_fee']);
    }
    return _s(total);
  }

  /// IF-Z22：抵押状态同步（负债侧触发，IF-Z09 同一接口）。
  /// 【所属模块】service/asset · 抵押状态
  /// 【实现功能】在新增抵押债务或任一抵押贷款结清时，按「未结清且未软删」重算该资产 mortgage_state 为已抵押 / 正常。
  /// 【使用限制】与资产侧 IF-Z09 同一接口；不存顺位、不建多押列表；判定不按打开页面时点漂移；必须与债务动作同事务。
  /// 【入参与结果】收 txn / assetId；返回 Future<void>，必须 await。
  /// 【异常与调用方处理】DAO 异常上抛并与债务动作一并回滚；调用方自行 try/catch 保持旧状态。
  Future<void> syncMortgageStateIn(
    DatabaseExecutor txn, {
    required int assetId,
  }) async {
    final List<Map<String, Object?>> live = await txn.query(
      _loanSub,
      columns: <String>['liability_id'],
      where: 'link_asset_id = ? AND has_collateral = 1',
      whereArgs: <Object?>[assetId],
    );
    bool mortgaged = false;
    for (final Map<String, Object?> r in live) {
      final Map<String, Object?>? m = (await txn.query(
        _main,
        columns: <String>['status', 'deleted_at'],
        where: 'id = ?',
        whereArgs: <Object?>[r['liability_id']],
        limit: 1,
      )).firstOrNull;
      if (m == null) continue;
      if (m['deleted_at'] != null) continue;
      if ((m['status'] ?? '').toString() == 'settled') continue;
      mortgaged = true;
      break;
    }
    final int now = DateTime.now().millisecondsSinceEpoch;
    for (final String t in <String>['az_asset_property', 'az_asset_vehicle']) {
      final List<Map<String, Object?>> rows = await txn.query(
        t,
        columns: <String>['id'],
        where: 'asset_id = ?',
        whereArgs: <Object?>[assetId],
        limit: 1,
      );
      final int? subId = rows.firstOrNull?['id'] as int?;
      if (subId == null) continue;
      await dao.update(txn, t, subId, <String, Object?>{
        'mortgage_state': mortgaged ? 'mortgaged' : 'unmortgaged',
        'updated_at': now,
      });
    }
  }

  /// IF-Z23：还款账户回落（附表 → 主表）。
  /// 【所属模块】service/ledger · 还款账户绑定
  /// 【实现功能】优先取调用方指定的账户，未指定则回落主表 link_account_id；账户不存在时抛错提示重新关联，不自动清空。
  /// 【使用限制】主表 link_account_id、次表 mount_creditcard_id、附表 repay_account_id 三者方向不同不可混用；跨类统计一律取 accounts.id。
  /// 【入参与结果】收 txn / liabilityId / preferred；返回生效账户 id，必须 await。
  /// 【异常与调用方处理】账户未绑定或不存在的抛 ArgumentError / StateError；调用方自行 try/catch 提示用户重新关联。
  Future<int> resolveRepayAccountIn(
    DatabaseExecutor txn, {
    required int liabilityId,
    int? preferred,
  }) async {
    int id = preferred ?? 0;
    if (id <= 0) {
      final Map<String, Object?>? main = (await txn.query(
        _main, where: 'id = ?', whereArgs: <Object?>[liabilityId], limit: 1))
          .firstOrNull;
      id = _int(main?['link_account_id']);
    }
    if (id <= 0) {
      throw StateError('这笔债没有绑定还款账户，请在还款弹层选择付款账户');
    }
    final List<Map<String, Object?>> rows = await txn.query(
      'accounts',
      columns: <String>['id', 'kind'],
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('还款账户已删除，请重新关联');
    // 信用卡的「出账」是增加已用额度，拿它做贷款扣款会把余额写反（IF-Z23）。
    if ((rows.first['kind'] ?? '').toString() == 'credit') {
      throw ArgumentError('还款账户不能是信用卡，请选流动资金 / 其他资金账户');
    }
    return id;
  }

  /// 【所属模块】service/ledger · 还款计划
  /// 【实现功能】部分提前还后重算当前 pending 的本金 / 利息 / 手续费，不生成下期、不改 paid_terms。
  /// 【使用限制】只修改 state 为 pending / overdue 的那一条；金额向下取整到分；必须在事务内。
  /// 【入参与结果】收 txn / liabilityId / 附表名 / 次表 / 新剩余本金；返回 Future<void>。
  /// 【异常与调用方处理】DAO 异常上抛并回滚；无 pending 时静默返回。
  Future<void> _recurrentPending(
    DatabaseExecutor txn,
    int liabilityId,
    String table,
    Map<String, Object?> sub,
    double remaining, {
    bool isInstallment = false,
  }) async {
    final List<Map<String, Object?>> rows = await txn.query(
      table,
      where: 'liability_id = ? AND state IN (?, ?)',
      whereArgs: <Object?>[liabilityId, 'pending', 'overdue'],
      orderBy: 'term_no ASC',
      limit: 1,
    );
    final Map<String, Object?>? row = rows.firstOrNull;
    if (row == null) return;
    final int terms = _int(sub['total_terms']);
    final int paid = _int(sub['paid_terms']);
    final int rest = terms > paid ? terms - paid : 1;
    final double principal = _floor2(remaining / rest);
    final double interest = isInstallment
        ? _floor2(remaining * _rate(sub['annual_rate']) / 12)
        : _floor2(remaining *
            _periodRate(_rate(sub['annual_rate']),
                (sub['term_unit'] ?? 'month').toString()));
    final double fee = isInstallment
        ? _floor2(remaining * _rate(sub['per_term_fee_rate']))
        : 0;
    await dao.update(txn, table, _int(row['id']), <String, Object?>{
      'principal_part': _s(principal),
      'interest_part': _s(interest),
      'fee': _s(fee),
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// 【所属模块】service/ledger · 内部工具
  /// 【实现功能】按 id 取一行，供生成下一条后判断是否逾期。
  /// 【使用限制】只读；表名必须来自 AzSchema 白名单。
  /// 【入参与结果】收 txn / table / id；返回行 Map，缺失返回空 Map。
  /// 【异常与调用方处理】查询异常上抛；调用方自行 try/catch。
  Future<Map<String, Object?>> _rowById(
      DatabaseExecutor txn, String table, int id) async {
    final List<Map<String, Object?>> rows = await txn.query(
      table, where: 'id = ?', whereArgs: <Object?>[id], limit: 1);
    return rows.firstOrNull ?? <String, Object?>{};
  }

  /// 【所属模块】service/ledger · 内部工具
  /// 【实现功能】判断一条待还记录是否已过应还日且仍未还。
  /// 【使用限制】只读；状态不在 pending / overdue 时不算逾期。
  /// 【入参与结果】收行 Map；返回 bool。
  /// 【异常与调用方处理】不抛异常；due_at 缺失按不逾期处理。
  bool _isOverdue(Map<String, Object?> row) {
    final int due = _int(row['due_at']);
    if (due <= 0) return false;
    return DateTime.fromMillisecondsSinceEpoch(due).isBefore(DateTime.now()) &&
        ((row['state'] ?? '').toString() == 'pending' ||
            (row['state'] ?? '').toString() == 'overdue');
  }

  /// 【所属模块】service/ledger · 内部工具
  /// 【实现功能】统一补留痕三件套（created_at / updated_at / revision）。
  /// 【使用限制】只用于 insert 前；不修改入参。
  /// 【入参与结果】无入参；返回新 Map。
  /// 【异常与调用方处理】不抛异常。
  Map<String, Object?> _stamp() {
    final int now = DateTime.now().millisecondsSinceEpoch;
    return <String, Object?>{
      'created_at': now,
      'updated_at': now,
      'revision': 1,
    };
  }

  // ── 纯计算：金额 / 期利率 / 到期日 ───────────────────────────────

  /// 【所属模块】service/ledger · 内部工具
  /// 【实现功能】把 TEXT / num 金额解析成 double，非法按 0。
  /// 【使用限制】只用于读库值；不用于回写。
  /// 【入参与结果】收任意值；返回 double。
  /// 【异常与调用方处理】不抛异常。
  static double _num(Object? v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().trim()) ?? 0;
  }

  static int _int(Object? v) {
    if (v == null) return 0;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString().trim()) ?? 0;
  }

  static int? _nullableInt(Object? v) {
    final int i = _int(v);
    return i > 0 ? i : null;
  }

  static double _rate(Object? v) {
    final double r = _num(v);
    return r < 0 ? 0 : r;
  }

  /// 向下取整到分（L2：尾差全放末期）。
  static double _floor2(double v) =>
      (v * 100).floorToDouble() / 100;

  static String _s(double v) => _floor2(v < 0 ? 0 : v).toStringAsFixed(2);

  /// 期利率：日 = 年/365、周 = 日×7、月 /12、季 /4、年原值。
  static double _periodRate(double annual, String unit) {
    final double daily = annual / 365;
    return switch (unit) {
      'day' => daily,
      'week' => daily * 7,
      'month' => annual / 12,
      'quarter' => annual / 4,
      _ => annual,
    };
  }

  /// 第 1 期本息（按草案四种公式，尾差放末期）。
  static _Period _firstPeriod(Map<String, Object?> sub,
      {required bool isInstallment}) {
    if (isInstallment) {
      final double amount = _num(sub['installment_amount']);
      final int terms = _int(sub['total_terms']);
      final double principal = _floor2(amount / terms);
      final double interest = _floor2(amount * _rate(sub['annual_rate']) / 12);
      final double fee = _floor2(amount * _rate(sub['per_term_fee_rate']));
      return _Period(principal, interest, fee);
    }
    return _periodAt(sub,
        isInstallment: false,
        remaining: _num(sub['loan_amount']),
        termNo: 1,
        totalTerms: _int(sub['total_terms']));
  }

  /// 第 termNo 期本息。等额本金 / 等额本息 / 先息后本分别按公式算，
  /// 末期把尾差补齐、使 remaining_after 强制归零。
  static _Period _periodAt(
    Map<String, Object?> sub, {
    required bool isInstallment,
    required double remaining,
    required int termNo,
    required int totalTerms,
  }) {
    if (isInstallment) {
      final int rest = totalTerms - termNo + 1;
      final double principal =
          termNo == totalTerms ? remaining : _floor2(remaining / rest);
      final double interest =
          _floor2(remaining * _rate(sub['annual_rate']) / 12);
      final double fee =
          _floor2(remaining * _rate(sub['per_term_fee_rate']));
      return _Period(principal, interest, fee);
    }
    final String method = (sub['repay_method'] ?? '').toString();
    final String unit = (sub['term_unit'] ?? 'month').toString();
    final double annual = _rate(sub['annual_rate']);
    final double r = _periodRate(annual, unit);
    final int n = totalTerms > 0 ? totalTerms : 1;
    final double p = remaining;
    switch (method) {
      case 'equal_installment':
        final double factor = r <= 0 ? 1 / n : r * _pow(1 + r, n) / (_pow(1 + r, n) - 1);
        final double monthly = _floor2(p * factor);
        final double interest = _floor2(p * r);
        final double principal = termNo == n ? p : _floor2(monthly - interest);
        return _Period(principal < 0 ? 0 : principal, interest, 0);
      case 'interest_first':
        return _Period(termNo == n ? p : 0, _floor2(p * r), 0);
      case 'equal_principal':
      default:
        final double principal =
            termNo == n ? p : _floor2(p / (n - termNo + 1));
        return _Period(principal, _floor2(p * r), 0);
    }
  }

  static double _pow(double base, int n) {
    double out = 1;
    for (int i = 0; i < n; i++) {
      out *= base;
    }
    return out;
  }

  /// L3 首期后延：月/季/年取起始日之后的**第二个**日历还款日
  /// （1 月 28 日放款、每月 15 日还款 → 第一条 2/15~3/15）；
  /// day 就是起始日 +1 天、week 就是下一个周六，不再二次后延。
  static DateTime _firstDue(DateTime start, String unit, int day) {
    if (unit == 'day' || unit == 'week') return _nextDue(start, unit, day);
    final DateTime first = _nextDue(start, unit, day);
    return _nextDue(first, unit, day);
  }

  /// 下一条 due_at = 上一条 due_at + 一个完整周期。
  static DateTime _nextDue(DateTime from, String unit, int day) {
    switch (unit) {
      case 'day':
        return from.add(const Duration(days: 1));
      case 'week':
        int add = (DateTime.saturday - from.weekday) % 7;
        if (add == 0) add = 7;
        return DateTime(from.year, from.month, from.day + add);
      case 'month':
        return _atDay(_addMonths(from, 1), day);
      case 'quarter':
        return _atDay(_addMonths(from, 3), day);
      case 'year':
        return _atDay(_addMonths(from, 12), day);
      default:
        return _atDay(_addMonths(from, 1), day);
    }
  }

  /// end_date = 起始日 + 总期 × 单位（与首期后延保持同一套推算）。
  static DateTime _lastDue(DateTime start, String unit, int terms, int day) {
    DateTime due = _firstDue(start, unit, day);
    for (int i = 1; i < terms; i++) {
      due = _nextDue(due, unit, day);
    }
    return due;
  }

  static DateTime _addMonths(DateTime d, int n) {
    final int total = d.year * 12 + (d.month - 1) + n;
    final int y = total ~/ 12;
    final int m = total % 12 + 1;
    final int last = DateTime(y, m + 1, 0).day;
    return DateTime(y, m, d.day > last ? last : d.day);
  }

  static DateTime _atDay(DateTime d, int day) {
    if (day <= 0) return d;
    final int last = DateTime(d.year, d.month + 1, 0).day;
    return DateTime(d.year, d.month, day > last ? last : day);
  }
}

/// 一期金额（本金 / 利息 / 手续费），纯内存值对象。
/// 【所属模块】service/ledger · 内部值对象
/// 【实现功能】承载软件算好的一期三项金额，供写还款附表时展开。
/// 【使用限制】不可变；单位元；不持有 BuildContext、不写库。
/// 【入参与结果】构造收 principal / interest / fee；消费方只读字段。
/// 【异常与调用方处理】不抛异常；调用方负责向下取整与写回 TEXT。
class _Period {
  const _Period(this.principal, this.interest, this.fee);

  final double principal;
  final double interest;
  final double fee;
}
