import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../database/account/account_record.dart';
import '../../../database/category/category_record.dart' show CategoryKind;
import '../../../service/account_controller.dart';
import '../../../service/category_controller.dart';
import '../../../service/credit_card_account_controller.dart';
import '../../../service/savings_account_controller.dart';
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
const String _kNameHint = '例如：工资卡、微信零钱、公积金';
const int _kNameMaxLength = 12;
const String _kNumberError = '请输入大于 0 的数值';
const String _kTransferTip =
    '资金在储蓄类账户之间划转，不计入收支，不影响本期结余。信用卡还款请使用还款功能。';
const String _kAdjustTip =
    '差额将记录为一条「调整」流水，不计入收支，可随时追溯核对。';
const String _kBindTip =
    '未选择表示不限制用途。绑定仅影响记账时的账户列表，为提示性约束，不作强制拦截。';
const String _kCreditRuleTip =
    '信用卡记的是已用额度：消费记为出账（欠款增加），还款记为入账（欠款减少）。';
const String _kRepayTip =
    '还款同时减少来源账户余额与信用卡已用额度，不计入收支。';
const String _kCreditAdjustTip =
    '差额记为一条「调整」流水；额度不足或账单未同步时使用。';

/// ══════════════════════════════════════════════════════════════════
/// Sheet 组件使用契约（项目约定）在本模块的落点
/// ══════════════════════════════════════════════════════════════════
/// ① 修改 / 新增 → [FormSheetContent]：新增/编辑账户、转账、还款、
///    消费出账、余额调整、已用额度校准、调整额度、修改绑定用途；
/// ③ 确认操作 → [ConfirmSheetContent]：归档、恢复、删除；
/// ⑤ 带图标的类型选择 → [CategorySheetContent]：新增账户先选三大类。
/// **没有新建任何 `XxxAccountSheetContent` 业务包装组件**：所有表单都是
/// 本文件里一次 `items:` 声明，特殊控件只是 `SheetFormCustomItem.builder`
/// 里的私有字段（留在文件下半部分）。
///
/// 每个 form 型 Sheet 都与 `showEditProfileSheet` 逐行同构：new 一个
/// FormSheetController → header 的保存按钮接 `controller.submit` →
/// 同一个实例传给 FormSheetContent → await 壳的 show。
///
/// 【两个业务处理器的分派，本轮的硬规则】
///   · 流动资金 / 其他资金账户 → SavingsAccountController；
///   · 信用卡                 → CreditCardAccountController；
///   · 查询 / 归档 / 删除     → AccountController（共享账本）。
/// 储蓄类与信用卡的表单**不共用提交逻辑**：还款有独立表单，绝不把
/// `showAccountRepaySheet` 转发成 `showAccountTransferSheet`。
/// ══════════════════════════════════════════════════════════════════

/// ⑤ 新增账户第一步：选类型（三个彩色图标格，点击即选）。
Future<AccountKind?> showAccountKindPicker(BuildContext context) =>
    AppSheetShell.show<AccountKind>(
      context,
      header: const SheetHeader(
        title: '新增账户',
        subtitle: '请选择账户类别',
        centered: true,
        leading: SheetCloseButton(),
      ),
      child: CategorySheetContent<AccountKind>(
        categories: <SheetCategory<AccountKind>>[
          SheetCategory<AccountKind>(
            value: AccountKind.liquid,
            label: AccountKind.liquid.label,
            icon: AppIcons.accountBank,
          ),
          SheetCategory<AccountKind>(
            value: AccountKind.credit,
            label: AccountKind.credit.label,
            icon: AppIcons.accountCreditCard,
          ),
          SheetCategory<AccountKind>(
            value: AccountKind.restricted,
            label: AccountKind.restricted.label,
            icon: AppIcons.locked,
          ),
        ],
        allLabel: '全部类型',
        hint: '选择后仍可修改名称与图标。',
      ),
    );

/// ① 新增 / 编辑账户。**同一个 FormSheetContent**，但表单项与提交
/// 处理器按 [kind] 分开：储蓄类走 [savings]，信用卡走 [credit]。
Future<void> showAccountEditorSheet(
  BuildContext context, {
  required AccountController catalog,
  required SavingsAccountController savings,
  required CreditCardAccountController credit,
  required AccountKind kind,
  AccountRecord? account,
}) async {
  final AccountRecord? editing = account;
  final formController = FormSheetController();

  // 可见支出分类，给「绑定用途」多选标签用（3.5，仅储蓄类里的受限账户）。
  final List<SheetTag<Object>> bindingOptions =
      context.read<CategoryController>().visible(CategoryKind.expense)
          .map((c) => SheetTag<Object>(value: c.id ?? 0, label: c.name))
          .toList(growable: false);

  await AppSheetShell.show<SheetFormValues>(
    context,
    header: SheetHeader(
      title: editing == null ? '新增${kind.label}' : '编辑账户',
      centered: true,
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
        savings: savings,
        credit: credit,
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
              return '名称长度需为 1 ~ $_kNameMaxLength 个字符';
            }
            if (catalog.nameExists(name, excludeId: editing?.id)) {
              return '账户「$name」已存在';
            }
            return null;
          },
        ),

        // 具体类型：候选按类别写死（AccountType.allowedTypesFor）。
        // 信用卡候选里没有「其他」，其他资金账户候选里没有任何信用形态。
        SheetFormCustomItem(
          key: 'type',
          label: '具体类型',
          builder: (BuildContext ctx, ValueChanged<Object?> onChanged) =>
              _TypeField(
            kind: kind,
            initial: editing?.type ?? AccountType.defaultTypeFor(kind),
            onChanged: onChanged,
          ),
        ),

        const SheetFormSingleLineTextItem(
          key: 'note',
          label: '备注',
          hint: '例如：工资入账账户 / 房租储蓄',
        ),

        // ── 储蓄类专属：开户余额、受限账户开关与绑定用途 ────────────
        if (kind != AccountKind.credit) ...<SheetFormItem>[
          // 3.8：只有开户时允许填初始余额；编辑时不显示，
          // 避免改了期初值破坏「期初 + Σ流水 = 余额」恒等式。
          if (editing == null)
            SheetFormSingleLineTextItem(
              key: 'initial',
              label: '余额',
              initialValue: '0',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (String value) =>
                  (double.tryParse(value.trim()) ?? -1) < 0
                      ? '余额不得为负数'
                      : null,
            ),
          if (kind == AccountKind.restricted) ...<SheetFormItem>[
            SheetFormToggleItem(
              key: 'isLiquid',
              label: '计入可用余额',
              initialValue: editing?.isLiquid ?? false,
            ),
            SheetFormTagsItem(
              key: 'bindings',
              label: '绑定支出类型',
              options: bindingOptions,
              initialSelected: editing == null
                  ? const <Object>{}
                  : Set<Object>.from(catalog.bindingsOf(editing.id!)),
            ),
            const SheetFormNoteItem(
              key: 'bindTip',
              text: _kBindTip,
              align: TextAlign.start,
            ),
          ],
        ],

        // ── 信用卡专属：额度、账单周期、关联还款卡 ──────────────────
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
            label: '账单日（1 ~ 31）',
            initialValue: '${editing?.statementDay ?? 5}',
            keyboardType: TextInputType.number,
            validator: (String v) => _dayError(v, '账单日'),
          ),
          SheetFormSingleLineTextItem(
            key: 'dueDay',
            label: '还款日（1 ~ 31）',
            initialValue: '${editing?.dueDay ?? 25}',
            keyboardType: TextInputType.number,
            validator: (String v) => _dayError(v, '还款日'),
          ),
          // 关联还款储蓄卡：还款表单的默认来源。
          SheetFormCustomItem(
            key: 'repayTo',
            label: '还款账户',
            builder: (BuildContext ctx, ValueChanged<Object?> onChanged) =>
                _AccountPickerField(
              accounts: catalog.all
                  .where((AccountRecord r) =>
                      r.kind == AccountKind.liquid &&
                      !r.isDeleted &&
                      !r.archived)
                  .toList(growable: false),
              initialId: editing?.repayAccountId,
              hint: '可稍后补充',
              onChanged: onChanged,
            ),
          ),
          const SheetFormNoteItem(
            key: 'creditRuleTip',
            text: _kCreditRuleTip,
            align: TextAlign.start,
          ),
        ],
      ],
    ),
  );
}

/// ① 储蓄类账户间转账（3.7）。**只走 SavingsAccountController**，
/// 候选里不含信用卡；给信用卡还钱请用 [showAccountRepaySheet]。
///
/// 【契约 2 的一处明确取舍】「从哪个账户 / 转到哪个账户」也是内容选择，
/// 按契约 2 本该用 SelectSheetContent。但它是**表单里的一个字段**，再弹
/// 一层 Sheet 就成了「弹窗里套弹窗」；契约 1 又规定修改/新增一律
/// FormSheetContent。这里取「整个动作是一个表单」为主线，把两个选择器
/// 做成内联下拉（SheetFormCustomItem），不新建任何 Sheet 组件。
Future<void> showAccountTransferSheet(
  BuildContext context, {
  required AccountController catalog,
  required SavingsAccountController savings,
  int? fromId,
}) async {
  final formController = FormSheetController();
  // 信用卡不参与转账：它的「进钱」是还款，规则相反。
  final List<AccountRecord> savingsAccounts = catalog.all
      .where((AccountRecord r) =>
          !r.isDeleted && !r.archived && r.kind != AccountKind.credit)
      .toList(growable: false);

  await AppSheetShell.show<SheetFormValues>(
    context,
    header: SheetHeader(
      title: '账户转账',
      centered: true,
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
        savings: savings,
        values: values,
        fallbackFrom: fromId,
      ),
      items: <SheetFormItem>[
        SheetFormCustomItem(
          key: 'from',
          label: '转出账户',
          builder: (BuildContext ctx, ValueChanged<Object?> onChanged) =>
              _AccountPickerField(
            accounts: savingsAccounts,
            initialId: fromId,
            hint: '请选择转出账户',
            onChanged: onChanged,
          ),
        ),
        SheetFormCustomItem(
          key: 'to',
          label: '转入账户',
          builder: (BuildContext ctx, ValueChanged<Object?> onChanged) =>
              _AccountPickerField(
            accounts: savingsAccounts,
            hint: '请选择转入账户',
            onChanged: onChanged,
          ),
        ),
        SheetFormSingleLineTextItem(
          key: 'amount',
          label: '转账金额',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (String v) =>
              (double.tryParse(v.trim()) ?? 0) <= 0 ? _kNumberError : null,
        ),
        const SheetFormSingleLineTextItem(
          key: 'note',
          label: '备注',
          hint: '（可选）例如：转入微信零钱',
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

/// ① 信用卡「立即还款」：**独立表单，独立处理器**。
///
/// 不再是「预置转入账户的转账」：还款会同时减少来源储蓄账户余额与
/// 信用卡已用额度，两条流水用各自类别的规则，且金额不得超过已用额度。
Future<void> showAccountRepaySheet(
  BuildContext context, {
  required AccountController catalog,
  required CreditCardAccountController credit,
  required AccountRecord creditCard,
}) async {
  final formController = FormSheetController();
  final List<AccountRecord> sources = catalog.all
      .where((AccountRecord r) =>
          r.kind == AccountKind.liquid && !r.isDeleted && !r.archived)
      .toList(growable: false);
  final double used = creditCard.balance;

  await AppSheetShell.show<SheetFormValues>(
    context,
    header: SheetHeader(
      title: '${creditCard.name} 还款',
      centered: true,
      leading: const SheetCancelAction(),
      trailing: SheetTextAction(
        label: '确认还款',
        emphasized: true,
        onTap: formController.submit,
      ),
    ),
    child: FormSheetContent(
      controller: formController,
      onSubmit: (SheetFormValues values) => _repay(
        credit: credit,
        creditCard: creditCard,
        values: values,
      ),
      items: <SheetFormItem>[
        SheetFormNoteItem(
          key: 'cardInfo',
          text: '当前已用 ${MoneyFormat.yuan(used)} · '
              '账单日每月 ${creditCard.statementDay ?? "—"} 日 · '
              '还款日每月 ${creditCard.dueDay ?? "—"} 日 · '
              '最低还款约 ${MoneyFormat.yuan0(used * creditCard.minPaymentRate)}',
          align: TextAlign.start,
        ),
        SheetFormCustomItem(
          key: 'from',
          label: '还款来源',
          builder: (BuildContext ctx, ValueChanged<Object?> onChanged) =>
              _AccountPickerField(
            accounts: sources,
            initialId: creditCard.repayAccountId,
            hint: '请选择流动资金账户',
            onChanged: onChanged,
          ),
        ),
        SheetFormSingleLineTextItem(
          key: 'amount',
          label: '还款金额',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (String v) {
            final double n = double.tryParse(v.trim()) ?? 0;
            if (n <= 0) return _kNumberError;
            if (n > used + 0.000001) return '还款金额不能超过当前已用额度';
            return null;
          },
        ),
        const SheetFormSingleLineTextItem(
          key: 'note',
          label: '备注',
          hint: '（可选）例如：本月账单全额还款',
        ),
        const SheetFormNoteItem(
          key: 'repayTip',
          text: _kRepayTip,
          align: TextAlign.start,
        ),
      ],
    ),
  );
}

/// ① 信用卡消费出账：direction = out，credit 规则下已用额度增加。
Future<void> showAccountCreditSpendSheet(
  BuildContext context, {
  required CreditCardAccountController credit,
  required AccountRecord account,
}) async {
  final formController = FormSheetController();
  await AppSheetShell.show<SheetFormValues>(
    context,
    header: SheetHeader(
      title: '消费出账',
      centered: true,
      leading: const SheetCancelAction(),
      trailing: SheetTextAction(
        label: '确认',
        emphasized: true,
        onTap: formController.submit,
      ),
    ),
    child: FormSheetContent(
      controller: formController,
      onSubmit: (SheetFormValues values) => credit.spend(
        accountId: account.id!,
        amount: double.tryParse(values.text('amount').trim()) ?? 0,
        note: values.text('note'),
      ),
      items: <SheetFormItem>[
        SheetFormNoteItem(
          key: 'available',
          text: '当前已用 ${MoneyFormat.yuan(account.balance)} · '
              '可用 ${MoneyFormat.orDash(account.availableCredit)}',
          align: TextAlign.start,
        ),
        SheetFormSingleLineTextItem(
          key: 'amount',
          label: '消费金额',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (String v) =>
              (double.tryParse(v.trim()) ?? 0) <= 0 ? _kNumberError : null,
        ),
        const SheetFormSingleLineTextItem(
          key: 'note',
          label: '备注',
          hint: '（可选）例如：超市购物',
        ),
        const SheetFormNoteItem(
          key: 'creditRuleTip',
          text: _kCreditRuleTip,
          align: TextAlign.start,
        ),
      ],
    ),
  );
}

/// ① 储蓄类余额调整（3.8：必须填原因、留痕）。
Future<void> showAccountAdjustSheet(
  BuildContext context, {
  required SavingsAccountController savings,
  required AccountRecord account,
}) async {
  final formController = FormSheetController();
  await AppSheetShell.show<SheetFormValues>(
    context,
    header: SheetHeader(
      title: '余额调整',
      centered: true,
      leading: const SheetCancelAction(),
      trailing: SheetTextAction(
        label: '确认调整',
        emphasized: true,
        onTap: formController.submit,
      ),
    ),
    child: FormSheetContent(
      controller: formController,
      onSubmit: (SheetFormValues values) => savings.adjustBalance(
        accountId: account.id!,
        actualBalance:
            double.tryParse(values.text('actual').trim()) ?? account.balance,
        reason: values.text('reason'),
      ),
      items: <SheetFormItem>[
        SheetFormNoteItem(
          key: 'current',
          text: '当前余额：${MoneyFormat.yuan(account.balance)}',
          align: TextAlign.start,
        ),
        SheetFormSingleLineTextItem(
          key: 'actual',
          label: '实际余额',
          initialValue: account.balance.toStringAsFixed(0),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (String v) =>
              double.tryParse(v.trim()) == null ? _kNumberError : null,
        ),
        SheetFormMultiLineTextItem(
          key: 'reason',
          label: '调整原因',
          hint: '例如：银行扣收年费，未同步记录',
          minLines: 2,
          maxLines: 2,
          showCounter: false,
          validator: (String v) =>
              v.trim().isEmpty ? '请填写调整原因，便于后续核对' : null,
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

/// ① 信用卡「已用额度校准」：**独立表单**，与储蓄类余额调整分开。
/// 差额 > 0 记出账、差额 < 0 记入账，方向判断与储蓄类相反。
Future<void> showAccountCreditAdjustSheet(
  BuildContext context, {
  required CreditCardAccountController credit,
  required AccountRecord account,
}) async {
  final formController = FormSheetController();
  await AppSheetShell.show<SheetFormValues>(
    context,
    header: SheetHeader(
      title: '已用额度校准',
      centered: true,
      leading: const SheetCancelAction(),
      trailing: SheetTextAction(
        label: '确认校准',
        emphasized: true,
        onTap: formController.submit,
      ),
    ),
    child: FormSheetContent(
      controller: formController,
      onSubmit: (SheetFormValues values) => credit.adjustUsedAmount(
        accountId: account.id!,
        actualUsed:
            double.tryParse(values.text('actual').trim()) ?? account.balance,
        reason: values.text('reason'),
      ),
      items: <SheetFormItem>[
        SheetFormNoteItem(
          key: 'current',
          text: '当前已用额度：${MoneyFormat.yuan(account.balance)}',
          align: TextAlign.start,
        ),
        SheetFormSingleLineTextItem(
          key: 'actual',
          label: '实际已用额度',
          initialValue: account.balance.toStringAsFixed(0),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (String v) =>
              double.tryParse(v.trim()) == null ? _kNumberError : null,
        ),
        SheetFormMultiLineTextItem(
          key: 'reason',
          label: '校准原因',
          hint: '例如：账单金额与本地记录不一致',
          minLines: 2,
          maxLines: 2,
          showCounter: false,
          validator: (String v) =>
              v.trim().isEmpty ? '请填写校准原因，便于后续核对' : null,
        ),
        const SheetFormNoteItem(
          key: 'creditAdjustTip',
          text: _kCreditAdjustTip,
          align: TextAlign.start,
        ),
      ],
    ),
  );
}

/// ① 调整信用卡额度（只改属性，不写流水）。
Future<void> showAccountCreditLimitSheet(
  BuildContext context, {
  required CreditCardAccountController credit,
  required AccountRecord account,
}) async {
  final formController = FormSheetController();
  await AppSheetShell.show<SheetFormValues>(
    context,
    header: SheetHeader(
      title: '调整额度',
      centered: true,
      leading: const SheetCancelAction(),
      trailing: SheetTextAction(
        label: '保存',
        emphasized: true,
        onTap: formController.submit,
      ),
    ),
    child: FormSheetContent(
      controller: formController,
      onSubmit: (SheetFormValues values) => credit.setCreditLimit(
        account.id!,
        double.tryParse(values.text('limit').trim()) ?? 0,
      ),
      items: <SheetFormItem>[
        SheetFormSingleLineTextItem(
          key: 'limit',
          label: '信用额度',
          initialValue: account.creditLimit?.toStringAsFixed(0) ?? '',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (String v) =>
              (double.tryParse(v.trim()) ?? 0) <= 0 ? _kNumberError : null,
        ),
        SheetFormNoteItem(
          key: 'used',
          text: '当前已用 ${MoneyFormat.yuan0(account.balance)}，'
              '可用额度将自动重新计算。',
          align: TextAlign.start,
        ),
      ],
    ),
  );
}

/// ① 修改其他资金账户的绑定用途（3.5）。
Future<void> showAccountBindingsSheet(
  BuildContext context, {
  required AccountController catalog,
  required SavingsAccountController savings,
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
      title: '可支付支出类型',
      centered: true,
      leading: const SheetCancelAction(),
      trailing: SheetTextAction(
        label: '保存',
        emphasized: true,
        onTap: formController.submit,
      ),
    ),
    child: FormSheetContent(
      controller: formController,
      onSubmit: (SheetFormValues values) => savings.setBindings(
        account.id!,
        values.tags('bindings').whereType<int>().toSet(),
      ),
      items: <SheetFormItem>[
        SheetFormTagsItem(
          key: 'bindings',
          label: '请选择允许使用该账户支付的支出类型',
          options: options,
          initialSelected: Set<Object>.from(catalog.bindingsOf(account.id!)),
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
/// 只改标记、不写流水，属共享账本的通用记录维护。
Future<void> showAccountArchiveSheet(
  BuildContext context, {
  required AccountController catalog,
  required AccountRecord account,
  required bool archive,
}) async {
  await AppSheetShell.show<void>(
    context,
    header: SheetHeader(
      title: archive ? '归档账户' : '恢复账户',
      centered: true,
      leading: const SheetCancelAction(),
    ),
    child: ConfirmSheetContent(
      title:
          archive ? '确认归档「${account.name}」？' : '确认恢复「${account.name}」？',
      description: archive
          ? '归档后该账户不再显示于日常列表，历史流水完整保留，可随时恢复。'
          : '恢复后该账户将重新显示于账户页，历史流水保持不变。',
      secondaryLabel: '取消',
      primaryLabel: archive ? '确认归档' : '确认恢复',
      icon: archive ? AppIcons.archive : AppIcons.unarchive,
      intent: SheetIntent.warning,
      footnote: '该操作可随时撤销。',
      onPrimaryAsync: () => catalog.setArchived(account.id!, archive),
    ),
  );
}

/// ③ 删除账户（3.8 先数流水再提示；10.7 进回收站 30 天）。
Future<void> showAccountDeleteSheet(
  BuildContext context, {
  required AccountController catalog,
  required AccountRecord account,
}) async {
  final int entries = await catalog.countEntries(account.id!);
  if (!context.mounted) return;
  await AppSheetShell.show<void>(
    context,
    header: SheetHeader(
      title: '删除账户',
      centered: true,
      leading: const SheetCancelAction(),
    ),
    child: ConfirmSheetContent(
      title: '删除「${account.name}」？',
      description: '该账户下共有 $entries 笔记录。删除后记录仍将保留，'
          '但不再关联该账户。',
      secondaryLabel: '取消',
      primaryLabel: '确认删除',
      icon: AppIcons.trash,
      intent: SheetIntent.danger,
      footnote: '删除后将进入回收站，30 天内可恢复。',
      onPrimaryAsync: () => catalog.delete(account.id!),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════
// 提交逻辑：储蓄类与信用卡**分开**，两条路径不共用任何实现
// ══════════════════════════════════════════════════════════════════

/// 表单值 → 两个业务处理器之一。工作逻辑：按 key 取值 → 按类别分派 →
/// `await 处理器.save` → 成功才由公共组件关闭弹层；抛异常则提示且保持打开。
Future<void> _saveAccount({
  required SavingsAccountController savings,
  required CreditCardAccountController credit,
  required AccountKind kind,
  required AccountRecord? editing,
  required SheetFormValues values,
}) async {
  // 历史脏数据兜底：v4 曾允许任意形态与类别组合，若旧记录的形态不在
  // 当前类别清单里，回退到该类别默认形态，而不是把错配值塞进下拉。
  // 这一步在提交环节也做一次，保证用户没动下拉时同样合法。
  AccountType type = values.raw('type') as AccountType? ??
      editing?.type ??
      AccountType.defaultTypeFor(kind);
  if (!type.supports(kind)) type = AccountType.defaultTypeFor(kind);

  if (kind == AccountKind.credit) {
    await _saveCreditCard(
      credit: credit,
      editing: editing,
      values: values,
      type: type,
    );
    return;
  }
  await _saveSavings(
    savings: savings,
    kind: kind,
    editing: editing,
    values: values,
    type: type,
  );
}

Future<void> _saveSavings({
  required SavingsAccountController savings,
  required AccountKind kind,
  required AccountRecord? editing,
  required SheetFormValues values,
  required AccountType type,
}) async {
  final double initial =
      double.tryParse(values.text('initial').trim()) ??
          editing?.initialBalance ??
          0;
  final bool isLiquid = type.liquidLocked
      ? false
      : (values.contains('isLiquid')
          ? values.flag('isLiquid')
          : kind == AccountKind.liquid);

  await savings.save(
    id: editing?.id,
    kind: kind,
    type: type,
    name: values.text('name'),
    initialBalance: initial,
    note: values.text('note'),
    isLiquid: isLiquid,
    includeInNetWorth: editing?.includeInNetWorth ?? true,
    bindingIds: kind == AccountKind.restricted
        ? values.tags('bindings').whereType<int>().toSet()
        : const <int>{},
  );
}

Future<void> _saveCreditCard({
  required CreditCardAccountController credit,
  required AccountRecord? editing,
  required SheetFormValues values,
  required AccountType type,
}) async {
  final double limit = double.tryParse(values.text('limit').trim()) ??
      editing?.creditLimit ??
      0;
  final int statementDay = int.tryParse(values.text('statementDay').trim()) ??
      editing?.statementDay ??
      5;
  final int dueDay = int.tryParse(values.text('dueDay').trim()) ??
      editing?.dueDay ??
      25;
  final int? repayTo =
      values.raw('repayTo') as int? ?? editing?.repayAccountId;

  await credit.save(
    id: editing?.id,
    type: type,
    name: values.text('name'),
    creditLimit: limit,
    statementDay: statementDay,
    dueDay: dueDay,
    repayAccountId: repayTo,
    // 界面暂不开放该字段，编辑时沿用旧值，避免被默认值悄悄覆盖。
    minPaymentRate: editing?.minPaymentRate ?? 0.1,
    note: values.text('note'),
  );
}

Future<void> _transfer({
  required SavingsAccountController savings,
  required SheetFormValues values,
  required int? fallbackFrom,
}) async {
  final int? from = values.raw('from') as int? ?? fallbackFrom;
  final int? to = values.raw('to') as int?;
  if (from == null || to == null) {
    throw StateError('请选择转出账户与转入账户');
  }
  await savings.transfer(
    fromId: from,
    toId: to,
    amount: double.tryParse(values.text('amount').trim()) ?? 0,
    note: values.text('note'),
  );
}

Future<void> _repay({
  required CreditCardAccountController credit,
  required AccountRecord creditCard,
  required SheetFormValues values,
}) async {
  final int? from = values.raw('from') as int? ??
      creditCard.repayAccountId;
  if (from == null) throw StateError('请选择还款来源账户');
  await credit.repay(
    creditCardId: creditCard.id!,
    fromAccountId: from,
    amount: double.tryParse(values.text('amount').trim()) ?? 0,
    note: values.text('note'),
  );
}

String? _dayError(String raw, String label) {
  final int? day = int.tryParse(raw.trim());
  if (day == null || day < 1 || day > 31) {
    return '请输入有效的$label（1 ~ 31）';
  }
  return null;
}

// ══════════════════════════════════════════════════════════════════
// 表单里的私有字段（只服务本文件，样式全走全局令牌）
// ══════════════════════════════════════════════════════════════════

/// 具体类型下拉：候选来自 [AccountType.allowedTypesFor] 的静态清单。
/// 【局部状态工作逻辑】选中值由本组件持有，点选后 `onChanged` 上抛给
/// FormSheetContent 统一收集；外层表单不额外持有 controller。
/// 【历史脏数据兜底】旧记录形态若已不在清单里（例如「其他资金账户 +
/// 信用卡」），直接回退到该类别默认形态，不再把错配值补进下拉候选 ——
/// 这正是本轮要求的「其他类型账户中将信用卡类型删除」。
class _TypeField extends StatefulWidget {
  const _TypeField({
    required this.kind,
    required this.initial,
    required this.onChanged,
  });

  final AccountKind kind;
  final AccountType initial;
  final ValueChanged<Object?> onChanged;

  @override
  State<_TypeField> createState() => _TypeFieldState();
}

class _TypeFieldState extends State<_TypeField> {
  late AccountType _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initial.supports(widget.kind)
        ? widget.initial
        : AccountType.defaultTypeFor(widget.kind);
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
            for (final AccountType t in AccountType.allowedTypesFor(widget.kind))
              DropdownMenuItem<AccountType>(
                value: t,
                child: Text(t.label),
              ),
          ],
          onChanged: (AccountType? v) {
            if (v == null) return;
            setState(() => _value = v);
            widget.onChanged(v);
          },
        ),
      );
}

/// 账户下拉（转账 / 还款来源 / 关联还款卡共用）。
/// 【局部状态工作逻辑】内部持有选中 id，变化即上抛；没选时允许为 null，
/// 提交环节会给出「要先选好账户」的明确提示，不静默写库。
class _AccountPickerField extends StatefulWidget {
  const _AccountPickerField({
    required this.accounts,
    required this.hint,
    required this.onChanged,
    this.initialId,
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
