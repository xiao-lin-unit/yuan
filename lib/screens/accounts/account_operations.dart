import 'package:flutter/material.dart';

import '../../models/money.dart';
import '../../models/account.dart';
import '../../services/services.dart';
import '../../utils/amount_formatter.dart';

/// 账户操作：转账 / 余额调整。
/// 转账是资金在账户间移动，不产生收支，不影响本月结余。
class AccountOperationsScreen extends StatefulWidget {
  final int initialTab;
  /// 从账户详情页跳过来时，预填转出账户
  final String? presetFromAccountId;
  const AccountOperationsScreen({super.key, this.initialTab = 0, this.presetFromAccountId});

  @override
  State<AccountOperationsScreen> createState() => _AccountOperationsScreenState();
}

class _AccountOperationsScreenState extends State<AccountOperationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  late Future<List<Account>> _accountsFuture;

  // 转账
  String _transferAmount = '0';
  Account? _from;
  Account? _to;

  // 余额调整
  String _adjustAmount = '0';
  bool _isIncrease = false;
  Account? _adjustAccount;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
    _accountsFuture = Services.instance.account.all();
    _accountsFuture.then((list) {
      if (list.isEmpty) return;
      setState(() {
        if (widget.presetFromAccountId != null) {
          _from = list.firstWhere(
            (a) => a.id == widget.presetFromAccountId,
            orElse: () => list.first,
          );
        } else {
          _from = list.first;
        }
        // 默认转入账户选不同于转出的第一个
        _to = list.firstWhere(
          (a) => a.id != _from!.id,
          orElse: () => list.first,
        );
        _adjustAccount = list.first;
      });
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _onKey(String key, bool isTransfer) {
    setState(() {
      final target = isTransfer ? _transferAmount : _adjustAmount;
      String next;
      if (key == '⌫') {
        next = target.length > 1 ? target.substring(0, target.length - 1) : '0';
      } else if (key == '.') {
        next = target.contains('.') ? target : '$target.';
      } else {
        next = target == '0' ? key : target + key;
      }
      if (isTransfer) {
        _transferAmount = next;
      } else {
        _adjustAmount = next;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('账户操作'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: '转账'),
            Tab(text: '余额调整'),
          ],
        ),
      ),
      body: FutureBuilder<List<Account>>(
        future: _accountsFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return TabBarView(
            controller: _tab,
            children: [
              _buildTransfer(context),
              _buildAdjust(context),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTransfer(BuildContext context) {
    final amt = double.tryParse(_transferAmount) ?? 0;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          color: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              const Text('转账金额', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 8),
              Text(
                AmountFormatter.plain(Money.fromDouble(amt)),
                style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _TransferDirectionRow(
                from: _from?.name ?? '-',
                to: _to?.name ?? '-',
                onTapFrom: () => _pickAccount(true),
                onTapTo: () => _pickAccount(false),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '资金在账户之间划转，不产生收支，不影响本月结余。',
                        style: TextStyle(fontSize: 11, color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
              if (_from != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _from!.category == AccountCategory.credit
                        ? '可用额度 ¥${_from!.availableLimit.toStringAsFixed(2)}'
                        : '当前余额 ¥${_from!.balance.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        _NumberKeyboard(onKey: (k) => _onKey(k, true)),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: () => _doTransfer(context, amt),
                child: const Text('确认转账', style: TextStyle(fontSize: 16)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAdjust(BuildContext context) {
    final amt = double.tryParse(_adjustAmount) ?? 0;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          color: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              const Text('调整后余额', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 8),
              Text(
                AmountFormatter.plain(Money.fromDouble(amt)),
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: _isIncrease ? Colors.green[600] : Colors.red[400],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(value: false, label: Text('设为')),
                          ButtonSegment(value: true, label: Text('设为')),
                        ],
                        selected: {_isIncrease},
                        onSelectionChanged: (s) => setState(() => _isIncrease = s.first),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickAccountForAdjust(),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Expanded(child: Text(
                                _adjustAccount?.name ?? '选择账户',
                                style: const TextStyle(fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              )),
                              const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.blue),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '用于修正账户余额与记录不符的情况。差额会作为调整记录留存，不计入收支。',
                        style: TextStyle(fontSize: 11, color: Colors.blue),
                      ),
                    ),
                  ],
                ),
              ),
              if (_adjustAccount != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    '当前余额 ¥${_adjustAccount!.balance.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        _NumberKeyboard(onKey: (k) => _onKey(k, false)),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: () => _doAdjust(context, amt),
                child: const Text('确认调整', style: TextStyle(fontSize: 16)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _pickAccount(bool isFrom) async {
    final accounts = await _accountsFuture;
    if (!mounted) return;
    final selected = await showModalBottomSheet<Account>(
      context: context,
      builder: (_) => ListView(
        shrinkWrap: true,
        children: [
          for (final a in accounts)
            ListTile(
              title: Text(a.name),
              subtitle: Text(a.type.label),
              onTap: () => Navigator.pop(context, a),
            ),
        ],
      ),
    );
    if (selected == null) return;
    setState(() {
      if (isFrom) {
        _from = selected;
        // 转出变了，确保转入不等于转出
        if (_to?.id == _from!.id) {
          _to = accounts.firstWhere((a) => a.id != _from!.id, orElse: () => accounts.first);
        }
      } else {
        _to = selected;
      }
    });
  }

  void _pickAccountForAdjust() async {
    final accounts = await _accountsFuture;
    if (!mounted) return;
    final selected = await showModalBottomSheet<Account>(
      context: context,
      builder: (_) => ListView(
        shrinkWrap: true,
        children: [
          for (final a in accounts)
            ListTile(
              title: Text(a.name),
              subtitle: Text(a.type.label),
              onTap: () => Navigator.pop(context, a),
            ),
        ],
      ),
    );
    if (selected != null) setState(() => _adjustAccount = selected);
  }

  void _doTransfer(BuildContext context, double amt) async {
    if (_from == null || _to == null) return;
    if (amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入大于零的金额')),
      );
      return;
    }

    final s = Services.instance;
    final result = await s.account.transfer(
      fromId: _from!.id,
      toId: _to!.id,
      amount: Money.fromDouble(amt),
    );

    if (!mounted) return;
    result.fold(
      (from, to) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('转账成功：${_from!.name} → ${_to!.name} ¥${amt.toStringAsFixed(2)}')),
        );
        Navigator.pop(context, true); // 返回 true 通知列表刷新
      },
      (msg) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      },
    );
  }

  void _doAdjust(BuildContext context, double amt) async {
    if (_adjustAccount == null) return;
    if (amt < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('余额不能为负数')),
      );
      return;
    }

    final s = Services.instance;
    final result = await s.account.adjustBalance(
      accountId: _adjustAccount!.id,
      newBalance: amt,
    );

    if (!mounted) return;
    result.fold(
      (updated) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已调整 ${_adjustAccount!.name} 余额为 ¥${amt.toStringAsFixed(2)}')),
        );
        Navigator.pop(context, true);
      },
      (msg) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      },
    );
  }
}

class _TransferDirectionRow extends StatelessWidget {
  final String from, to;
  final VoidCallback onTapFrom;
  final VoidCallback onTapTo;
  const _TransferDirectionRow({
    required this.from,
    required this.to,
    required this.onTapFrom,
    required this.onTapTo,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onTapFrom,
              borderRadius: BorderRadius.circular(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('转出', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(child: Text(from, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                      const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const Icon(Icons.arrow_forward, color: Colors.grey),
          Expanded(
            child: InkWell(
              onTap: onTapTo,
              borderRadius: BorderRadius.circular(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('转入', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                      Expanded(child: Text(to, style: const TextStyle(fontSize: 13), textAlign: TextAlign.right, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NumberKeyboard extends StatelessWidget {
  final ValueChanged<String> onKey;
  const _NumberKeyboard({required this.onKey});

  static const _keys = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['.', '0', '⌫'],
  ];

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        color: Colors.grey[50],
        child: Column(
          children: _keys.map((row) {
            return Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: row.map((k) {
                  return Expanded(
                    child: _KeyButton(keyLabel: k, onTap: () => onKey(k)),
                  );
                }).toList(),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _KeyButton extends StatelessWidget {
  final String keyLabel;
  final VoidCallback onTap;
  const _KeyButton({required this.keyLabel, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Colors.grey[200]!),
            right: BorderSide(color: Colors.grey[200]!),
          ),
        ),
        child: keyLabel == '⌫'
            ? const Icon(Icons.backspace_outlined, size: 20)
            : Text(keyLabel, style: const TextStyle(fontSize: 22)),
      ),
    );
  }
}
