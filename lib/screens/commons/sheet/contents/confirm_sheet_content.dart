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
class ConfirmSheetContent extends StatelessWidget {
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
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final p = SheetPalette.of(context);
    final text = SheetText.of(context);
    final Color tone = sheetIntentTone(p, intent);
    final bool danger = intent == SheetIntent.danger;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: SheetIconBadge(
            icon: icon ?? AppIcons.trash,
            tone: tone,
          ),
        ),
        const SizedBox(height: AppSheetSize.sectionGap),
        Text(
          title,
          textAlign: TextAlign.center,
          style: text.confirmTitle,
        ),
        const SizedBox(height: AppSpacing.sm),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
          ),
          child: Text(
            description,
            textAlign: TextAlign.center,
            style: text.confirmBody,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        SheetButtonPair(
          secondaryLabel: secondaryLabel,
          primaryLabel: primaryLabel,
          onSecondary: onSecondary ?? () => SheetActions.close(context),
          onPrimary: onPrimary,
          danger: danger,
          loading: loading,
        ),
        if (footnote != null)
          SheetCaption(text: footnote!, centered: true),
      ],
    );
  }
}
