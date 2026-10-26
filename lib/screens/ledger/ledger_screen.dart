import 'package:flutter/material.dart';

import '../../models/asset.dart';
import '../../models/liability.dart';
import '../../models/money.dart';
import '../../services/services.dart';
import '../../utils/amount_formatter.dart';
import 'asset_detail_screen.dart';
import 'liability_detail_screen.dart';

/// 资债模块：资产 / 负债 双 Tab
class LedgerScreen extends StatefulWidget {
  const LedgerScreen({super.key});

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<_LedgerData> _future;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _reload();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reload();
  }

  void _reload() {
    _future = _load();
  }

  Future<_LedgerData> _load() async {
    final s = Services.instance;
    final (normal, stocks, funds) = await s.asset.all();
    final liabilities = await s.liability.all();
    final totalAssets = await s.asset.totalAssets();
    final totalDebt = await s.liability.totalDebt();
    final monthlyPayment = await s.liability.monthlyPayment();
    return _LedgerData(
      normal: normal,
      stocks: stocks,
      funds: funds,
      liabilities: liabilities,
      totalAssets: totalAssets,
      totalDebt: totalDebt,
      monthlyPayment: monthlyPayment,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('资债'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '资产'),
            Tab(text: '负债'),
          ],
        ),
      ),
      body: FutureBuilder<_LedgerData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('加载失败'));
          }
          return TabBarView(
            controller: _tabController,
            children: [
              _AssetList(data: snapshot.data!, onChanged: _reload),
              _LiabilityList(data: snapshot.data!, onChanged: _reload),
            ],
          );
        },
      ),
    );
  }
}

class _LedgerData {
  final List<Asset> normal;
  final List<StockAsset> stocks;
  final List<FundAsset> funds;
  final List<Liability> liabilities;
  final Money totalAssets;
  final Money totalDebt;
  final Money monthlyPayment;
  const _LedgerData({
    required this.normal,
    required this.stocks,
    required this.funds,
    required this.liabilities,
    required this.totalAssets,
    required this.totalDebt,
    required this.monthlyPayment,
  });
}

class _AssetList extends StatelessWidget {
  final _LedgerData data;
  final VoidCallback onChanged;
  const _AssetList({required this.data, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final all = <Widget>[
      _SummaryCard(
        title: '资产总金额',
        amount: data.totalAssets,
        subtitle: '${data.normal.length + data.stocks.length + data.funds.length} 项资产',
        color: Colors.green,
      ),
      const SizedBox(height: 12),
    ];

    // 股票
    for (final s in data.stocks) {
      all.add(_StockTile(stock: s, onTap: () => _openStock(context, s)));
    }
    // 基金
    for (final f in data.funds) {
      all.add(_FundTile(fund: f, onTap: () => _openFund(context, f)));
    }
    // 普通资产
    for (final a in data.normal) {
      all.add(_NormalAssetTile(asset: a, onTap: () => _openNormal(context, a)));
    }

    if (all.length == 2) {
      all.add(const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text('暂无资产，点击右上角添加', style: TextStyle(color: Colors.grey))),
      ));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: all,
    );
  }

  void _openNormal(BuildContext context, Asset a) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AssetDetailScreen.normal(asset: a),
    )).then((_) => onChanged());
  }

  void _openStock(BuildContext context, StockAsset s) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AssetDetailScreen.stock(stock: s),
    )).then((_) => onChanged());
  }

  void _openFund(BuildContext context, FundAsset f) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AssetDetailScreen.fund(fund: f),
    )).then((_) => onChanged());
  }
}

class _LiabilityList extends StatelessWidget {
  final _LedgerData data;
  final VoidCallback onChanged;
  const _LiabilityList({required this.data, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SummaryCard(
          title: '负债总金额',
          amount: data.totalDebt,
          subtitle: '月还款合计 ${AmountFormatter.plain(data.monthlyPayment)}',
          color: Colors.red,
        ),
        const SizedBox(height: 12),
        if (data.liabilities.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('暂无负债', style: TextStyle(color: Colors.grey))),
          )
        else
          ...data.liabilities.map((l) => _LiabilityTile(
                liability: l,
                onTap: () => _open(context, l),
              )),
      ],
    );
  }

  void _open(BuildContext context, Liability l) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => LiabilityDetailScreen(liability: l),
    )).then((_) => onChanged());
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final Money amount;
  final String subtitle;
  final MaterialColor color;
  const _SummaryCard({required this.title, required this.amount, required this.subtitle, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color[400]!, color[600]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 8),
          Text(
            AmountFormatter.plain(amount),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}

class _NormalAssetTile extends StatelessWidget {
  final Asset asset;
  final VoidCallback onTap;
  const _NormalAssetTile({required this.asset, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.withOpacity(0.15),
          child: Text(_iconFor(asset.subType), style: const TextStyle(fontSize: 20)),
        ),
        title: Text(asset.name),
        subtitle: Text(asset.subType.label),
        trailing: Text(
          AmountFormatter.plain(asset.amount),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        onTap: onTap,
      ),
    );
  }

  String _iconFor(AssetSubType t) {
    switch (t) {
      case AssetSubType.deposit:
        return '🏦';
      case AssetSubType.interest:
        return '💵';
      case AssetSubType.rent:
        return '🔑';
      case AssetSubType.copyright:
        return '📖';
      case AssetSubType.socialSecurity:
        return '🏥';
      case AssetSubType.housingFund:
        return '🏠';
      case AssetSubType.loanToFriend:
        return '💰';
      case AssetSubType.other:
        return '📦';
    }
  }
}

class _StockTile extends StatelessWidget {
  final StockAsset stock;
  final VoidCallback onTap;
  const _StockTile({required this.stock, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final change = stock.profitLossRatio;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.red.withOpacity(0.15),
          child: const Text('📈', style: TextStyle(fontSize: 20)),
        ),
        title: Text('${stock.name} (${stock.code})'),
        subtitle: Text('持仓 ¥${stock.marketValue.toStringAsFixed(0)}'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '¥${stock.marketValue.toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              '${change >= 0 ? '+' : ''}${(change * 100).toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 11,
                color: change >= 0 ? Colors.red[400] : Colors.green[600],
              ),
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

class _FundTile extends StatelessWidget {
  final FundAsset fund;
  final VoidCallback onTap;
  const _FundTile({required this.fund, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cost = fund.confirmNav * fund.shares;
    final mv = fund.marketValue;
    final change = cost == 0 ? 0.0 : (mv - cost) / cost;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.purple.withOpacity(0.15),
          child: const Text('📊', style: TextStyle(fontSize: 20)),
        ),
        title: Text('${fund.name} (${fund.code})'),
        subtitle: Text('份额 ${fund.shares.toStringAsFixed(0)}'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '¥${mv.toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              '${change >= 0 ? '+' : ''}${(change * 100).toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 11,
                color: change >= 0 ? Colors.red[400] : Colors.green[600],
              ),
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

class _LiabilityTile extends StatelessWidget {
  final Liability liability;
  final VoidCallback onTap;
  const _LiabilityTile({required this.liability, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.red.withOpacity(0.15),
          child: Text(_iconFor(liability.type), style: const TextStyle(fontSize: 20)),
        ),
        title: Text(liability.name),
        subtitle: Text(liability.type.label),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '剩余 ¥${liability.remainingPrincipal.yuan.toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
            ),
            if (liability.repaymentMethod != RepaymentMethod.flexible)
              Text('${liability.repaymentMethod.label}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  String _iconFor(LiabilityType t) {
    switch (t) {
      case LiabilityType.mortgage:
        return '🏠';
      case LiabilityType.carLoan:
        return '🚗';
      case LiabilityType.creditCard:
        return '💳';
      case LiabilityType.consumerLoan:
        return '🏦';
      case LiabilityType.decorationLoan:
        return '🔨';
      case LiabilityType.studentLoan:
        return '🎓';
      case LiabilityType.onlineLoan:
        return '📱';
      case LiabilityType.ecommerceInstallment:
        return '🛒';
      case LiabilityType.rentInstallment:
        return '🏢';
      case LiabilityType.loanFromFriend:
        return '👨‍💼';
      case LiabilityType.other:
        return '📄';
    }
  }
}
