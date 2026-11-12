import 'dart:async';

import 'package:flutter/material.dart';
import 'package:yuan/screens/commons/icons/app_icons.dart';
import 'package:yuan/screens/commons/sheet/parts/sheet_buttons.dart';
import 'package:yuan/screens/commons/sheet/parts/sheet_primitives.dart';
import 'package:yuan/screens/commons/sheet/sheet_models.dart';
import 'package:yuan/styles/sheet_tokens.dart';
import 'package:yuan/styles/theme_tokens.dart';

/// 原型 ②「危险确认」：居中圆形语义图标徽章 + 大标题 + 两行说明 +
/// 「再想想 / 确认删除」双按钮 + 不可撤销注释。
///
/// [intent] 决定徽章与危险按钮的取色；默认是 danger（语义「支出」红，
/// 已 harmonize 到当前主题种子）。改成 warning / neutral 时同一套布局
/// 会自动换成对应语义色，不需要另写组件。
///
/// 【本轮补齐的异步确认链路，工作逻辑写清楚】
/// 归档 / 删除这类「二次确认后还要 await 写库」的操作，不能把 Future
/// 丢给同步 [onPrimary]——那会界面先关、写盘失败无人知（前几轮修过的
/// P0）。所以新增 [onPrimaryAsync]，与 `SelectSheetContent.onApplyAsync`
/// 完全同构：
///   ① 点主按钮 → `_saving = true` → 按钮显示进度且禁连点；
///   ② `await onPrimaryAsync()`；
///   ③ 成功才用**渲染时 context** 调 `SheetActions.close(context)` 关弹层
///      （构造期捕获的页面 context 在 SheetScope 之外，会静默 no-op，
///      这正是 SheetCancelAction 注释里讲过的坑）；
///   ④ 抛异常 → SnackBar 提示、弹层**保持打开**、界面数据不变。
/// 老调用点只传 [onPrimary] 时行为一字不变（纯同步、不显示进度）。
/// 这是唯一一处动态状态（_saving），没有 Notifier / 跨帧注册。
class ConfirmSheetContent extends StatefulWidget {
  const ConfirmSheetContent({
    super.key,
    required this.title,
    required this.description,
    required this.secondaryLabel,
    required this.primaryLabel,
    this.icon,
    this.intent = SheetIntent.danger,
    this.footnote,
    this.onSecondary,
    this.onPrimary,
    this.onPrimaryAsync,
    this.loading = false,
  });

  final String title;
  final String description;
  final String secondaryLabel;
  final String primaryLabel;
  final IconData? icon;
  final SheetIntent intent;
  final String? footnote;
  final VoidCallback? onSecondary;
  final VoidCallback? onPrimary;

  /// 异步确认（需要写盘 / await 的场景）；优先于 [onPrimary]。
  final Future<void> Function()? onPrimaryAsync;
  final bool loading;

  @override
  State<ConfirmSheetContent> createState() => _ConfirmSheetContentState();
}

class _ConfirmSheetContentState extends State<ConfirmSheetContent> {
  bool _saving = false;

  bool get _busy => _saving || widget.loading;

  Future<void> _confirm() async {
    final Future<void> Function()? handler = widget.onPrimaryAsync;
    if (handler == null) {
      widget.onPrimary?.call();
      return;
    }
    if (_busy) return;
    setState(() => _saving = true);
    try {
      await handler();
      if (!mounted) return;
      // 必须用本组件 build 时的 context：它在 SheetScope 内。
      SheetActions.close(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = SheetPalette.of(context);
    final text = SheetText.of(context);
    final Color tone = sheetIntentTone(p, widget.intent);
    final bool danger = widget.intent == SheetIntent.danger;
    // 两个主回调都没传时保持旧行为：按钮禁用，不是「点了没反应」。
    final bool hasPrimary =
        widget.onPrimary != null || widget.onPrimaryAsync != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: SheetIconBadge(
            icon: widget.icon ?? AppIcons.trash,
            tone: tone,
          ),
        ),
        const SizedBox(height: AppSheetSize.sectionGap),
        Text(
          widget.title,
          textAlign: TextAlign.center,
          style: text.confirmTitle,
        ),
        const SizedBox(height: AppSpacing.sm),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
          ),
          child: Text(
            widget.description,
            textAlign: TextAlign.center,
            style: text.confirmBody,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        SheetButtonPair(
          secondaryLabel: widget.secondaryLabel,
          primaryLabel: widget.primaryLabel,
          onSecondary: widget.onSecondary ?? () => SheetActions.close(context),
          onPrimary: !hasPrimary || _busy ? null : () => unawaited(_confirm()),
          danger: danger,
          loading: _busy,
        ),
        if (widget.footnote != null)
          SheetCaption(text: widget.footnote!, centered: true),
      ],
    );
  }
}
