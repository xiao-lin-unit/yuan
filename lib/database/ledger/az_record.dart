import 'az_schema.dart';

/// 一行通用记录：32 张表统一用 Map 承载，不做 32 个强类型类。
///
/// 金额列在 DDL 里是 TEXT 十进制字符串，[money] 统一按 double 解析供统计用；
/// 写库时仍写 String，避免二进制浮点误差。
/// 【所属模块】database/ledger · 资债记录
/// 【实现功能】包装一张资债表里的一行，提供 id / 文本 / 金额 / 整数 / 布尔的统一读取。
/// 【使用限制】不可变包装但内部 Map 引用不复制；table 必须来自 AzSchema.allTables；不得用本类写库，写库走 AzDao。
/// 【入参与结果】构造收 table 与 fields（sqflite query 的原始 Map）；text / money / intOf / boolOf 收列名，返回解析后的值，缺失返回默认值。
/// 【异常与调用方处理】不抛异常；金额格式非法时 money 返回 0，调用方需自行在录入层校验字符串格式，不得把 0 当合法金额写入。
class AzRecord {
  const AzRecord(this.table, this.fields);

  final String table;
  final Map<String, Object?> fields;

  /// 【所属模块】database/ledger · 资债记录
  /// 【实现功能】取主键 id，缺失返回 -1。
  /// 【使用限制】只读派生；-1 表示无效行，调用方必须判 -1 后再跳转详情。
  /// 【入参与结果】无入参；返回 int。
  /// 【异常与调用方处理】不抛异常；调用方需自行处理 -1。
  int get id => (fields['id'] as num?)?.toInt() ?? -1;

  /// 【所属模块】database/ledger · 资债记录
  /// 【实现功能】按列名取字符串值，null 或空统一返回 ''。
  /// 【使用限制】只读；不用于解析金额。
  /// 【入参与结果】收 key；返回 String。
  /// 【异常与调用方处理】不抛异常；调用方不得拿返回值拼 SQL。
  String text(String key) => (fields[key] ?? '').toString();

  /// 【所属模块】database/ledger · 资债记录
  /// 【实现功能】把 TEXT / INTEGER / REAL 金额列解析成 double，非法或空返回 0。
  /// 【使用限制】只供统计与展示；写库必须用原始字符串，禁止把 double 回写 TEXT 列。
  /// 【入参与结果】收 key；返回 double。
  /// 【异常与调用方处理】不抛异常；解析失败静默返回 0，调用方需保证录入层已校验金额格式。
  double money(String key) {
    final Object? v = fields[key];
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().trim()) ?? 0;
  }

  /// 【所属模块】database/ledger · 资债记录
  /// 【实现功能】按列名取整数，缺失或非法返回 0。
  /// 【使用限制】只读；时间戳列用本方法读取后需自行换算 DateTime。
  /// 【入参与结果】收 key；返回 int。
  /// 【异常与调用方处理】不抛异常；调用方判 0 后按「未填」处理。
  int intOf(String key) => (fields[key] as num?)?.toInt() ?? 0;

  /// 【所属模块】database/ledger · 资债记录
  /// 【实现功能】把 0/1 整数列解析成 bool。
  /// 【使用限制】只读；仅用于 has_collateral / archived / manual_adjusted 一类列。
  /// 【入参与结果】收 key；返回 bool。
  /// 【异常与调用方处理】不抛异常；非法值按 false 处理。
  bool boolOf(String key) => intOf(key) == 1;
}

/// 一次读库出来的全部资债数据（主表 + 所有次表 / 附表）。
/// 【所属模块】database/ledger · 资债记录
/// 【实现功能】持有 32 张表的当前快照：两张主表的有效行 + 按表名分组的其余表行，供 Controller 与 home 页聚合。
/// 【使用限制】不可变快照，不监听数据库；软删过滤只在主表做；刷新必须由 AzController.load 整体替换，不得就地改 List。
/// 【入参与结果】构造收 assets / liabilities / rowsByTable / today；subFor / rowsOf / typOf 按 id 或表名查询，缺失返回 null / 空列表。
/// 【异常与调用方处理】不抛异常；调用方必须判空后再渲染详情，不能假设每条主表行都有次表行。
class AzData {
  const AzData({
    required this.assets,
    required this.liabilities,
    required this.rowsByTable,
    required this.today,
  });

  final List<AzRecord> assets;
  final List<AzRecord> liabilities;
  final Map<String, List<AzRecord>> rowsByTable;
  final DateTime today;

  /// 【所属模块】database/ledger · 资债记录
  /// 【实现功能】空快照常量，AzController 未加载完成前使用，避免页面判 null。
  /// 【使用限制】只读常量；不得当作「已加载」状态使用。
  /// 【入参与结果】无入参；返回 AzData。
  /// 【异常与调用方处理】不抛异常；调用方仍需自行展示加载态。
  static AzData empty(DateTime now) => AzData(
        assets: const <AzRecord>[],
        liabilities: const <AzRecord>[],
        rowsByTable: const <String, List<AzRecord>>{},
        today: now,
      );

  /// 【所属模块】database/ledger · 资债记录
  /// 【实现功能】按表名取该表全部行，未登记或无数据返回空列表。
  /// 【使用限制】只读；返回值不可修改。
  /// 【入参与结果】收 table；返回 List<AzRecord>。
  /// 【异常与调用方处理】不抛异常；调用方判 isEmpty 后展示空态。
  List<AzRecord> rowsOf(String table) =>
      rowsByTable[table] ?? const <AzRecord>[];

  /// 【所属模块】database/ledger · 资债记录
  /// 【实现功能】按主表 id 找对应次表的唯一一行（asset_id / liability_id 关联）。
  /// 【使用限制】只读；次表与主表 1:1，找不到返回 null。
  /// 【入参与结果】收 mainId 与 subTable；返回 AzRecord?。
  /// 【异常与调用方处理】不抛异常；调用方判空后按「尚未录次表」展示。
  AzRecord? subFor(int mainId, String subTable) {
    final String fk = subTable.startsWith('az_asset') ? 'asset_id' : 'liability_id';
    for (final AzRecord r in rowsOf(subTable)) {
      if (r.intOf(fk) == mainId) return r;
    }
    return null;
  }

  /// 【所属模块】database/ledger · 资债记录
  /// 【实现功能】按主表行反查它属于哪个 AzTypeSpec（读 asset_class / liability_type）。
  /// 【使用限制】只读；未登记编码返回 null。
  /// 【入参与结果】收一条主表 AzRecord；返回 AzTypeSpec?。
  /// 【异常与调用方处理】不抛异常；调用方判空后跳过该行，不得渲染成未知类型。
  AzTypeSpec? typOf(AzRecord main) {
    final String code = main.table == 'az_assets'
        ? main.text('asset_class')
        : main.text('liability_type');
    return AzSchema.byCode(code);
  }
}
