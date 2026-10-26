import 'package:flutter/material.dart';

import '../../models/category.dart';
import '../../models/money.dart';
import '../../models/account.dart';
import '../../services/services.dart';
import '../../utils/amount_formatter.dart';

/// 收支录入页。
/// 只有支出 / 收入两个 Tab。
/// 转账不在收支内，归到"账户"模块操作。
class EntryScreen extends StatefulWidget {
  const EntryScreen({super.key});

  @override
  State<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen> {
  int _tab = 0; // 0 支出 / 1 收入
  String _amount = '0';
  Category? _category;
  Account? _account;
  late Future<List<dynamic>> _initFuture;

  bool get _isExpense => _tab == 0;
  Money get _money => Money.fromDouble(double.tryParse(_amount) ?? 0);

  @override
  void initState() {
    super.initState();
    _initFuture = _init();
  }

  Future<List<dynamic>> _init() async {
    final s = Services.instance;
    final cats = _isExpense
        ? await s.transaction.expenseCategories()
        : await s.transaction.incomeCategories();
    final accounts = await s.account.all();
    // 默认选中第一个分类
    _category = cats.isNotEmpty ? cats.first : null;
    // 默认选中第一个流动资金账户；受限账户不能作为默认
    _account = accounts.firstWhere(
      (a) => a.isLiquid && a.category != AccountCategory.credit,
      orElse: () => accounts.first,
    );
    return [cats, accounts];
  }

  void _switchTab(int tab) {
    if (tab == _tab) return;
    setState(() {
      _tab = tab;
      _amount = '0';
    });
    _reloadCategories();
  }

  void _reloadCategories() async {
    final s = Services.instance;
    final cats = _isExpense
        ? await s.transaction.expenseCategories()
        : await s.transaction.incomeCategories();
    if (!mounted) return;
    setState(() {
      _category = cats.isNotEmpty ? cats.first : null;
    });
  }

  void _onKey(String key) {
    setState(() {
      if (key == '⌫') {
        if (_amount.length > 1) {
          _amount = _amount.substring(0, _amount.length - 1);
        } else {
          _amount = '0';
        }
        if (_amount.contains('.')) {
          _amount = _amount.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
          if (_amount.isEmpty) _amount = '0';
        }
      } else if (key == '.') {
        if (!_amount.contains('.')) _amount += '.';
      } else {
        if (_amount == '0') {
          _amount = key;
        } else if (_amount.contains('.') && _amount.split('.')[1].length >= 2) {
          return;
        } else {
          _amount += key;
        }
      }
    });
  }

  Future<void> _submit() async {
    if (_category == null || _account == null) return;
    final amt = _money;
    if (amt.isZero) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入金额')),
      );
      return;
    }

    final s = Services.instance;
    final result = _isExpense
        ? await s.transaction.addExpense(
            categoryId: _category!.id,
            occurredAt: DateTime.now(),
            amount: amt,
            accountId: _account!.id,
          )
        : await s.transaction.addIncome(
            categoryId: _category!.id,
            occurredAt: DateTime.now(),
            amount: amt,
            accountId: _account!.id,
          );

    if (!mounted) return;
    result.fold(
      (tx) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已记录：${_isExpense ? "支出" : "收入"} ${AmountFormatter.plain(amt)}')),
        );
        setState(() => _amount = '0');
      },
      (msg) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('收支')),
      body: FutureBuilder<List<dynamic>>(
        future: _initFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final cats = snapshot.data![0] as List<Category>;
          final accounts = snapshot.data![1] as List<Account>;
          final effectiveCats = _isExpense ? cats : cats;

          return Column(
            children: [
              // 金额输入区
              Container(
                color: Theme.of(context).colorScheme.surface,
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    Text(
                      _isExpense ? '支出金额' : '收入金额',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AmountFormatter.withSign(_money, showPositiveSign: !_isExpense),
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: _isExpense ? Colors.red[400] : Colors.green[600],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildPickerRow(accounts),
                  ],
                ),
              ),
              const Divider(height: 1),
              // 分类选择
              Expanded(
                child: GridView.count(
                  crossAxisCount: 4,
                  padding: const EdgeInsets.all(16),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.1,
                  children: effectiveCats.map((c) {
                    final selected = _category?.id == c.id;
                    return _CategoryTile(
                      category: c,
                      selected: selected,
                      onTap: () => setState(() => _category = c),
                    );
                  }).toList(),
                ),
              ),
              // 数字键盘
              _NumberKeyboard(onKey: _onKey),
              // 保存按钮
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: _submit,
                      child: Text(_isExpense ? '记 支 出' : '记 收 入', style: const TextStyle(fontSize: 16)),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPickerRow(List<Account> accounts) {
    // 受限账户用途校验提示
    final restricted = _account != null && _account!.isRestricted;
    final allowed = !restricted ||
        (_category != null &&
            _account!.allowedExpenseCategoryIds.contains(_category!.id));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _PickerChip(
                  label: _isExpense ? '支出账户' : '收款账户',
                  value: _account?.name ?? '请选择',
                  warning: restricted && !allowed,
                  onTap: () => _pickAccount(accounts),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PickerChip(
                  label: '分类',
                  value: _category?.name ?? '请选择',
                  onTap: () {},
                ),
              ),
            ],
          ),
          if (restricted && !allowed)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_outlined, size: 14, color: Colors.orange),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${_account!.name} 仅限用于：${_account!.remark ?? "绑定的支出分类"}',
                        style: const TextStyle(fontSize: 11, color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _pickAccount(List<Account> accounts) async {
    final selected = await showModalBottomSheet<Account>(
      context: context,
      builder: (_) => ListView(
        shrinkWrap: true,
        children: [
          for (final a in accounts)
            ListTile(
              leading: a.isRestricted
                  ? const Icon(Icons.lock_outline, color: Colors.purple, size: 20)
                  : null,
              title: Text(a.name),
              subtitle: Text(a.type.label),
              onTap: () => Navigator.pop(context, a),
            ),
        ],
      ),
    );
    if (selected != null) {
      setState(() => _account = selected);
    }
  }
}

class _CategoryTile extends StatelessWidget {
  final Category category;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryTile({required this.category, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: selected ? Theme.of(context).colorScheme.primaryContainer : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: selected
              ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(category.icon ?? '📁', style: const TextStyle(fontSize: 26)),
            const SizedBox(height: 4),
            Text(
              category.name,
              style: TextStyle(
                fontSize: 12,
                color: selected ? Theme.of(context).colorScheme.primary : Colors.grey[800],
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerChip extends StatelessWidget {
  final String label;
  final String value;
  final bool warning;
  final VoidCallback onTap;
  const _PickerChip({required this.label, required this.value, this.warning = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: warning ? Colors.orange : Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
          color: warning ? Colors.orange.withOpacity(0.08) : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      color: warning ? Colors.orange[800] : null,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: warning ? Colors.orange : Colors.grey),
          ],
        ),
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
    return Container(
      color: Colors.grey[50],
      child: Column(
        children: _keys.map((row) {
          return Row(
            children: row.map((k) {
              return Expanded(
                child: _KeyButton(keyLabel: k, onTap: () => onKey(k)),
              );
            }).toList(),
          );
        }).toList(),
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
        height: 52,
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
