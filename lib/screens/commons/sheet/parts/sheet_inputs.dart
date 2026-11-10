import 'package:flutter/material.dart';
import 'package:yuan/screens/commons/icons/app_icons.dart';
import 'package:yuan/screens/commons/sheet/sheet_models.dart';
import 'package:yuan/styles/app_decorations.dart';
import 'package:yuan/styles/sheet_tokens.dart';
import 'package:yuan/styles/theme_tokens.dart';

// ── 组件私有常量（只服务本文件）────────────────────────────────
const double _kFieldMinHeight = 56;
const double _kFieldPaddingV = AppSpacing.sm;
const double _kFieldPaddingH = AppSpacing.md;
const double _kLabelGap = AppSpacing.md;
const double _kSwitchRowMinHeight = 56;

/// 表单行：左侧 label、右侧可编辑值，单行 / 多行通用。
///
/// 刻意用 `InputDecoration(border: InputBorder.none, filled: false)` 覆盖
/// 全局 `InputDecorationTheme`（filled + 下划线指示线），否则输入框会自带
/// 一层填充色和底边，和原型里「整行一个圆角框」的观感对不上。
class SheetFormField extends StatelessWidget {
  const SheetFormField({super.key, required this.spec});

  final SheetFieldSpec spec;

  @override
  Widget build(BuildContext context) {
    final text = SheetText.of(context);
    final p = SheetPalette.of(context);
    final multiLine = spec.maxLines > 1;

    return Container(
      constraints: const BoxConstraints(minHeight: _kFieldMinHeight),
      decoration: AppDecorations.field(context),
      padding: const EdgeInsets.symmetric(
        horizontal: _kFieldPaddingH,
        vertical: _kFieldPaddingV,
      ),
      child: Row(
        crossAxisAlignment:
            multiLine ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.only(top: multiLine ? AppSpacing.xxs : 0),
            child: Text(spec.label, style: text.fieldLabel),
          ),
          const SizedBox(width: _kLabelGap),
          Expanded(
            child: TextFormField(
              initialValue: spec.value,
              maxLines: spec.maxLines,
              minLines: multiLine ? spec.maxLines : null,
              onChanged: spec.onChanged,
              style: text.fieldValue,
              decoration: InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                hintStyle: text.fieldValue.copyWith(
                  color: p.mutedText.withValues(alpha: AppOpacity.hint),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 开关行（「设为公开」）。Switch 走 ThemeData 的 M3 默认样式，
/// 会自动跟随当前 ColorScheme，不需要局部写颜色。
class SheetSwitchRow extends StatelessWidget {
  const SheetSwitchRow({super.key, required this.spec});

  final SheetSwitchSpec spec;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _kSwitchRowMinHeight,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              spec.label,
              style: SheetText.of(context).optionLabel,
            ),
          ),
          Switch(
            value: spec.value,
            onChanged: spec.onChanged,
          ),
        ],
      ),
    );
  }
}

/// 头像占位圆 + 右下角相机角标（编辑资料弹层）。
///
/// 图像本体由业务层通过 [image] 传入（可接统一图片层的 AppImage），
/// 这里只负责形状、角标与点击热区，不碰任何图片存储逻辑。
class SheetAvatarField extends StatelessWidget {
  const SheetAvatarField({
    super.key,
    this.image,
    this.onTap,
    this.size = AppSheetSize.avatarSize,
  });

  final Widget? image;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = SheetPalette.of(context);
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned.fill(
              child: Material(
                color: p.unselectedTint,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onTap,
                  child: ClipOval(
                    child: image ??
                        Icon(
                          AppIcons.user,
                          size: AppIconSize.empty,
                          color: p.mutedText,
                        ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: AppSheetSize.avatarCameraBadge,
                height: AppSheetSize.avatarCameraBadge,
                decoration: BoxDecoration(
                  color: p.unselectedTint,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: p.glassColor,
                    width: AppBorder.focused,
                  ),
                ),
                child: Icon(
                  AppIcons.camera,
                  size: AppIconSize.small,
                  color: p.mutedText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
