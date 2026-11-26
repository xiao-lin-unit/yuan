import 'package:flutter/foundation.dart';

import '../../database/account/account_record.dart';
import '../../database/ledger/az_record.dart';

/// 视图层的**纯数据契约**（两个视图 + 页面骨架共用）。
///
/// 【架构约束（全项目级）】《项目规范与契约.md》契-16 规定功能与页面拆分：
/// 本文件只放不可变数据与回调集合，视图不认识 Controller、不碰 DB、不碰
/// Navigator；换掉整套页面时功能接口不用重写。同一功能只有一个接口见契-17，
/// 跨接口事务一致见契-18（同文 2.4 要-17 ~ 要-19 / 三-D 硬-17 ~ 硬-19）；
/// 本文件及后续新增接口均按要-20 / 硬-20 / 契-19 写全五标签接口注释。
///
/// 【为什么要这一层】原型资债页一屏要显示十几个数字，若把 AzMath 的结果
/// 在页面与两个视图之间来回传十几个参数，稍加一个指标就要改三处签名。
/// 这里只打包「算之前要有的输入」（数据、账户镜像来源、今天、当前筛选、
/// 折叠状态），所有数字仍由视图现场调 AzMath 算 —— 不缓存第二份结果，
/// 也不存在「看到的数和算出来的数不同步」。
///
/// 静态优先：本文件只有不可变数据类与回调集合，没有状态、没有通知。
@immutable
class AzViewData {
  const AzViewData({
    required this.data,
    required this.accounts,
    required this.today,
    this.filter = 'all',
    this.collapsed = const <String, bool>{
      'give': false,
      'take': false,
      'flat': true,
    },
  });

  final AzData data;

  /// 账户页的内存快照（只读）。A1/A2 由它现场聚合，不落库、不缓存。
  final List<AccountRecord> accounts;

  /// 由页面在 build 里取一次，跨天自动刷新；本模块不写快照。
  final DateTime today;

  /// 快筛：all / give / take / A7 / A4（投资 A4/A5/A6）/ stale / cost /
  /// T4 / float / due。
  final String filter;

  /// 三个资产分组的折叠状态。页面持有，视图只按它渲染。
  final Map<String, bool> collapsed;
}

/// 视图里所有「点一下之后做什么」的回调集合。
///
/// 【为什么打包】这些动作全部由页面决定（导航 / 打开哪个 Sheet / 写库），
/// 视图本身不认识 Controller、不碰 Navigator。构造期一次传入，读一眼就
/// 知道整个页面能做什么，不用在 widget 树里层层透传十几个闭包。
@immutable
class AzViewActions {
  const AzViewActions({
    required this.openAsset,
    required this.openDebt,
    required this.openContingent,
    required this.addAsset,
    required this.addDebt,
    required this.addContingent,
    required this.addInsured,
    required this.valuationMode,
    required this.leverage,
    required this.gap,
    required this.payoff,
    required this.goAccounts,
    required this.filterChanged,
    required this.toggleGroup,
  });

  final ValueChanged<AssetRecord> openAsset;
  final ValueChanged<LiabilityRecord> openDebt;
  final ValueChanged<ContingentRecord> openContingent;
  final VoidCallback addAsset;
  final VoidCallback addDebt;
  final VoidCallback addContingent;
  final VoidCallback addInsured;
  final VoidCallback valuationMode;
  final VoidCallback leverage;
  final VoidCallback gap;
  final VoidCallback payoff;
  final VoidCallback goAccounts;
  final ValueChanged<String> filterChanged;
  final ValueChanged<String> toggleGroup;
}
