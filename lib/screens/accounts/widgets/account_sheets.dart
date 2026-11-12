import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../database/account/account_record.dart';
import '../../../database/category/category_record.dart' show CategoryKind;
import '../../../service/account_controller.dart';
import '../../../service/category_controller.dart';
import '../../../styles/app_decorations.dart';
import '../../../styles/app_typography.dart';
import '../../../styles/theme_tokens.dart';
import '../../../utils/money_format.dart';
import '../../commons/icons/app_icons.dart';
import '../../commons/sheet/app_sheet_shell.dart';
import '../../commons/sheet/contents/category_sheet_content.dart';
import '../../commons/sheet/contents/confirm_sheet_content.dart';
import '../../commons/sheet/contents/form_sheet_content.dart';
import '../../commons/sheet/parts/sheet_primitives.dart';
import '../../commons/sheet/sheet_form_items.dart';
import '../../commons/sheet/sheet_models.dart';

// ── 模块私有文案 / 校验上限（样式一律走全局令牌）────────────────
const String _kNameHint = '比如：工资卡、微信零钱、公积金';
const int _kNameMaxLength = 12;
const String _kNumberError = '这里要填一个大于 0 的数字';
const String _kTransferTip = '资金在账户之间划转，不产生收支，不影响本月结余。';
const String _kAdjustTip = '差额会记成一条「调整」流水，不产生收支，事后能翻出来对账。';
const String _kBindTip = '不选就是不限用途。绑定只影响记账时的账户下拉，是软提醒，不硬拦。';

/// ══════════════════════════════════════════════════════════════════
/// Sheet 组件使用契约（项目约定）在本模块的落点
/// ══════════════════════════════════════════════════════════════════
/// ① 修改 / 新增 → [FormSheetContent]：
///    新增账户、编辑账户、转账、余额调整、调整额度、修改绑定用途；
/// ③ 确认操作 → [ConfirmSheetContent]：归档、恢复、删除；
/// ⑤ 带图标的类型选择 → [CategorySheetContent]：新增账户先选三大类。
/// ②④⑥（Select / Overview / Operation）本模块当前用不到，不硬凑。
/// **没有新建任何 `XxxAccountSheetContent` 业务包装组件**：所有表单都是
/// 本文件里一次 `items:` 声明，特殊控件只是 `SheetFormCustomItem.builder`
/// 里的私有字段（留在文件下半部分）。
///
/// 每个 form 型 Sheet 都与 `showEditProfileSheet` / `showCategoryEditorSheet`
/// 逐行同构：new 一个 FormSheetController → header 的保存按钮接
/// `controller.submit` → 同一个实例传给 FormSheetContent → await 壳的 show。
/// ══════════════════════════════════════════════════════════════════

/// ⑤ 新增账户第一步：选类型（三个彩色图标格，点击即选）。
Future<AccountKind?> showAccountKindPicker(BuildContext context) =>
    AppSheetShell.show<AccountKind>(
      context,
      header: const SheetHeader(
        title: '添加账户',
        subtitle: '先告诉我这是哪一类账户',
        leading: SheetCloseButton(),
      ),
      child: CategorySheetContent<AccountKind>(
        categories: <SheetCategory<AccountKind>>[
          SheetCategory<AccountKind>(
            value: AccountKind.liquid,
            label: '流动账户',
            icon: AppIcons.accountBank,
          ),
          SheetCategory<AccountKind>(
            value: AccountKind.credit,
            label: '信用卡',
            icon: AppIcons.accountCreditCard,
          ),
          SheetCategory<AccountKind>(
            value: AccountKind.restricted,
            label: '非流动账户',
            icon: AppIcons.locked,
          ),
        ],
        allLabel: '账户类型',
        hint: '点一下就选好了，名字和图标之后都能改。',
      ),
    );

/// ① 新增 / 编辑账户。按 [kind] 决定显示哪些专属字段，
/// **同一个 FormSheetContent**，不是三套表单。
Future<void> showAccountEditorSheet(
  BuildContext context, {
  required AccountController controller,
  required AccountKind kind,
  AccountRecord? account,
}) async {
  final AccountRecord? editing = account;
  final formController = FormSheetController();

  // 分类的可见支出分类，给「绑定用途」多选标签用（3.5）。
  final List<SheetTag<Object>> bindingOptions =
      context.read<CategoryController>().visible(CategoryKind.expense)
          .map((c) => SheetTag<Object>(value: c.id ?? 0, label: c.name))
          .toList(growable: false);

  await AppSheetShell.show<SheetFormValues>(
    context,
    header: SheetHeader(
      title: editing == null ? '新增${kind.label}' : '编辑账户',
      leading: const SheetCancelAction(),
      trailing: SheetTextAction(
        label: '保存',
        emphasized: true,
        onTap: formController.submit,
      ),
    ),
    child: FormSheetContent(
      controller: formController,
      onSubmit: (SheetFormValues values) => _saveAccount(
        controller: controller,
        kind: kind,
        editing: editing,
        values: values,
      ),
      items: <SheetFormItem>[
        SheetFormSingleLineTextItem(
          key: 'name',
          label: '账户名称',
          initialValue: editing?.name ?? '',
          hint: _kNameHint,
          maxLength: _kNameMaxLength,
          showClearButton: true,
          validator: (String value) {
            final String name = value.trim();
            if (name.isEmpty || name.length > _kNameMaxLength) {
              return '名字要填 1 ~ $_kNameMaxLength 个字';
            }
            if (controller.nameExists(name, excludeId: editing?.id)) {
              return '已经有同名账户「$name」了';
            }
            return null;
          },
        ),

        // 账户形态：信用卡固定、其余可在同类里换；
        // 状态由下面的 _TypeField 局部持有并上抛（代码明显的局部状态）。
        SheetFormCustomItem(
          key: 'type',
          label: '具体类型',
          builder: (BuildContext ctx, ValueChanged<Object?> onChanged) =>
              _TypeField(
            initial: editing?.type ?? _defaultType(kind),
            fixed: kind == AccountKind.credit,
            onChanged: onChanged,
          ),
        ),

        SheetFormSingleLineTextItem(
          key: 'note',
          label: '备注',
          initialValue: editing?.note ?? '',
          hint: '比如：工资入账账户 / 存房租',
        ),

        // 3.8：只有开户时允许填初始余额；编辑时不显示这一项，
        // 避免改了期初值破坏「期初 + Σ流水 = 余额」恒等式。
        if (editing == null && kind != AccountKind.credit)
          SheetFormSingleLineTextItem(
            key: 'initial',
            label: '余额',
            initialValue: '0',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (String value) =>
                (double.tryParse(value.trim()) ?? -1) < 0
                    ? '金额只能填正数（10.6）'
                    : null,
          ),

        if (kind == AccountKind.credit) ...<SheetFormItem>[
          SheetFormSingleLineTextItem(
            key: 'limit',
            label: '总额度',
            initialValue: editing?.creditLimit?.toStringAsFixed(0) ?? '',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (String v) =>
                (double.tryParse(v.trim()) ?? 0) <= 0 ? _kNumberError : null,
          ),
          SheetFormSingleLineTextItem(
            key: 'statementDay',
            label: '账单日（每月几号）',
            initialValue: '${editing?.statementDay ?? 5}',
            keyboardType: TextInputType.number,
            validator: (String v) =>
                _dayError(v, '账单日'),
          ),
          SheetFormSingleLineTextItem(
            key: 'dueDay',
            label: '还款日（每月几号）',
            initialValue: '${editing?.dueDay ?? 25}',
            keyboardType: TextInputType.number,
            validator: (String v) => _dayError(v, '还款日'),
          ),
          // 关联还款储蓄卡：3.4「到期时软件知道提醒他从哪张卡扣」。
          SheetFormCustomItem(
            key: 'repayTo',
            label: '用哪张卡还款',
            builder: (BuildContext ctx, ValueChanged<Object?> onChanged) =>
                _AccountPickerField(
              accounts: controller.all
                  .where((AccountRecord r) =>
                      r.kind == AccountKind.liquid &&
                      !r.isDeleted &&
                      !r.archived)
                  .toList(growable: false),
              initialId: editing?.repayAccountId,
              hint: '先不选也行，之后能补',
              onChanged: onChanged,
            ),
          ),
        ],

        if (kind == AccountKind.restricted) ...<SheetFormItem>[
          SheetFormToggleItem(
            key: 'isLiquid',
            label: '算作能自由花的钱',
            initialValue: editing?.isLiquid ?? false,
          ),
          SheetFormTagsItem(
            key: 'bindings',
            label: '绑定可支付类型',
            options: bindingOptions,
            initialSelected: editing == null
                ? const <Object>{}
                : Set<Object>.from(controller.bindingsOf(editing.id!)),
          ),
          const SheetFormNoteItem(
            key: 'bindTip',
            text: _kBindTip,
            align: TextAlign.start,
          ),
        ],
      ],
    ),
  );
}

/// ① 账户间转账（3.7）。
///
/// 【契约 2 的一处明确取舍，请先看这段】
/// 「从哪个账户 / 转到哪个账户」也是内容选择，按契约 2 本该用
/// `SelectSheetContent`。但它是**表单里的一个字段**，再弹一层 Sheet 就成了
/// 设计原则第二条明令禁止的「弹窗里套弹窗」；而契约 1 规定「修改/新增类
/// 操作一律 FormSheetContent」。两条规定在这里冲突，本实现取「整个动作
/// 是一个表单」为主线，把两个选择器做成内联下拉（SheetFormCustomItem），
/// 不新建任何 Sheet 组件。`SelectSheetContent` 仍用于**独立**的内容选择
/// （主题色、排序方式等）。若你要求严格按契约 2，我可以改成「先选账户
/// 再开表单」的两段式，但会多一次弹层。
Future<void> showAccountTransferSheet(
  BuildContext context, {
  required AccountController controller,
  int? fromId,
  int? toId,
  String? title,
}) async {
  final formController = FormSheetController();
  final List<AccountRecord> active = controller.all
      .where((AccountRecord r) => !r.isDeleted && !r.archived)
      .toList(growable: false);

  await AppSheetShell.show<SheetFormValues>(
    context,
    header: SheetHeader(
      title: title ?? '账户转账',
      leading: const SheetCancelAction(),
      trailing: SheetTextAction(
        label: '确认转账',
        emphasized: true,
        onTap: formController.submit,
      ),
    ),
    child: FormSheetContent(
      controller: formController,
      onSubmit: (SheetFormValues values) => _transfer(
        controller: controller,
        values: values,
        fallbackFrom: fromId,
        fallbackTo: toId,
      ),
      items: <SheetFormItem>[
        SheetFormCustomItem(
          key: 'from',
          label: '从哪个账户转出',
          builder: (BuildContext ctx, ValueChanged<Object?> onChanged) =>
              _AccountPickerField(
            // 信用卡不能转出（取现是另一类业务，Controller 也会拦）。
            accounts: active
                .where((AccountRecord r) => r.kind != AccountKind.credit)
                .toList(growable: false),
            initialId: fromId,
            hint: '选一张有余额的账户',
            onChanged: onChanged,
          ),
        ),
        SheetFormCustomItem(
          key: 'to',
          label: '转到哪个账户',
          builder: (BuildContext ctx, ValueChanged<Object?> onChanged) =>
              _AccountPickerField(
            accounts: active,
            initialId: toId,
            hint: '转到信用卡就是「还款」',
            onChanged: onChanged,
          ),
        ),
        SheetFormSingleLineTextItem(
          key: 'amount',
          label: '转多少钱',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (String v) =>
              (double.tryParse(v.trim()) ?? 0) <= 0 ? _kNumberError : null,
        ),
        const SheetFormSingleLineTextItem(
          key: 'note',
          label: '备注',
          hint: '（可选）比如：还信用卡 / 转到微信',
        ),
        const SheetFormNoteItem(
          key: 'transferTip',
          text: _kTransferTip,
          align: TextAlign.start,
        ),
      ],
    ),
  );
}

/// 信用卡「立即还款」= 预置转入账户的转账，不另做一套表单。
Future<void> showAccountRepaySheet(
  BuildContext context, {
  required AccountController controller,
  required AccountRecord creditCard,
}) =>
    showAccountTransferSheet(
      context,
      controller: controller,
      toId: creditCard.id,
      title: '还 ${creditCard.name}',
    );

/// ① 余额调整（3.8：必须填原因、留痕）。
Future<void> showAccountAdjustSheet(
  BuildContext context, {
  required AccountController controller,
  required AccountRecord account,
}) async {
  final formController = FormSheetController();
  await AppSheetShell.show<SheetFormValues>(
    context,
    header: SheetHeader(
      title: '余额调整',
      leading: const SheetCancelAction(),
      trailing: SheetTextAction(
        label: '确认调整',
        emphasized: true,
        onTap: formController.submit,
      ),
    ),
    child: FormSheetContent(
      controller: formController,
      onSubmit: (SheetFormValues values) => controller.adjustBalance(
        accountId: account.id!,
        actualBalance:
            double.tryParse(values.text('actual').trim()) ?? account.balance,
        reason: values.text('reason'),
      ),
      items: <SheetFormItem>[
        SheetFormNoteItem(
          key: 'current',
          text: '当前记录：${MoneyFormat.yuan(account.balance)}',
          align: TextAlign.start,
        ),
        SheetFormSingleLineTextItem(
          key: 'actual',
          label: '实际有多少',
          initialValue: account.balance.toStringAsFixed(0),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (String v) =>
              double.tryParse(v.trim()) == null ? _kNumberError : null,
        ),
        SheetFormMultiLineTextItem(
          key: 'reason',
          label: '为什么调整',
          hint: '比如：银行扣了一笔年费，账上没记',
          minLines: 2,
          maxLines: 2,
          showCounter: false,
          validator: (String v) =>
              v.trim().isEmpty ? '余额调整必须填原因，方便以后对账' : null,
        ),
        const SheetFormNoteItem(
          key: 'adjustTip',
          text: _kAdjustTip,
          align: TextAlign.start,
        ),
      ],
    ),
  );
}

/// ① 调整信用卡额度（只改属性，不写流水）。
Future<void> showAccountCreditLimitSheet(
  BuildContext context, {
  required AccountController controller,
  required AccountRecord account,
}) async {
  final formController = FormSheetController();
  await AppSheetShell.show<SheetFormValues>(
    context,
    header: SheetHeader(
      title: '调整额度',
      leading: const SheetCancelAction(),
      trailing: SheetTextAction(
        label: '保存',
        emphasized: true,
        onTap: formController.submit,
      ),
    ),
    child: FormSheetContent(
      controller: formController,
      onSubmit: (SheetFormValues values) => controller.setCreditLimit(
        account.id!,
        double.tryParse(values.text('limit').trim()) ?? 0,
      ),
      items: <SheetFormItem>[
        SheetFormSingleLineTextItem(
          key: 'limit',
          label: '这张卡最多能花',
          initialValue: account.creditLimit?.toStringAsFixed(0) ?? '',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (String v) =>
              (double.tryParse(v.trim()) ?? 0) <= 0 ? _kNumberError : null,
        ),
        SheetFormNoteItem(
          key: 'used',
          text: '已经用了 ${MoneyFormat.yuan0(account.balance)}，'
              '可用额度会跟着重新算。',
          align: TextAlign.start,
        ),
      ],
    ),
  );
}

/// ① 修改受限账户的绑定用途（3.5）。
Future<void> showAccountBindingsSheet(
  BuildContext context, {
  required AccountController controller,
  required AccountRecord account,
}) async {
  final formController = FormSheetController();
  final List<SheetTag<Object>> options =
      context.read<CategoryController>().visible(CategoryKind.expense)
          .map((c) => SheetTag<Object>(value: c.id ?? 0, label: c.name))
          .toList(growable: false);
  await AppSheetShell.show<SheetFormValues>(
    context,
    header: SheetHeader(
      title: '能用来付哪些支出',
      leading: const SheetCancelAction(),
      trailing: SheetTextAction(
        label: '保存',
        emphasized: true,
        onTap: formController.submit,
      ),
    ),
    child: FormSheetContent(
      controller: formController,
      onSubmit: (SheetFormValues values) => controller.setBindings(
        account.id!,
        values.tags('bindings').whereType<int>().toSet(),
      ),
      items: <SheetFormItem>[
        SheetFormTagsItem(
          key: 'bindings',
          label: '勾选允许从这个账户扣钱的支出类型',
          options: options,
          initialSelected: Set<Object>.from(controller.bindingsOf(account.id!)),
        ),
        const SheetFormNoteItem(
          key: 'bindTip',
          text: _kBindTip,
          align: TextAlign.start,
        ),
      ],
    ),
  );
}

/// ③ 归档 / 恢复账户（3.7）。写库成功才关弹层。
Future<void> showAccountArchiveSheet(
  BuildContext context, {
  required AccountController controller,
  required AccountRecord account,
  required bool archive,
}) async {
  await AppSheetShell.show<void>(
      context,
      header: SheetHeader(
        title: archive ? '归档账户' : '恢复账户',
        leading: const SheetCancelAction(),
      ),
      child: ConfirmSheetContent(
        title: archive ? '把「${account.name}」收起来？' : '把「${account.name}」放回来？',
        description: archive
            ? '归档后不再出现在日常列表，但它记过的每一笔流水都完整保留，随时能恢复。'
            : '恢复后这个账户会重新出现在账户首页，历史流水不变。',
        secondaryLabel: '再想想',
        primaryLabel: archive ? '确认归档' : '确认恢复',
        icon: archive ? AppIcons.archive : AppIcons.unarchive,
        intent: SheetIntent.warning,
        footnote: '这个操作随时可以反悔。',
        onPrimaryAsync: () =>
            controller.setArchived(account.id!, archive),
      ),
    );
}

/// ③ 删除账户（3.8 先数流水再提示；10.7 进回收站 30 天）。
Future<void> showAccountDeleteSheet(
  BuildContext context, {
  required AccountController controller,
  required AccountRecord account,
}) async {
  final int entries = await controller.countEntries(account.id!);
  if (!context.mounted) return;
  await AppSheetShell.show<void>(
    context,
    header: SheetHeader(
      title: '删除账户',
      leading: const SheetCancelAction(),
    ),
    child: ConfirmSheetContent(
      title: '删除「${account.name}」？',
      description: '这个账户下还有 $entries 笔记录。删除后这些记录仍会保留，'
          '但不再关联账户。',
      secondaryLabel: '再想想',
      primaryLabel: '确认删除',
      icon: AppIcons.trash,
      intent: SheetIntent.danger,
      footnote: '会进回收站，30 天内可以恢复。',
      onPrimaryAsync: () => controller.delete(account.id!),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════
// 提交逻辑（本文件唯一的业务动态逻辑）
// ══════════════════════════════════════════════════════════════════

/// 表单值 → Controller.save。工作逻辑：按 key 取值 → 用户没动过的自定义
/// 字段用编辑对象 / 默认形态兜底 → `await controller.save` → 成功才由
/// 公共组件关闭弹层；抛异常则公共组件提示且弹窗保持打开。
Future<void> _saveAccount({
  required AccountController controller,
  required AccountKind kind,
  required AccountRecord? editing,
  required SheetFormValues values,
}) async {
  final AccountType type =
      values.raw('type') as AccountType? ?? editing?.type ?? _defaultType(kind);
  final double initial =
      double.tryParse(values.text('initial').trim()) ?? 0;
  final double? limit = double.tryParse(values.text('limit').trim());
  final int? statementDay = int.tryParse(values.text('statementDay').trim());
  final int? dueDay = int.tryParse(values.text('dueDay').trim());
  final int? repayTo = values.raw('repayTo') as int? ?? editing?.repayAccountId;

  // 3.5：社保 / 公积金「流动资金强制为否且不可改」，即使开关被打开
  // 也在这里兜住，与 DDL 的 CHECK 双保险。
  final bool isLiquid = type.liquidLocked
      ? false
      : (values.contains('isLiquid')
          ? values.flag('isLiquid')
          : kind == AccountKind.liquid);

  await controller.save(
    id: editing?.id,
    kind: kind,
    type: type,
    name: values.text('name'),
    initialBalance: initial,
    creditLimit: kind == AccountKind.credit
        ? (limit ?? editing?.creditLimit)
        : null,
    statementDay: kind == AccountKind.credit
        ? (statementDay ?? editing?.statementDay ?? 5)
        : null,
    dueDay: kind == AccountKind.credit
        ? (dueDay ?? editing?.dueDay ?? 25)
        : null,
    repayAccountId: kind == AccountKind.credit ? repayTo : null,
    note: values.text('note'),
    isLiquid: isLiquid,
    includeInNetWorth: kind != AccountKind.credit
        ? (editing?.includeInNetWorth ?? true)
        : false,
    bindingIds: kind == AccountKind.restricted
        ? values.tags('bindings').whereType<int>().toSet()
        : const <int>{},
  );
}

Future<void> _transfer({
  required AccountController controller,
  required SheetFormValues values,
  required int? fallbackFrom,
  required int? fallbackTo,
}) async {
  final int? from = values.raw('from') as int? ?? fallbackFrom;
  final int? to = values.raw('to') as int? ?? fallbackTo;
  if (from == null || to == null) {
    throw StateError('要先选好转出和转入账户');
  }
  final double amount =
      double.tryParse(values.text('amount').trim()) ?? 0;
  await controller.transfer(
    fromId: from,
    toId: to,
    amount: amount,
    note: values.text('note'),
  );
}

AccountType _defaultType(AccountKind kind) => switch (kind) {
      AccountKind.credit => AccountType.creditCard,
      AccountKind.restricted => AccountType.other,
      AccountKind.liquid => AccountType.bank,
    };

String? _dayError(String raw, String label) {
  final int? day = int.tryParse(raw.trim());
  if (day == null || day < 1 || day > 31) {
    return '$label 要填 1 ~ 31 之间的数字';
  }
  return null;
}

// ══════════════════════════════════════════════════════════════════
// 表单里的私有字段（只服务本文件，样式全走全局令牌）
// ══════════════════════════════════════════════════════════════════

/// 具体类型下拉。
/// 【局部状态工作逻辑】选中值由本组件持有，点选后 `onChanged` 上抛给
/// FormSheetContent 统一收集；外层表单不额外持有 controller。信用卡类型
/// 固定不可改（3.4），下拉直接禁用并显示当前值。
class _TypeField extends StatefulWidget {
  const _TypeField({
    required this.initial,
    required this.fixed,
    required this.onChanged,
  });

  final AccountType initial;
  final bool fixed;
  final ValueChanged<Object?> onChanged;

  @override
  State<_TypeField> createState() => _TypeFieldState();
}

class _TypeFieldState extends State<_TypeField> {
  late AccountType _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initial;
  }

  @override
  Widget build(BuildContext context) => Container(
        decoration: AppDecorations.field(context),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: DropdownButton<AccountType>(
          value: _value,
          isExpanded: true,
          underline: const SizedBox.shrink(),
          style: context.appText.body,
          items: <DropdownMenuItem<AccountType>>[
            for (final AccountType t in AccountType.values)
              DropdownMenuItem<AccountType>(
                value: t,
                child: Text(t.label),
              ),
          ],
          onChanged: widget.fixed
              ? null
              : (AccountType? v) {
                  if (v == null) return;
                  setState(() => _value = v);
                  widget.onChanged(v);
                },
        ),
      );
}

/// 账户下拉（转账 / 关联还款卡共用）。
/// 【局部状态工作逻辑】同上：内部持有选中 id，变化即上抛；没选时允许
/// 为 null，提交环节会给出「要先选好账户」的明确提示，不静默写库。
class _AccountPickerField extends StatefulWidget {
  const _AccountPickerField({
    required this.accounts,
    required this.initialId,
    required this.hint,
    required this.onChanged,
  });

  final List<AccountRecord> accounts;
  final int? initialId;
  final String hint;
  final ValueChanged<Object?> onChanged;

  @override
  State<_AccountPickerField> createState() => _AccountPickerFieldState();
}

class _AccountPickerFieldState extends State<_AccountPickerField> {
  int? _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialId;
  }

  /// DropdownButton 要求 value 必须命中 items 之一，否则 assert 崩。
  /// 归档 / 删除过的关联还款卡可能已不在候选列表里，这里兜成未选。
  int? get _effectiveValue => widget.accounts.any(
        (AccountRecord r) => r.id == _value,
      )
      ? _value
      : null;

  @override
  Widget build(BuildContext context) => Container(
        decoration: AppDecorations.field(context),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: DropdownButton<int>(
          value: _effectiveValue,
          isExpanded: true,
          underline: const SizedBox.shrink(),
          style: context.appText.body,
          hint: Text(widget.hint, style: context.appText.caption),
          items: <DropdownMenuItem<int>>[
            for (final AccountRecord r in widget.accounts)
              if (r.id != null)
                DropdownMenuItem<int>(
                  value: r.id,
                  child: Text(
                    '${r.name} · ${MoneyFormat.yuan0(r.balance)}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
          ],
          onChanged: (int? v) {
            setState(() => _value = v);
            widget.onChanged(v);
          },
        ),
      );
}
