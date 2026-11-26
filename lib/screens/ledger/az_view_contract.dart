import '../../database/ledger/az_math.dart';
import '../../database/ledger/az_record.dart';

/// home 页一次 build 所需的纯数据（页面 ↔ 功能接口契约，不依赖 Controller 内部）。
/// 【所属模块】screens/ledger · 视图契约
/// 【实现功能】把 AzController 快照、当前展示侧、搜索词与类型组汇总打成一份不可变数据，供 home 页渲染。
/// 【使用限制】不可变；不含 BuildContext、不含 Controller；页面不得在这里写库。
/// 【入参与结果】构造收 data / side / keyword / groups；消费方只读字段。
/// 【异常与调用方处理】不抛异常；groups 为空时调用方渲染空态。
class AzViewData {
  const AzViewData({
    required this.data,
    required this.side,
    required this.keyword,
    required this.groups,
  });

  final AzData data;
  final String side;
  final String keyword;
  final List<AzGroupStat> groups;
}

/// home 页动作契约：页面只持回调，不认识具体 Controller 实现。
/// 【所属模块】screens/ledger · 视图契约
/// 【实现功能】登记 home 页的四个动作：切换类型组折叠、新增、打开详情、搜索词变化。
/// 【使用限制】不可变；回调由 LedgerScreen 装配；不得在回调里直接调 DAO。
/// 【入参与结果】构造收四个函数；消费方直接调用。
/// 【异常与调用方处理】回调自身异常由装配方 try/catch；本类不抛异常。
class AzViewActions {
  const AzViewActions({
    required this.toggleGroup,
    required this.add,
    required this.open,
    required this.onKeyword,
  });

  final void Function(String groupKey) toggleGroup;
  final Future<void> Function() add;
  final void Function(int id) open;
  final void Function(String keyword) onKeyword;
}
