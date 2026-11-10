import 'package:flutter/material.dart';
import 'package:yuan/styles/sheet_tokens.dart';
import 'package:yuan/styles/theme_tokens.dart';

// ── 组件私有常量（只服务本文件）────────────────────────────────
const double _kLoadingSize = 20;
const double _kLoadingStroke = 2;

/// 原型里那种「蓝紫渐变 + 全圆角 + 同色柔和外发光」的主操作按钮。
///
/// 渐变与光晕全部来自 [SheetPalette]，不写死蓝色：
/// [danger] = true 时自动切成语义「支出」红渐变（删除确认）。
/// [loading] = true 时显示进度圈并禁用点击，配合 `await` 保存链路。
class SheetGradientButton extends StatelessWidget {
  const SheetGradientButton({
    super.key,
    required this.label,
    this.onPressed,
    this.danger = false,
    this.loading = false,
    this.icon,
    this.height = AppSheetSize.primaryButtonHeight,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool danger;
  final bool loading;
  final IconData? icon;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = SheetPalette.of(context);
    final text = SheetText.of(context);
    final enabled = onPressed != null && !loading;
    final activeVisual = onPressed != null;

    final Gradient gradient = danger ? p.dangerGradient : p.primaryGradient;
    final Color foreground =
        danger ? p.onDangerGradient : p.onPrimaryGradient;
    final List<BoxShadow> glow =
        danger ? p.dangerGlow : p.primaryGlow;

    final Widget content = loading
        ? SizedBox(
            width: _kLoadingSize,
            height: _kLoadingSize,
            child: CircularProgressIndicator(
              strokeWidth: _kLoadingStroke,
              color: foreground,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: AppIconSize.medium, color: foreground),
                const SizedBox(width: AppSpacing.xs),
              ],
              Text(
                label,
                style: text.buttonLabel.copyWith(color: foreground),
              ),
            ],
          );

    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: activeVisual ? gradient : null,
        color: activeVisual ? null : p.unselectedTint,
        borderRadius: BorderRadius.circular(AppSheetRadius.pill),
        boxShadow: activeVisual ? glow : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppSheetRadius.pill),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSheetRadius.pill),
          onTap: enabled ? onPressed : null,
          child: Center(
            child: (loading || enabled)
                ? content
                : Text(
                    label,
                    style: text.plainButtonLabel.copyWith(
                      color: p.mutedText,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// 次要按钮：浅灰胶囊、深色文字、无光晕（「再想想」）。
class SheetPlainButton extends StatelessWidget {
  const SheetPlainButton({
    super.key,
    required this.label,
    this.onPressed,
    this.height = AppSheetSize.secondaryButtonHeight,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = SheetPalette.of(context);
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: p.unselectedTint,
        borderRadius: BorderRadius.circular(AppSheetRadius.pill),
        border: Border.all(
          color: p.dividerColor.withValues(alpha: AppOpacity.outline),
          width: AppBorder.thin,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppSheetRadius.pill),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSheetRadius.pill),
          onTap: onPressed,
          child: Center(
            child: Text(
              label,
              style: SheetText.of(context).plainButtonLabel,
            ),
          ),
        ),
      ),
    );
  }
}

/// 两个等宽按钮并排（确认弹层的「再想想 / 确认删除」）。
class SheetButtonPair extends StatelessWidget {
  const SheetButtonPair({
    super.key,
    required this.secondaryLabel,
    required this.primaryLabel,
    this.onSecondary,
    this.onPrimary,
    this.danger = false,
    this.loading = false,
  });

  final String secondaryLabel;
  final String primaryLabel;
  final VoidCallback? onSecondary;
  final VoidCallback? onPrimary;
  final bool danger;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: SheetPlainButton(
            label: secondaryLabel,
            onPressed: loading ? null : onSecondary,
          ),
        ),
        const SizedBox(width: AppSheetSize.itemGap),
        Expanded(
          child: SheetGradientButton(
            label: primaryLabel,
            onPressed: onPrimary,
            danger: danger,
            loading: loading,
          ),
        ),
      ],
    );
  }
}
