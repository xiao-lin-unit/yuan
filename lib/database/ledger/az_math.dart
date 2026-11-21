import 'package:flutter/foundation.dart';

import '../../database/account/account_record.dart';
import 'az_record.dart';

/// 资债计算引擎（原型 az.js 的 Dart 版），**全部是纯静态函数**。
///
/// ══════════════════════════════════════════════════════════════════
/// 三条铁律（设计原则第三条「简单，但绝对不能出错」）
/// ══════════════════════════════════════════════════════════════════
/// 1. 不重复计算：A1/A2 来自 accounts 只读聚合，az_assets 里没有它们；
///    信用卡已用额度若已在 az_liabilities 里有对应负债，就不再加一遍。
/// 2. 本金不算消耗：每月出去的钱 = Σ资产自己的持有成本 + Σ债的
///    利息与手续费，**不含月供本金**；还本金只是把现金换成少欠一点。
/// 3. 同屏可核对：每个总数都能拆成逐项；「万一要我还的钱」默认不进
///    「一共欠多少」，也不进「真正属于你的钱」。
///
/// 【为什么单独一层】页面只负责「把数摆出来」，所有算式集中在这里，
/// 单元测试可以直接喂 AzData + 账户列表，不需要起 widget 树。
/// 本文件没有状态、没有通知、没有 IO、没有 DateTime.now()（今天由调用方
/// 传 [today]，便于测试与月末快照复现）。

/// 账户页只读镜像的一行（A1 / A2）。
@immutable
class AzAccountMirror {
  const AzAccountMirror({
    required this.a1,
    required this.label,
    required this.amount,
    required this.accountCount,
  });

  /// true = 卡里和手上的钱；false = 暂时动不了的钱。
  final bool a1;
  final String label;
  final double amount;
  final int accountCount;
}

@immutable
class AzFlow {
  const AzFlow({
    required this.fixed,
    required this.occasional,
    required this.totalIn,
    required this.holdCost,
    required this.interest,
    required this.fee,
    required this.totalOut,
    required this.passiveLeft,
  });

  final double fixed;
  final double occasional;
  final double totalIn;
  final double holdCost;
  final double interest;
  final double fee;
  final double totalOut;
  final double passiveLeft;
}

@immutable
class AzCashLayer {
  const AzCashLayer({
    required this.label,
    required this.amount,
    required this.note,
  });

  final String label;
  final double amount;
  final String note;
}

/// 一项资产「在给你钱 / 在拿你钱 / 不进也不出」。
@immutable
class AzFlowTag {
  const AzFlowTag({required this.good, required this.bad, required this.text});

  final bool good;
  final bool bad;
  final String text;
}

/// 借钱买的东西划不划算（13.5）。
@immutable
class AzLeverage {
  const AzLeverage({
    required this.asset,
    required this.debt,
    required this.steadyIn,
    required this.cost,
    required this.net,
  });

  final AssetRecord asset;
  final LiabilityRecord debt;
  final double steadyIn;
  final double cost;
  final double net;
}

@immutable
class AzDebtStats {
  const AzDebtStats({
    required this.total,
    required this.count,
    required this.monthPay,
    required this.monthCost,
    required this.interestRatio,
    required this.floatDelta,
    required this.worstMonth,
    required this.worstPay,
  });

  final double total;
  final int count;
  final double monthPay;
  final double monthCost;
  final double interestRatio;
  final double floatDelta;
  final String worstMonth;
  final double worstPay;
}

/// 逐月缺口表的一行（7.9 / 13.6）。
@immutable
class AzGapRow {
  const AzGapRow({
    required this.month,
    required this.pay,
    required this.available,
    required this.gap,
  });

  final String month;
  final double pay;
  final double available;
  final double gap;
}

/// 提前还款四件事（7.10）。
@immutable
class AzPrepay {
  const AzPrepay({
    required this.saveInterest,
    required this.penalty,
    required this.netSave,
    required this.cashAfter,
    required this.realRate,
  });

  final double saveInterest;
  final double penalty;
  final double netSave;
  final double cashAfter;
  final double realRate;
}

@immutable
class AzClassSum {
  const AzClassSum({
    required this.code,
    required this.label,
    required this.count,
    required this.sum,
  });

  final String code;
  final String label;
  final int count;
  final double sum;
}

@immutable
class AzTradeSummary {
  const AzTradeSummary({
    required this.realized,
    required this.holdingQuantity,
    required this.holdingCost,
    required this.buyTotal,
    required this.sellTotal,
  });

  final double realized;
  final double holdingQuantity;
  final double holdingCost;
  final double buyTotal;
  final double sellTotal;
}

abstract final class AzMath {
  /// 这一项东西「现在算多少钱」（6.4）。counted=false 的东西完全不进总账。
  /// 口径为 latest 且用户确实填过价才用最新价，否则一直按买入价（保守）。
  static double assetValueOf(AssetRecord a, ValuationMode mode) {
    if (!a.counted) return 0;
    if (mode == ValuationMode.latest && a.latestValue != null) {
      return a.latestValue!;
    }
    return a.cost;
  }

  /// A1/A2 只读镜像。账户是唯一写入点；归档与软删的账户不再参与总账，
  /// 镜像标「已断开」（6.2），这里直接不返回它，避免静默沿用旧数。
  static List<AzAccountMirror> mirrors(List<AccountRecord> accounts) {
    double a1 = 0;
    double a2 = 0;
    int n1 = 0;
    int n2 = 0;
    for (final AccountRecord a in accounts) {
      if (a.isDeleted || a.archived) continue;
      if (a.kind == AccountKind.liquid && a.isLiquid) {
        a1 += a.balance;
        n1++;
      } else if (a.kind == AccountKind.restricted && a.includeInNetWorth) {
        a2 += a.balance;
        n2++;
      }
    }
    return <AzAccountMirror>[
      AzAccountMirror(
        a1: true,
        label: '卡里的钱',
        amount: a1,
        accountCount: n1,
      ),
      AzAccountMirror(
        a1: false,
        label: '动不了',
        amount: a2,
        accountCount: n2,
      ),
    ];
  }

  /// 家底账右侧的「除了钱以外的东西」= A3~A11 自登记资产。
  static double selfAssets(AzData d) => d.activeAssets.fold<double>(
        0,
        (double s, AssetRecord a) =>
            s + assetValueOf(a, d.preferences.valuationMode),
      );

  /// 没有被负债表登记过的信用卡，其已用额度要作为欠款兜底。
  /// 【为什么必须去重】3.4 规定建信用卡时自动建一条对应负债，若两边都
  /// 加进去，同一笔欠款会算两遍（附录 A 明令禁止）。
  static double unlinkedCreditUsed(
    AzData d,
    List<AccountRecord> accounts,
  ) {
    final Set<int> linked = <int>{
      for (final LiabilityRecord x in d.activeLiabilities)
        if (x.accountId != null) x.accountId!,
    };
    double sum = 0;
    for (final AccountRecord a in accounts) {
      if (a.isDeleted || a.archived) continue;
      if (a.kind != AccountKind.credit) continue;
      if (a.id != null && linked.contains(a.id)) continue;
      sum += a.balance;
    }
    return sum;
  }

  static double debtsTotal(AzData d, List<AccountRecord> accounts) {
    final double fromRows = d.activeLiabilities.fold<double>(
      0,
      (double s, LiabilityRecord x) => s + x.principal,
    );
    return fromRows + unlinkedCreditUsed(d, accounts);
  }

  static double accountTotal(List<AzAccountMirror> mirrors) =>
      mirrors.fold<double>(0, (double s, AzAccountMirror m) => s + m.amount);

  /// 真正属于你的钱 = 账户余额合计 + 非账户形态资产 − 负债合计（10.9 一次减完）。
  static double netWorth(AzData d, List<AccountRecord> accounts) =>
      accountTotal(mirrors(accounts)) +
      selfAssets(d) -
      debtsTotal(d, accounts);

  /// 流向账：每月自动进来 / 出去。本金不算消耗，「每月出」只填资产自己的
  /// 持有成本，借款利息与费用由负债侧统一给（2.1 关键边界）。
  static AzFlow flow(AzData d) {
    double fixed = 0;
    double occ = 0;
    double holdCost = 0;
    for (final AssetRecord a in d.activeAssets) {
      // 投资（A4/A5/A6）不按固定收付记账：估值走买入批次，分红是已发生
      // 的事实，不是「每月都有」的进账。老记录里若曾误填 monthly_in /
      // monthly_out，这里一律不参与流向账，避免被当成稳定收入（6.4/6.5）。
      if (a.assetClass.isInvestment) continue;
      if (a.stability == AzStability.fixed) {
        fixed += a.monthlyIn;
      } else if (a.monthlyIn > 0) {
        occ += a.monthlyIn;
      }
      holdCost += a.monthlyOut;
    }
    double interest = 0;
    double fee = 0;
    for (final LiabilityRecord x in d.activeLiabilities) {
      interest += x.monthlyInterest;
      fee += x.monthlyFee;
    }
    final double totalOut = holdCost + interest + fee;
    return AzFlow(
      fixed: fixed,
      occasional: occ,
      totalIn: fixed + occ,
      holdCost: holdCost,
      interest: interest,
      fee: fee,
      totalOut: totalOut,
      // 13.2：只取「每月都有」的进账，分母是每月必须花的钱，不是月收入。
      passiveLeft: fixed - totalOut,
    );
  }

  /// 「真要用钱，能拿出多少」按多久能变成现金分四层（6.8 / 13.6）。
  static List<AzCashLayer> cashLayers(
    AzData d,
    List<AccountRecord> accounts,
  ) {
    final List<AzAccountMirror> ms = mirrors(accounts);
    final List<AzCashLayer> layers = <AzCashLayer>[
      const AzCashLayer(label: '随时取', amount: 0, note: '现金与易变现'),
      const AzCashLayer(label: '数日', amount: 0, note: '基金、金条'),
      const AzCashLayer(label: '数月', amount: 0, note: '房车、借出款'),
      const AzCashLayer(label: '动不了', amount: 0, note: '公积金、医保'),
    ];
    final List<double> values = <double>[0, 0, 0, 0];
    values[0] += ms.isEmpty ? 0 : ms[0].amount;
    values[3] += ms.length < 2 ? 0 : ms[1].amount;
    for (final AssetRecord a in d.activeAssets) {
      final double v = assetValueOf(a, d.preferences.valuationMode);
      final int i = a.liquidity.dbValue > 3 ? 3 : a.liquidity.dbValue;
      values[i] += v;
    }
    return <AzCashLayer>[
      for (int i = 0; i < layers.length; i++)
        AzCashLayer(
          label: layers[i].label,
          amount: values[i],
          note: layers[i].note,
        ),
    ];
  }

  /// 真要全变成现金要扣多少（13.7）。固定标「估算」。
  static double exitCost(AzData d) => d.activeAssets.fold<double>(
        0,
        (double s, AssetRecord a) => s + (a.counted ? a.exitCost : 0),
      );

  /// 实际一年要付多少（7.5）：月费率口径按**实际占用本金**折算。
  /// 「免息分期」月费率 0.6% 看着 7.2%，因每期都在还本金，实际约 13.8%。
  /// 银行算法各不相同，界面一律标「估算，以账单为准」。
  static double realAnnualRate(LiabilityRecord d) {
    if (d.rateType == RateType.given) return d.rate;
    if (d.nominalRate != null && d.monthlyFee > 0 && d.principal > 0) {
      final int n = d.totalTerms == 0 ? 12 : d.totalTerms;
      final double avgUsed = d.principal * (n + 1) / (2 * n);
      final double totalFee = d.monthlyFee * n;
      final double years = n / 12;
      if (avgUsed > 0 && years > 0) return totalFee / avgUsed / years;
    }
    return d.rate;
  }

  /// 这笔债关联的资产每月利息与费用（资产卡片要把它算进「拿你钱」）。
  static double linkCostOf(AssetRecord a, List<LiabilityRecord> debts) {
    if (a.linkDebtId == null) return 0;
    for (final LiabilityRecord d in debts) {
      if (d.id == a.linkDebtId) return d.monthlyCost;
    }
    return 0;
  }

  static AzFlowTag flowTagOf(AssetRecord a, List<LiabilityRecord> debts) {
    // 投资不进「在给你钱 / 在拿你钱」两组：按买入价记，赚亏只在卖出时
    // 结算（6.4/6.5），没有每月净流向；老记录的月入值也不参与判断。
    if (a.assetClass.isInvestment) {
      return const AzFlowTag(good: false, bad: false, text: '按买卖算');
    }
    final double steady = a.stability == AzStability.fixed ? a.monthlyIn : 0;
    final double out = a.monthlyOut + linkCostOf(a, debts);
    final double net = steady - out;
    if (net > 0) {
      return AzFlowTag(good: true, bad: false, text: '每月给你 +${net.toStringAsFixed(0)} 元');
    }
    if (net < 0) {
      return AzFlowTag(good: false, bad: true, text: '每月拿走 ${(-net).toStringAsFixed(0)} 元');
    }
    return const AzFlowTag(good: false, bad: false, text: '不进也不出');
  }

  /// 借钱买的东西划不划算（13.5）：只取标了「每月都有」的进账。
  static AzLeverage? leverageOf(LiabilityRecord d, List<AssetRecord> assets) {
    if (d.linkAssetId == null) return null;
    AssetRecord? found;
    for (final AssetRecord a in assets) {
      if (a.id == d.linkAssetId) {
        found = a;
        break;
      }
    }
    if (found == null) return null;
    // 投资没有「稳稳每月都有」的分红，借钱买投资不按固定进账算划算与否。
    final double steady = found.assetClass.isInvestment
        ? 0
        : (found.stability == AzStability.fixed ? found.monthlyIn : 0);
    return AzLeverage(
      asset: found,
      debt: d,
      steadyIn: steady,
      cost: d.monthlyCost,
      net: steady - d.monthlyCost,
    );
  }

  static double monthPay(AzData d) => d.activeLiabilities.fold<double>(
        0,
        (double s, LiabilityRecord x) => s + x.monthlyPay,
      );

  /// 7.9 负债统计（只加总已记录数据）。月收入占比 / 偿债能力比值依赖
  /// 情境设计（8.2 / 13.2）的参数，资债不计算，也不显示「—」占位。
  static AzDebtStats debtStats(AzData d, List<AzGapRow> gaps) {
    final List<LiabilityRecord> debts = d.activeLiabilities;
    final double total = debts.fold<double>(
      0,
      (double s, LiabilityRecord x) => s + x.principal,
    );
    final double pay = monthPay(d);
    final AzFlow f = flow(d);
    final double cost = f.interest + f.fee;
    // 「利率涨 1 个点」只作用于会变的那些（7.6 / 8.2.2）。
    final double floatDelta = debts
            .where((LiabilityRecord x) => x.rateType == RateType.float)
            .fold<double>(0, (double s, LiabilityRecord x) => s + x.principal) *
        0.01 /
        12;
    AzGapRow worst = gaps.isEmpty
        ? const AzGapRow(month: '—', pay: 0, available: 0, gap: 0)
        : gaps.first;
    for (final AzGapRow g in gaps) {
      if (g.gap > worst.gap) worst = g;
    }
    return AzDebtStats(
      total: total,
      count: debts.length,
      monthPay: pay,
      monthCost: cost,
      interestRatio: pay == 0 ? 0 : cost / pay,
      floatDelta: floatDelta,
      worstMonth: worst.month,
      worstPay: worst.pay,
    );
  }

  /// 逐月缺口表（13.6）：别拿今天的钱去除明年的债。
  /// 【工作逻辑，4 步】
  ///   ① 按「多久能变成现金」把资产排到能到手的月份：随时/几天 → 第 1 月，
  ///      几个月 → 第 3 月，很难 → 第 6 月，动不了 → 不排；先扣变现摩擦；
  ///   ② 每月应还 = 剩余期数还覆盖得到的所有负债月供之和；
  ///   ③ 到那个月能拿出的钱 = 已排期的钱 − 之前各月已用掉的正缺口；
  ///   ④ gap = 应还 − 能拿出，正数标红。这是估算，不预测收入。
  /// 【边界】只用已记录的资产变现期与月供，不读情境设计参数。
  static List<AzGapRow> gapTable(
    AzData d,
    List<AccountRecord> accounts,
    DateTime today,
  ) {
    final List<AzCashLayer> layers = cashLayers(d, accounts);
    double atOnce = layers[0].amount + layers[1].amount - exitCost(d);
    if (atOnce < 0) atOnce = 0;
    final double atMonth3 = layers[2].amount;
    final double atMonth6 = layers[3].amount;
    final List<AzGapRow> rows = <AzGapRow>[];
    double used = 0;
    for (int m = 1; m <= 12; m++) {
      double pay = 0;
      for (final LiabilityRecord x in d.activeLiabilities) {
        if (x.monthlyPay > 0 && m <= x.leftTerms) pay += x.monthlyPay;
      }
      double released = atOnce;
      if (m >= 3) released += atMonth3;
      if (m >= 6) released += atMonth6;
      final double available = released - used;
      final double gap = pay - available;
      if (gap > 0) used += gap;
      final DateTime dt = DateTime(today.year, today.month + m, 1);
      final String month =
          '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
      rows.add(
        AzGapRow(month: month, pay: pay, available: available, gap: gap),
      );
    }
    return rows;
  }

  /// 提前还款违约金（7.4）：按这笔债自己的章程，不冒充银行。
  static double prepayPenalty(LiabilityRecord d, double amount) {
    if (d.prepayPenaltyRate > 0) return amount * d.prepayPenaltyRate;
    if (d.monthlyFee > 0 && d.totalTerms > 0) {
      final int left = d.leftTerms < 6 ? d.leftTerms : 6;
      return d.monthlyFee * left;
    }
    return 0;
  }

  /// 提前还款（7.10）。省息是线性近似并乘 0.72 贴近等额本息重算，
  /// 界面必须标「估算，以账单为准」。「还完还能撑几个月」是情境设计的
  /// 推算（13.2），资债不算、不存、不展示。
  static AzPrepay prepayPlan(
    AzData d,
    List<AccountRecord> accounts,
    LiabilityRecord debt,
    double amount,
  ) {
    final double realRate = realAnnualRate(debt);
    final double r = realRate / 12;
    final int left = debt.leftTerms < 1 ? 1 : debt.leftTerms;
    final double saveInterest = amount * r * left * 0.72;
    final double penalty = prepayPenalty(debt, amount);
    final double cashAfter = cashLayers(d, accounts)[0].amount - amount;
    return AzPrepay(
      saveInterest: saveInterest,
      penalty: penalty,
      netSave: saveInterest - penalty,
      cashAfter: cashAfter,
      realRate: realRate,
    );
  }

  /// 「先还哪一笔」默认按实际一年要付多少从高到低（7.10）。
  static List<LiabilityRecord> payoffOrder(AzData d) {
    final List<LiabilityRecord> list = d.activeLiabilities
        .where((LiabilityRecord x) => x.principal > 0)
        .toList();
    list.sort((LiabilityRecord a, LiabilityRecord b) =>
        realAnnualRate(b).compareTo(realAnnualRate(a)));
    return list;
  }

  /// 未来 N 天到期的（7.9「快到期的」）。
  static List<LiabilityRecord> dueSoon(
    AzData d,
    DateTime today,
    int days,
  ) =>
      d.activeLiabilities.where((LiabilityRecord x) {
        if (x.endDate == null) return false;
        return x.endDate!.difference(today).inDays <= days;
      }).toList();

  /// 超过 staleDays 没更新过价的（6.4 / 6.9）。
  static List<AssetRecord> staleAssets(AzData d, DateTime today) =>
      d.activeAssets.where((AssetRecord a) {
        if (a.valuedAt == null) return false;
        return today.difference(a.valuedAt!).inDays > d.preferences.staleDays;
      }).toList();

  /// 资产汇总：按大类，每一项都能和上面的卡片对上（同屏可核对）。
  static List<AzClassSum> byClass(AzData d) {
    final Map<String, List<double>> acc = <String, List<double>>{};
    for (final AssetRecord a in d.activeAssets) {
      if (!a.counted) continue;
      final List<double> v = acc.putIfAbsent(
        a.assetClass.code,
        () => <double>[0, 0],
      );
      v[0] += 1;
      v[1] += assetValueOf(a, d.preferences.valuationMode);
    }
    final List<AzClassSum> out = <AzClassSum>[];
    for (final AssetClass c in AssetClass.values) {
      final List<double>? v = acc[c.code];
      if (v != null) {
        out.add(
          AzClassSum(
            code: c.code,
            label: c.label,
            count: v[0].toInt(),
            sum: v[1],
          ),
        );
      }
    }
    return out;
  }

  /// 负债汇总：按类型，金额大的在前。
  static List<AzClassSum> byType(AzData d) {
    final Map<String, List<double>> acc = <String, List<double>>{};
    for (final LiabilityRecord x in d.activeLiabilities) {
      final List<double> v = acc.putIfAbsent(
        x.type.dbValue,
        () => <double>[0, 0],
      );
      v[0] += 1;
      v[1] += x.principal;
    }
    final List<AzClassSum> out = <AzClassSum>[];
    for (final LiabilityType t in LiabilityType.values) {
      final List<double>? v = acc[t.dbValue];
      if (v != null) {
        out.add(
          AzClassSum(
            code: t.dbValue,
            label: t.label,
            count: v[0].toInt(),
            sum: v[1],
          ),
        );
      }
    }
    out.sort((AzClassSum a, AzClassSum b) => b.sum.compareTo(a.sum));
    return out;
  }

  /// 股票/基金详情页三块（6.5.3）：移动加权平均成本，卖出时结算落袋赚亏。
  /// 【边界】卖出数量超过持仓时按持仓量结算，不允许出现负持仓（6.5.4）；
  /// 本函数只读不改库，真正的写入由 AzWriteController.recordTrade 完成。
  static AzTradeSummary tradeSummary(List<AssetTradeRecord> rows) {
    final List<AssetTradeRecord> sorted = rows.toList()
      ..sort((AssetTradeRecord a, AssetTradeRecord b) =>
          a.occurredAt.compareTo(b.occurredAt));
    double quantity = 0;
    double cost = 0;
    double realized = 0;
    double buyTotal = 0;
    double sellTotal = 0;
    for (final AssetTradeRecord t in sorted) {
      if (t.direction == TradeDirection.buy) {
        quantity += t.quantity;
        cost += t.amount; // 单价×数量 + 费用，已含在 amount 里
        buyTotal += t.amount;
      } else {
        final double sellQty = t.quantity > quantity ? quantity : t.quantity;
        final double avg = quantity == 0 ? 0 : cost / quantity;
        final double basis = avg * sellQty;
        quantity -= sellQty;
        cost -= basis;
        final double pnl = t.amount - basis;
        realized += pnl;
        sellTotal += t.amount;
      }
    }
    return AzTradeSummary(
      realized: realized,
      holdingQuantity: quantity,
      holdingCost: cost,
      buyTotal: buyTotal,
      sellTotal: sellTotal,
    );
  }
}
