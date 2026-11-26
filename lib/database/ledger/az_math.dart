import 'az_record.dart';
import 'az_schema.dart';

/// 一个类型组在 home 页上的汇总数字。
/// 【所属模块】database/ledger · 资债统计
/// 【实现功能】承载某类型组的展示数据：组名、成员类型数、条目数、按类型块拆开的明细、金额合计。
/// 【使用限制】不可变；total 只作展示，不写回数据库。
/// 【入参与结果】构造收 groupKey / label / side / typeBlocks / entryCount / total；消费方只读字段。
/// 【异常与调用方处理】不抛异常；调用方按 entryCount==0 渲染空组提示。
class AzGroupStat {
  const AzGroupStat({
    required this.groupKey,
    required this.label,
    required this.side,
    required this.typeBlocks,
    required this.entryCount,
    required this.total,
  });

  final String groupKey;
  final String label;
  final String side;
  final List<AzTypeBlock> typeBlocks;
  final int entryCount;
  final double total;
}

/// 组内一个具体类型的条目块。
/// 【所属模块】database/ledger · 资债统计
/// 【实现功能】承载「A4（股票）」这类具体类型及其条目列表与小计。
/// 【使用限制】不可变；rows 来自 AzData 主表快照，不含次表行。
/// 【入参与结果】构造收 spec / rows / total；消费方只读字段。
/// 【异常与调用方处理】不抛异常；rows 为空时调用方渲染「暂无」。
class AzTypeBlock {
  const AzTypeBlock({required this.spec, required this.rows, required this.total});

  final AzTypeSpec spec;
  final List<AzRecord> rows;
  final double total;
}

/// 纯内存统计：按类型组聚合、算资产 / 负债合计。不读库、无副作用。
/// 【所属模块】database/ledger · 资债统计
/// 【实现功能】把 AzData 按 AzSchema.groups 整理成 home 页要的类型组汇总，并按草案口径算总资产 / 总负债 / 净资产。
/// 【使用限制】纯内存派生，不写库、不通知；金额列一律经 AzRecord.money 解析；挂卡分期不进总负债合计（草案主表标注 2）。
/// 【入参与结果】groupStats 收 AzData 与 side，返回 List<AzGroupStat>；assetsTotal / liabilitiesTotal / netWorth 收 AzData 返回 double。
/// 【异常与调用方处理】不抛异常；金额字符串非法按 0 处理，调用方需保证录入层已校验格式。
class AzMath {
  const AzMath._();

  /// 【所属模块】database/ledger · 资债统计
  /// 【实现功能】从一条主表行 + 其次表行里挑一个用于展示的金额：优先当前估值 / 剩余待还本金 / 总成本 / 金额类列；home 页条目也调它。
  /// 【使用限制】只读；返回值只用于展示与小计，不写回数据库。
  /// 【入参与结果】收 data / main / spec；返回 double。
  /// 【异常与调用方处理】不抛异常；无可用列返回 0。
  static double valueOf(AzData data, AzRecord main, AzTypeSpec spec) {
    final AzRecord? sub = data.subFor(main.id, spec.subTable);
    const List<String> keys = <String>[
      'current_value', 'remaining_principal', 'total_cost', 'installment_amount',
      'loan_amount', 'amount', 'income_amount', 'confirmed_repaid',
    ];
    if (sub != null) {
      for (final String k in keys) {
        if (sub.fields.containsKey(k)) return sub.money(k);
      }
    }
    for (final String k in keys) {
      if (main.fields.containsKey(k)) return main.money(k);
    }
    return 0;
  }

  /// 【所属模块】database/ledger · 资债统计
  /// 【实现功能】按 side（asset / liability）把主表行整理成类型组 → 具体类型 → 条目三级结构，供 home 页「按类型组分类整理」直接渲染。
  /// 【使用限制】只读；顺序取 AzSchema.groups，组内顺序取 members；未知类型编码的行会被跳过。
  /// 【入参与结果】收 data 与 side；返回 List<AzGroupStat>，调用方必须 await 之外无异步；空组也会返回（entryCount=0）。
  /// 【异常与调用方处理】不抛异常；调用方按 entryCount 渲染空态，不得假设每组都有数据。
  static List<AzGroupStat> groupStats(AzData data, String side) {
    final List<AzRecord> all =
        side == 'asset' ? data.assets : data.liabilities;
    final List<AzGroupStat> out = <AzGroupStat>[];
    for (final AzTypeGroup g in AzSchema.groups) {
      if (g.side != side) continue;
      final List<AzTypeBlock> blocks = <AzTypeBlock>[];
      int count = 0;
      double sum = 0;
      for (final AzTypeSpec spec in AzSchema.typesOfGroup(g.key)) {
        final List<AzRecord> rows = <AzRecord>[];
        double blockSum = 0;
        for (final AzRecord r in all) {
          final String code = side == 'asset'
              ? r.text('asset_class')
              : r.text('liability_type');
          if (code != spec.code) continue;
          rows.add(r);
          final double v = valueOf(data, r, spec);
          blockSum += v;
        }
        blocks.add(AzTypeBlock(spec: spec, rows: rows, total: blockSum));
        count += rows.length;
        sum += blockSum;
      }
      out.add(AzGroupStat(
        groupKey: g.key,
        label: g.label,
        side: side,
        typeBlocks: blocks,
        entryCount: count,
        total: sum,
      ));
    }
    return out;
  }

  /// 【所属模块】database/ledger · 资债统计
  /// 【实现功能】资产合计：按类型组汇总的资产侧金额之和（不接账户余额镜像，账户侧由看板单独聚合）。
  /// 【使用限制】只读；不含储蓄账户余额；不含浮动盈亏。
  /// 【入参与结果】收 AzData；返回 double。
  /// 【异常与调用方处理】不抛异常；非法金额按 0 计。
  static double assetsTotal(AzData data) => groupStats(data, 'asset')
      .fold<double>(0, (double p, AzGroupStat g) => p + g.total);

  /// 【所属模块】database/ledger · 资债统计
  /// 【实现功能】负债合计：只取贷款剩余本金与不挂卡分期剩余本金；挂卡分期（mount_creditcard_id 非空）只作明细、不进合计，避免与卡上欠款双计。
  /// 【使用限制】只读；信用卡账户「当前未还」由账户侧看板聚合，本方法不含它。
  /// 【入参与结果】收 AzData；返回 double。
  /// 【异常与调用方处理】不抛异常；次表缺行按 0 计。
  static double liabilitiesTotal(AzData data) {
    double sum = 0;
    for (final AzRecord main in data.liabilities) {
      final AzTypeSpec? spec = data.typOf(main);
      if (spec == null) continue;
      final AzRecord? sub = data.subFor(main.id, spec.subTable);
      if (sub == null) continue;
      if (main.text('liability_type') == '分期' &&
          sub.intOf('mount_creditcard_id') > 0) {
        continue; // 挂卡分期：与账户侧欠款是同一笔钱
      }
      sum += sub.money('remaining_principal');
    }
    return sum;
  }

  /// 【所属模块】database/ledger · 资债统计
  /// 【实现功能】净资产 = 资产合计 − 负债合计，仅作 home 页摘要数字。
  /// 【使用限制】只读；不是会计口径的全库净资产（不含账户余额），展示时必须标注「仅自登记资产」。
  /// 【入参与结果】收 AzData；返回 double，可为负。
  /// 【异常与调用方处理】不抛异常；负值由调用方按「倒欠」文案展示。
  static double netWorth(AzData data) => assetsTotal(data) - liabilitiesTotal(data);
}
