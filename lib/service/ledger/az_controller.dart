import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../database/ledger/az_dao.dart';
import '../../database/ledger/az_math.dart';
import '../../database/ledger/az_record.dart';
import '../../database/ledger/az_schema.dart';
import '../../service/core/entity_registry.dart';
import '../../service/core/lifecycle_service.dart';
import '../../service/core/uniqueness_service.dart';
import '../../service/core/unit_of_work.dart';
import 'az_liability_service.dart';

/// 资债共享账本：持有 AzData 快照，页面 watch 它自动重建。
/// 【所属模块】service/ledger · 资债共享账本
/// 【实现功能】从 AzDao 一次性加载 32 张表快照并按类型组聚合，写操作提交后由 load() 整体替换并通知页面。
/// 【使用限制】只持有内存快照，不缓存 db 写结果；页面不得直接改 data；刷新必须整份替换，不就地改 List。
/// 【入参与结果】构造收 Database 与 AzDao；load() 返回 Future<void> 必须 await；data / today / assetGroups / liabilityGroups 只读。
/// 【异常与调用方处理】load() 的读库异常原样上抛，调用方需自行 try/catch 并保留旧快照、展示错误态；不得吞异常后标成「已加载」。
class AzController extends ChangeNotifier {
  AzController(this.db, this.dao);

  final Database db;
  final AzDao dao;

  AzData _data = AzData.empty(DateTime.now());
  bool _loaded = false;

  /// 【所属模块】service/ledger · 资债共享账本
  /// 【实现功能】返回当前资债快照；未加载时返回空快照而非 null。
  /// 【使用限制】只读；页面应 watch 本 Controller，不要保存 data 副本。
  /// 【入参与结果】无入参；返回 AzData。
  /// 【异常与调用方处理】不抛异常；调用方按 loaded 判断是否展示加载态。
  AzData get data => _data;

  /// 【所属模块】service/ledger · 资债共享账本
  /// 【实现功能】返回快照生成时间，供「价待更新」一类时间判断。
  /// 【使用限制】只读；取的是读库那一刻，不是实时时钟。
  /// 【入参与结果】无入参；返回 DateTime。
  /// 【异常与调用方处理】不抛异常；调用方自行处理时区。
  DateTime get today => _data.today;

  /// 【所属模块】service/ledger · 资债共享账本
  /// 【实现功能】标记是否已完成首次加载，避免页面把空快照当真实空数据。
  /// 【使用限制】只读；由 load() 置 true，失败不置。
  /// 【入参与结果】无入参；返回 bool。
  /// 【异常与调用方处理】不抛异常；调用方按 false 展示加载态。
  bool get loaded => _loaded;

  /// 【所属模块】service/ledger · 资债共享账本
  /// 【实现功能】按类型组整理资产侧 / 负债侧的展示数据。
  /// 【使用限制】只读派生，不缓存；每次 build 重算，数据量为本模块记录数，无性能问题。
  /// 【入参与结果】无入参；返回 List<AzGroupStat>。
  /// 【异常与调用方处理】不抛异常；空组由调用方渲染空态。
  List<AzGroupStat> get assetGroups => AzMath.groupStats(_data, 'asset');
  List<AzGroupStat> get liabilityGroups => AzMath.groupStats(_data, 'liability');

  /// 【所属模块】service/ledger · 资债共享账本
  /// 【实现功能】一次性读库刷新整份快照并 notifyListeners；写操作的 afterCommit 统一挂这个方法。
  /// 【使用限制】不得在 UnitOfWork.run 的 body 内调用（会读到未提交数据）；只能在事务提交后的 afterCommit 里执行。
  /// 【入参与结果】无入参；返回 Future<void>，调用方必须 await。
  /// 【异常与调用方处理】读库异常上抛且不改旧快照、不通知；调用方需自行 try/catch 提示用户并保持旧值。
  Future<void> load() async {
    final AzData fresh = await dao.loadAll(db);
    _data = fresh;
    _loaded = true;
    notifyListeners();
  }
}

/// 资债写入口：所有写动作经 UnitOfWork.run 编排，主表 + 次表同事务。
/// 【所属模块】service/ledger · 资债写入口
/// 【实现功能】新增 / 修改 / 删除一条资产或负债，主表与对应次表在唯一事务里一起写；还款动作提供 markRepayPaidIn 供跨模块编排服务调用。
/// 【使用限制】页面不得直接调 AzDao 写方法；所有写必须经本类并放进 UnitOfWork.run；不得自建事务、不得在事务 body 内调 AzController.load。
/// 【入参与结果】构造收 db / dao / catalog / uow / lifecycle / uniqueness（装配点各建一份实例）；createEntry 收类型与两份字段 Map，返回新主表 id；removeEntry / setArchived 返回 Future<void>。
/// 【异常与调用方处理】类型未登记抛 ArgumentError；名字重复由 UniquenessService 抛 StateError；任一 SQL 失败整体回滚并原样上抛；调用方必须自行 try/catch 提示用户并保持旧快照。
class AzWriteController {
  AzWriteController(
    this.db,
    this.dao,
    this.catalog, {
    required this.uow,
    required this.lifecycle,
    required this.uniqueness,
  }) : liability = AzLiabilityService(dao);

  final Database db;
  final AzDao dao;
  final AzController catalog;
  final UnitOfWork uow;
  final LifecycleService lifecycle;
  final UniquenessService uniqueness;

  /// 负债侧功能接口（IF-Z13~Z23），只由本 Controller 与跨模块编排服务调用。
  final AzLiabilityService liability;

  /// 【所属模块】service/ledger · 资债写入口
  /// 【实现功能】补系统列：主表补 book_id / 排序 / 归档，主表与次表都补留痕三件套；判别列与外键由调用方填入。
  /// 【使用限制】只在写库前调用；次表没有 book_id / sort_order / archived，必须传 isMain=false；金额列传 String，不在这里做类型转换。
  /// 【入参与结果】收 values 与 isMain；返回新 Map（不修改入参）。
  /// 【异常与调用方处理】不抛异常；调用方需自行保证键都在目标表 DDL 中。
  Map<String, Object?> _stamp(Map<String, Object?> values, {required bool isMain}) {
    final int now = DateTime.now().millisecondsSinceEpoch;
    return <String, Object?>{
      ...values,
      if (isMain) 'book_id': 'default',
      'created_at': now,
      'updated_at': now,
      'revision': 1,
      if (isMain) 'sort_order': 0,
      if (isMain) 'archived': 0,
    };
  }

  /// 【所属模块】service/ledger · 资债写入口
  /// 【实现功能】新增一条资产 / 负债：同事务写主表 + 对应次表，先查名字唯一，提交后刷新共享账本。
  /// 【使用限制】必须在 uow.run 内完成两步写；spec 必须来自 AzSchema；mainValues 的 name 必填；次表外键由本方法补，表单不得传。
  /// 【入参与结果】收 spec / mainValues / subValues；返回 Future<int> 新主表 id，调用方必须 await；返回时事务已提交且快照已刷新。
  /// 【异常与调用方处理】spec 未登记抛 ArgumentError；重名抛 StateError；任一步 SQL 失败整体回滚（次表不会留下孤儿行）；调用方需自行 try/catch 提示用户，不得用返回值跳转详情前不判异常。
  Future<int> createEntry(
    AzTypeSpec spec,
    Map<String, Object?> mainValues,
    Map<String, Object?> subValues,
  ) async {
    final String table = spec.mainTable;
    final EntityKind kind =
        spec.side == 'asset' ? EntityKind.asset : EntityKind.liability;
    final String name = (mainValues['name'] ?? '').toString();
    int newId = -1;
    await uow.run(
      (DatabaseExecutor txn) async {
        await uniqueness.assertUnique(txn, kind, name: name);
        // 负债侧先做业务层校验与计算列补齐：实收金额、end_date、枚举、
        // 抵押必选、期数单位都在这里收口，写库前完成（IF-Z13 / IF-Z14）。
        Map<String, Object?> effMain = mainValues;
        Map<String, Object?> effSub = subValues;
        final bool isDebt = spec.side == 'liability';
        final bool isInstallment =
            isDebt && spec.subTable == 'az_liability_installment';
        if (isDebt) {
          final Map<String, Object?> normalized = isInstallment
              ? liability.normalizeInstallment(mainValues, subValues)
              : liability.normalizeLoan(mainValues, subValues);
          effMain = normalized['main']! as Map<String, Object?>;
          effSub = normalized['sub']! as Map<String, Object?>;
        }
        final Map<String, Object?> main = _stamp(<String, Object?>{
          ...effMain,
          spec.discriminatorColumn: spec.code,
        }, isMain: true);
        newId = await dao.insert(txn, table, main);
        final String fk = spec.side == 'asset' ? 'asset_id' : 'liability_id';
        final int subId = await dao.insert(
          txn,
          spec.subTable,
          _stamp(<String, Object?>{...effSub, fk: newId}, isMain: false),
        );
        if (isDebt) {
          // 运行时模型硬-1：只在「新建」这一时机生成第一条待还，禁止排满全部期数。
          await liability.createFirstPendingIn(
            txn,
            liabilityId: newId,
            subId: subId,
            isInstallment: isInstallment,
            sub: effSub,
            main: effMain,
          );
          if (!isInstallment) {
            final int assetId = int.tryParse(
                    (effSub['link_asset_id'] ?? '').toString()) ??
                0;
            if (assetId > 0) {
              await liability.syncMortgageStateIn(txn, assetId: assetId);
            }
          }
        }
      },
      afterCommit: () => catalog.load(),
    );
    return newId;
  }

  /// 【所属模块】service/ledger · 资债写入口
  /// 【实现功能】修改一条主表记录（含对应次表），同事务提交后刷新。
  /// 【使用限制】id 必须 > 0；不得改判别列与主键；次表不存在时只更新主表。
  /// 【入参与结果】收 spec / id / mainValues / subValues；返回 Future<void>，必须 await。
  /// 【异常与调用方处理】SQL 异常上抛并整体回滚；调用方需自行 try/catch 提示「保存未生效」。
  Future<void> updateEntry(
    AzTypeSpec spec,
    int id,
    Map<String, Object?> mainValues,
    Map<String, Object?> subValues,
  ) async {
    await uow.run(
      (DatabaseExecutor txn) async {
        await dao.update(txn, spec.mainTable, id,
            <String, Object?>{...mainValues, 'updated_at': DateTime.now().millisecondsSinceEpoch});
        if (subValues.isNotEmpty) {
          final AzRecord? sub = catalog.data.subFor(id, spec.subTable);
          if (sub != null) {
            await dao.update(txn, spec.subTable, sub.id,
                <String, Object?>{...subValues, 'updated_at': DateTime.now().millisecondsSinceEpoch});
          }
        }
      },
      afterCommit: () => catalog.load(),
    );
  }

  /// 【所属模块】service/ledger · 资债写入口
  /// 【实现功能】软删一条资产 / 负债，走 LifecycleService 唯一入口，同事务提交后刷新。
  /// 【使用限制】只允许主表两类实体；删除原因必填；软删后次表行保留，不物理删除。
  /// 【入参与结果】收 spec / id / reason；返回 Future<void>，必须 await。
  /// 【异常与调用方处理】不支持的实体抛 ArgumentError；记录不存在由 LifecycleService 抛 StateError；调用方需自行 try/catch。
  Future<void> removeEntry(AzTypeSpec spec, int id, String reason) async {
    final EntityKind kind =
        spec.side == 'asset' ? EntityKind.asset : EntityKind.liability;
    await uow.run(
      (DatabaseExecutor txn) async {
        await lifecycle.softDelete(txn, kind, id, reason: reason);
      },
      afterCommit: () => catalog.load(),
    );
  }

  /// 【所属模块】service/ledger · 资债写入口
  /// 【实现功能】切换资产归档标记，走 LifecycleService 唯一入口（负债侧不开放归档）。
  /// 【使用限制】仅 spec.side == 'asset'；必须在事务内调用。
  /// 【入参与结果】收 id / archived；返回 Future<void>，必须 await。
  /// 【异常与调用方处理】负债侧抛 ArgumentError；SQL 异常上抛并回滚；调用方需自行 try/catch。
  Future<void> setAssetArchived(int id, bool archived) async {
    await uow.run(
      (DatabaseExecutor txn) async {
        await lifecycle.setArchived(txn, EntityKind.asset, id, archived: archived);
      },
      afterCommit: () => catalog.load(),
    );
  }

  /// 【所属模块】service/ledger · 资债写入口
  /// 【实现功能】还款动作里的债务侧一步：把一条还款附表记录标记已还、写还后剩余本金与实还金额，并同步次表剩余本金。供 AzRepaymentService 与账户出账放在同一事务里调用。
  /// 【使用限制】必须由 AzRepaymentService 经 uow.run 调用，页面不得直调；本方法不自建事务、不写账户流水、不刷新快照。
  /// 【入参与结果】收 txn / repayTable / repayId / repaidAmount / remainingAfter（金额均为 String）；返回 Future<void>，必须 await。
  /// 【异常与调用方处理】非法表名由 AzDao 抛 ArgumentError；SQL 异常上抛并由外层事务整体回滚（账户出账一并撤销）；调用方需自行 try/catch 提示还款未生效。
  Future<void> markRepayPaidIn(
    DatabaseExecutor txn,
    String repayTable,
    int repayId, {
    required String repaidAmount,
    required String remainingAfter,
  }) async {
    final int now = DateTime.now().millisecondsSinceEpoch;
    await dao.update(txn, repayTable, repayId, <String, Object?>{
      'state': 'paid',
      'repaid_at': now,
      'repaid_amount': repaidAmount,
      'remaining_after': remainingAfter,
      'updated_at': now,
    });
  }

  /// IF-Z16 命名入口：把完整还款动作转给负债服务，供跨模块编排服务在同一事务里调用。
  /// 【所属模块】service/ledger · 资债写入口
  /// 【实现功能】转发到 AzLiabilityService.markPlanPaidIn，写回当期与次表、累加总亏损、生成下一条待还。
  /// 【使用限制】必须在 uow.run 事务内；页面不得直调；不得在此写账户流水或刷新快照。
  /// 【入参与结果】收 txn / liabilityId / planId / 实还金额 / 还款时间 / 还款账户 / 是否分期；返回 AzRepayOutcome，调用方必须 await。
  /// 【异常与调用方处理】参数与状态异常原样上抛由外层事务回滚；调用方自行 try/catch 提示「还款未生效」。
  Future<AzRepayOutcome> markPlanPaidIn(
    DatabaseExecutor txn, {
    required int liabilityId,
    required int planId,
    required double repaidAmount,
    required DateTime repaidAt,
    int? repayAccountId,
    double? fee,
    bool isInstallment = false,
  }) =>
      liability.markPlanPaidIn(
        txn,
        liabilityId: liabilityId,
        planId: planId,
        repaidAmount: repaidAmount,
        repaidAt: repaidAt,
        repayAccountId: repayAccountId,
        fee: fee,
        isInstallment: isInstallment,
      );

  /// IF-Z20：用户打开详情 / 执行还款前现算现标逾期（软件不打开不处理数据）。
  /// 【所属模块】service/ledger · 资债写入口
  /// 【实现功能】在唯一事务里扫描过 due_at 未还的期，标逾期、算罚息与复利、写回主表状态与总亏损，提交后刷新快照。
  /// 【使用限制】只在用户打开 / 操作时调用，不做定时跨天累计；不得在事务 body 内刷新快照。
  /// 【入参与结果】收 liabilityId / 是否分期；返回本次标逾期条数，调用方必须 await。
  /// 【异常与调用方处理】DAO 异常上抛并整体回滚；调用方自行 try/catch 保持旧状态。
  Future<int> scanOverdue(int liabilityId,
      {bool isInstallment = false}) async {
    int changed = 0;
    await uow.run(
      (DatabaseExecutor txn) async {
        changed = await liability.overdueScanIn(
          txn,
          liabilityId: liabilityId,
          now: DateTime.now(),
          isInstallment: isInstallment,
        );
      },
      afterCommit: () => catalog.load(),
    );
    return changed;
  }
}
