import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../database/ledger/az_dao.dart';
import '../core/entity_registry.dart';
import '../core/lifecycle_service.dart';
import '../core/uniqueness_service.dart';
import '../core/unit_of_work.dart';
import '../../database/account/account_dao.dart';
import '../../database/category/category_dao.dart';
import '../../database/ledger/az_math.dart';
import '../../database/ledger/az_record.dart';

/// 资债模块的**共享账本**（ChangeNotifier，由 Services.initServices 装配）。
///
/// ══════════════════════════════════════════════════════════════════
/// 【职责边界：查询留在这里，写拆给 AzWriteController】
/// ══════════════════════════════════════════════════════════════════
/// 与账户模块同一套策略（用户上一轮明确肯定过）：资产、负债、还款计划、
/// 或有清单要在同一个页面交叉汇总、名称唯一索引跨类生效，所以「快照 /
/// 查询 / 统计输入」必须只有一份真源，就是本类。
/// 凡是写库动作一律不在这里，全部交给 [AzWriteController]；写完统一调
/// [refresh] 重读快照再通知页面（10.8 即时保存：先落盘、失败内存保持旧值）。
///
/// 【动态逻辑说明】为什么动态：资产与负债会随用户操作变化，构造期定不死。
///   1. `_data` 是数据库里全部行（含归档 / 回收站）在内存里的一份只读快照；
///   2. 写操作由 AzWriteController **先 await 落库（事务）→ 再 refresh()
///      → notifyListeners()**；
///   3. 页面用 `context.watch<AzController>()` 读，不另存一份列表。
/// 没有 Notifier 嵌套、没有跨帧注册、没有隐藏双模式。
///
/// 【为什么不监听 AccountController】家底账要读账户镜像，但账户变化由
/// 页面同时 `watch<AccountController>()` 触发重建即可，不需要这里注册
/// 第二个监听者（避免「一处变化通知两次」）。本类只在 [AzMath] 计算时
/// 接收一份账户列表，不持有它的副本。
class AzController extends ChangeNotifier {
  AzController(this.db, this.dao);

  final Database db;
  final AzDao dao;

  AzData _data = const AzData();

  AzData get data => _data;
  AzPreferences get preferences => _data.preferences;
  List<AssetRecord> get assets => _data.activeAssets;
  List<LiabilityRecord> get liabilities => _data.activeLiabilities;
  List<ContingentRecord> get contingents => _data.activeContingents;

  /// 今天由调用方在 build 里取一次传进 AzMath；这里不缓存，避免跨天不刷新。
  DateTime get today => DateTime.now();

  Future<void> load() async {
    _data = await dao.loadAll(db);
    notifyListeners();
  }

  Future<void> refresh() async => load();

  /// 某一笔债**当前生效**的还款计划（7.8 旧版本保留但不在列表里显示）。
  List<RepayPlanRecord> plansFor(LiabilityRecord debt) => _data.plans
      .where((RepayPlanRecord p) =>
          p.liabilityId == debt.id && p.planVersion == debt.activePlanVersion)
      .toList(growable: false);

  /// 某一项资产的买卖记录（按时间倒序，loadAll 已排好）。
  List<AssetTradeRecord> tradesFor(AssetRecord asset) => _data.trades
      .where((AssetTradeRecord t) => t.assetId == asset.id)
      .toList(growable: false);

  AssetRecord? assetById(int? id) {
    if (id == null) return null;
    for (final AssetRecord a in _data.assets) {
      if (a.id == id) return a;
    }
    return null;
  }

  LiabilityRecord? liabilityById(int? id) {
    if (id == null) return null;
    for (final LiabilityRecord d in _data.liabilities) {
      if (d.id == id) return d;
    }
    return null;
  }
}

/// 资债模块的**业务写入处理器**（普通 Provider，不是 ChangeNotifier）。
///
/// 【为什么拆开】与 SavingsAccountController / CreditCardAccountController
/// 同样的理由：共享账本只负责读，写操作各自持有事务与校验规则。
/// 页面一律 `context.read<AzWriteController>()` 取用。
///
/// 【事务边界】每个公开方法走 [uow.run] 开一次事务；DAO 不自建事务，
/// 且刷新放在 `afterCommit`，**提交成功后**才重读并通知。任一步抛异常，
/// 事务回滚、内存快照保持旧值（10.8 / 附录 E 崩溃恢复后数据不丢、不重复）。
/// 需要与其他模块（例如账户出账）同事务时，调用 [markPlanPaidIn] 这类
/// 「收 [DatabaseExecutor]、不自建事务」的内部接口，由外层 [UnitOfWork.run]
/// 统一编排。
///
/// 【本轮边界】单个资产 / 负债的登记动作仍然只写本模块的表；
/// **「还一期 = 债务处理 + 账户出账」的跨模块联动**已由
/// `AzRepaymentService.repayLoanInstallment` 用 [UnitOfWork.run] 编排到
/// 同一个事务里，债务侧走 [markPlanPaidIn]、账户侧走
/// `AccountLedger.debit`，任一方失败整体回滚。资产买卖的现金收付仍等
/// 对应模块开工后按同一套编排接入，不在这里假装完成。
class AzWriteController {
  AzWriteController(
    this.db,
    this.dao,
    this.ledger, {
    UnitOfWork? uow,
    LifecycleService? lifecycle,
    UniquenessService? uniqueness,
  })  : uow = uow ?? UnitOfWork(db),
        lifecycle = lifecycle ??
            LifecycleService(
              accountDao: AccountDao(),
              categoryDao: CategoryDao(),
              azDao: dao,
            ),
        uniqueness = uniqueness ?? const UniquenessService();

  final Database db;
  final AzDao dao;
  final AzController ledger;

  /// 与账户侧共享同一个事务编排入口，跨模块还款才能同事务。
  final UnitOfWork uow;

  /// 软删 / 恢复 / 归档 / 排序的唯一接口（全库共用一份实现）。
  final LifecycleService lifecycle;

  /// 名称 / 代码查重的唯一写侧真源。
  final UniquenessService uniqueness;

  /// 新增 / 编辑一项资产。名称重复由部分唯一索引兜底，提前给一句校验；
  /// 投资类代码相同不允许二次新增（用户口径），表单即时校验 + 这里查库兜底。
  Future<int> saveAsset(AssetRecord record) async {
    late int id;
    await uow.run((txn) async {
      await _checkAssetUnique(txn, record);
      id = await dao.saveAsset(txn, record);
    }, afterCommit: ledger.refresh);
    return id;
  }

  /// 投资类「新增」：建档 + 首笔买入批次，**一个事务**（6.5.1）。
  ///
  /// 首次买入就在这里录完，后续「追加购买」才放详情页（本轮不做）。
  /// 单价 × 数量 + 费用 = 一共从卡里出去的钱，也就是 az_assets.cost；
  /// 同时插一条 buy 批次，详情页「买卖记录 / 持仓量 / 持仓成本」立刻
  /// 有数，不会留下一个空标的。账户余额联动仍等「记支出 / 记收入」
  /// 模块接 AccountEntryDao.append，本方法不碰账户（与既有边界一致）。
  Future<int> saveInvestmentWithFirstBuy({
    required AssetRecord record,
    required double unitPrice,
    required double quantity,
    double fee = 0,
  }) async {
    _requirePositive(unitPrice, '每个多少钱');
    _requirePositive(quantity, '买了多少');
    if (fee < 0) throw ArgumentError('另外交的钱不能是负数');
    final double total = unitPrice * quantity + fee;
    if ((record.cost - total).abs() > 0.0001) {
      throw ArgumentError('一共花了多少和单价、数量、费用对不上');
    }
    late int id;
    final DateTime now = DateTime.now();
    await uow.run((txn) async {
      await _checkAssetUnique(txn, record);
      id = await dao.saveAsset(txn, record);
      await dao.insertTrade(
        txn,
        AssetTradeRecord(
          assetId: id,
          direction: TradeDirection.buy,
          occurredAt: now,
          unitPrice: unitPrice,
          quantity: quantity,
          fee: fee,
          amount: total,
          createdAt: now,
        ),
      );
    }, afterCommit: ledger.refresh);
    return id;
  }

  /// 名称 / 代码唯一的共用校验：表单即时拦一次，写库前再查一次，
  /// 防两个弹层同时提交或以后别的入口绕过表单。
  /// 空代码不查；软删的行不占用代码（与名称部分唯一索引同口径）。
  Future<void> _checkAssetUnique(
    DatabaseExecutor txn,
    AssetRecord record,
  ) async {
    _requirePositive(record.cost, '买它一共花了多少');
    // 写库前在同一事务内走全库唯一查重接口，口径与账户 / 分类一致。
    await uniqueness.assertUnique(
      txn,
      EntityKind.asset,
      name: record.name,
      code: record.code,
      excludeId: record.id,
    );
  }

  /// 「更新一下现在值多少」（6.4）：填一次价，留一次痕，历史不覆盖。
  /// toMap/fromMap 往返保证 id 与其余字段一个不丢，不需要 copyWith。
  Future<void> updateValuation(AssetRecord asset, double value) async {
    _requirePositive(value, '现在大概值多少');
    final Map<String, Object?> next = asset.toMap()
      ..['id'] = asset.id
      ..['latest_value'] = value
      ..['valued_at'] = DateTime.now().millisecondsSinceEpoch
      ..['valuation_source'] = ValuationSource.manual.dbValue
      ..['note'] = asset.note;
    await uow.run((txn) async {
      await dao.saveAsset(txn, AssetRecord.fromMap(next));
    }, afterCommit: ledger.refresh);
  }

  /// 记一笔买入 / 卖出（6.5）。卖出时用移动加权平均当场结算已落袋赚亏，
  /// 卖出数量不得超过持仓（6.5.4），否则拦下，不产生负持仓。
  Future<void> recordTrade({
    required AssetRecord asset,
    required TradeDirection direction,
    required double unitPrice,
    required double quantity,
    double fee = 0,
    int? accountId,
    String note = '',
    DateTime? occurredAt,
  }) async {
    _requirePositive(unitPrice, '每个多少钱');
    _requirePositive(quantity, '买了多少');
    if (fee < 0) throw ArgumentError('另外交的钱不能是负数');
    final double amount = unitPrice * quantity;
    final double total = direction == TradeDirection.buy
        ? amount + fee
        : amount - fee;
    if (total <= 0) throw ArgumentError('这次到手的钱算出来不是正数，请检查填的数');

    final AzTradeSummary before = AzMath.tradeSummary(ledger.tradesFor(asset));
    double? costBasis;
    double? realizedPnl;
    if (direction == TradeDirection.sell) {
      if (quantity > before.holdingQuantity + 0.000001) {
        throw ArgumentError(
          '你一共只有 ${before.holdingQuantity.toStringAsFixed(2)} 份，卖不了这么多',
        );
      }
      final double avg = before.holdingQuantity == 0
          ? 0
          : before.holdingCost / before.holdingQuantity;
      costBasis = avg * quantity;
      realizedPnl = total - costBasis;
    }

    final DateTime now = DateTime.now();
    final AssetTradeRecord row = AssetTradeRecord(
      assetId: asset.id!,
      direction: direction,
      occurredAt: occurredAt ?? now,
      unitPrice: unitPrice,
      quantity: quantity,
      fee: fee,
      amount: total,
      costBasis: costBasis,
      realizedPnl: realizedPnl,
      accountId: accountId,
      note: note,
      createdAt: now,
    );
    await uow.run((txn) async {
      await dao.insertTrade(txn, row);
    }, afterCommit: ledger.refresh);
  }

  /// 新增 / 编辑一笔欠款。剩余本金只许正数；填 0 时按 7.13 提示「是不是
  /// 已经还完了」，这里交回给表单层提示，不擅自改状态。
  Future<int> saveLiability(LiabilityRecord record) async {
    if (record.principal < 0) {
      throw ArgumentError('现在还欠多少不能是负数');
    }
    late int id;
    await uow.run((txn) async {
      await uniqueness.assertUnique(
        txn,
        EntityKind.liability,
        name: record.name,
        excludeId: record.id,
      );
      id = await dao.saveLiability(txn, record);
    }, afterCommit: ledger.refresh);
    return id;
  }

  /// 登记一期「已还」。
  /// 【边界】只改计划状态与实还金额，**不改负债剩余本金、不动账户余额**：
  /// 本金与现金要成对变动（7.12），少了账户那半边就绝不先改这半边。
  /// 「现在还欠多少」仍由用户在编辑负债时自己填（7.4 明确是输入项）。
  Future<void> markPlanPaid({
    required int planId,
    required double actualAmount,
    required String reason,
  }) async {
    if (actualAmount <= 0) throw ArgumentError('还了多少要填正数');
    await uow.run(
      (txn) async {
        await markPlanPaidIn(
          txn,
          planId: planId,
          actualAmount: actualAmount,
          reason: reason,
        );
      },
      afterCommit: ledger.refresh,
    );
  }

  /// **债务处理接口（可注入事务）**：只收 [DatabaseExecutor]、不自建事务。
  ///
  /// 供 [AzRepaymentService] 把「债务状态更新」和「账户出账」放进同一个
  /// [UnitOfWork.run]：出账失败 → 本方法已执行的 UPDATE 一并回滚，
  /// 不会出现「债务已记已还、卡里的钱没扣」。单独调用请走 [markPlanPaid]。
  /// 【所属模块】service/ledger · 债务处理（供跨模块编排调用）
  /// 【实现功能】把一期还款计划标记为已还并写回实还金额；收 txn、不自建事务，供 AzRepaymentService 与账户出账接口放进同一个事务。
  /// 【使用限制】只改计划状态与实还金额，不改负债剩余本金、不动账户余额；必须由外层 UnitOfWork.run 传入 txn，单独调用不会开事务；公开 markPlanPaid 仍保留给原负债页入口。
  /// 【入参与结果】txn 必填；planId / actualAmount / reason 必填。返回 Future<void>，调用方必须 await；刷新由外层 afterCommit 统一做，本方法不通知页面。
  /// 【异常与调用方处理】计划不存在 / 状态不合法 / DAO 异常原样上抛；外层事务会因此整体回滚（含账户出账）。调用方需自行 try/catch 提示用户，不要吞掉异常后继续刷新。
  Future<void> markPlanPaidIn(
    DatabaseExecutor txn, {
    required int planId,
    required double actualAmount,
    required String reason,
  }) =>
      dao.markPlanPaid(txn, planId, actualAmount, reason);

  /// 重算还款计划：另存新版本，旧版本保留可对比（7.8）。
  Future<void> regeneratePlan({
    required LiabilityRecord debt,
    required List<RepayPlanRecord> rows,
  }) async {
    final int version = debt.activePlanVersion + 1;
    await uow.run((txn) async {
      await dao.insertPlans(
        txn,
        <RepayPlanRecord>[
          for (final RepayPlanRecord r in rows)
            RepayPlanRecord(
              liabilityId: debt.id!,
              planVersion: version,
              termNo: r.termNo,
              dueDate: r.dueDate,
              principal: r.principal,
              interest: r.interest,
              fee: r.fee,
              remainingPrincipal: r.remainingPrincipal,
              status: r.status,
              reason: r.reason,
              createdAt: DateTime.now(),
            ),
        ],
      );
      await dao.setActivePlanVersion(txn, debt.id!, version);
    }, afterCommit: ledger.refresh);
  }

  /// 两张成对清单的唯一编辑入口（13.13）。
  Future<int> saveContingent(ContingentRecord record) async {
    if (record.maxAmount < 0) {
      throw ArgumentError('最多可能要还多少不能是负数');
    }
    late int id;
    await uow.run((txn) async {
      id = await dao.saveContingent(txn, record);
    }, afterCommit: ledger.refresh);
    return id;
  }

  /// 「万一这笔要我还」→ 转成正式负债（7.11 唯一入口）。
  /// 一个事务里同时插负债 + 软删原或有项，不会出现两边都算或两边都没算。
  Future<int> convertContingentToDebt({
    required ContingentRecord item,
    required LiabilityRecord debt,
  }) async {
    if (item.id == null) throw ArgumentError('这一笔还没保存');
    late int id;
    await uow.run((txn) async {
      id = await dao.insertLiabilityFromContingent(txn, debt, item.id!);
    }, afterCommit: ledger.refresh);
    return id;
  }

  /// 记录 / 显示口径（估值口径 / 价格过期天数 / 隐藏已还清）。切了留痕。
  /// 情境设计与分析模块的参数不在这里写。
  Future<void> setPreference(String key, String value) async {
    await uow.run((txn) async {
      await dao.setPreference(txn, key, value);
    }, afterCommit: ledger.refresh);
  }

  /// 软删进回收站（10.7）。reason 必填；删前由页面先问一句并数记录。
  Future<void> softDelete(String table, int id, String reason) async {
    await uow.run((txn) async {
      await lifecycle.softDelete(
        txn,
        EntityKind.fromTable(table),
        id,
        reason: reason,
      );
    }, afterCommit: ledger.refresh);
  }

  Future<void> restore(String table, int id) async {
    await uow.run((txn) async {
      await lifecycle.restore(txn, EntityKind.fromTable(table), id);
    }, afterCommit: ledger.refresh);
  }

  Future<void> setArchived(String table, int id, bool archived) async {
    await uow.run((txn) async {
      await lifecycle.setArchived(
        txn,
        EntityKind.fromTable(table),
        id,
        archived: archived,
      );
    }, afterCommit: ledger.refresh);
  }

  static void _requirePositive(double v, String label) {
    if (v <= 0) throw ArgumentError('$label要填正数，不能是 0 或空');
  }
}
