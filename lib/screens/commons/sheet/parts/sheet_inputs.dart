import 'package:flutter/material.dart';
import 'package:yuan/screens/commons/icons/app_icons.dart';
import 'package:yuan/styles/app_decorations.dart';
import 'package:yuan/styles/sheet_tokens.dart';
import 'package:yuan/styles/theme_tokens.dart';

// ── 组件私有样式（只服务本文件，全部引用全局令牌）──────────────
const double _kFieldMinHeight = AppLayout.fieldMinHeight;
const double _kFieldPaddingV = AppSpacing.sm;
const double _kFieldPaddingH = AppSpacing.md;
const double _kLabelGap = AppSpacing.md;
const double _kSwitchRowMinHeight = AppLayout.listItemMinHeight;
const double _kClearIconSize = AppIconSize.small;
const double _kCounterGap = AppSpacing.xxs;

/// 表单文本输入行。
///
/// 这是**通用零件**：只描述「一个 label + 一个输入框」长什么样、怎么用，
/// 不知道表单里其它项是什么。样式全部来自全局令牌与 ColorScheme：
/// 容器用 `AppDecorations.field`，文字用 `SheetText`，错误色用 `cs.error`。
///
/// 刻意用 `InputDecoration(border: InputBorder.none, filled: false)` 覆盖
/// 全局 `InputDecorationTheme`（filled + 下划线指示线），否则输入框会自带
/// 一层填充色和底边，和原型里「整行一个圆角框」的观感对不上。
/// 错误文案与字数统计仍由本零件按同一套排版渲染，不散到业务层。
class SheetFormField extends StatelessWidget {
  const SheetFormField({
    super.key,
    required this.label,
    required this.controller,
    this.hintText,
    this.maxLength,
    this.maxLines = 1,
    this.minLines,
    this.showClearButton = false,
    this.showCounter = false,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final String? hintText;
  final int? maxLength;
  final int maxLines;
  final int? minLines;
  final bool showClearButton;
  final bool showCounter;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String? value)? validator;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final text = SheetText.of(context);
    final p = SheetPalette.of(context);
    final cs = Theme.of(context).colorScheme;
    final multiLine = maxLines > 1;

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
            child: Text(label, style: text.fieldLabel),
          ),
          const SizedBox(width: _kLabelGap),
          Expanded(
            // child 参数不会随文本变化重建，保证 FormFieldState / validator
            // 注册稳定；只有「清除按钮 + 字数」这两个随输入变化的部分在 builder 里。
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              child: TextFormField(
                controller: controller,
                maxLength: maxLength,
                maxLines: maxLines,
                minLines: minLines,
                keyboardType: keyboardType,
                textInputAction: textInputAction,
                validator: validator,
                onChanged: onChanged,
                style: text.fieldValue,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  filled: false,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  hintText: hintText,
                  counterText: '',
                  errorMaxLines: 2,
                  hintStyle: text.fieldValue.copyWith(
                    color: p.mutedText.withValues(alpha: AppOpacity.hint),
                  ),
                  errorStyle: text.caption.copyWith(color: cs.error),
                ),
              ),
              builder: (context, value, field) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: multiLine
                          ? CrossAxisAlignment.start
                          : CrossAxisAlignment.center,
                      children: <Widget>[
                        Expanded(child: field!),
                        if (showClearButton && value.text.isNotEmpty)
                          IconButton(
                            onPressed: controller.clear,
                            tooltip: '清空',
                            icon: const Icon(
                              AppIcons.clear,
                              size: _kClearIconSize,
                            ),
                            color: p.mutedText,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints.tightFor(
                              width: kMinTapTarget,
                              height: kMinTapTarget,
                            ),
                          ),
                      ],
                    ),
                    if (showCounter && maxLength != null)
                      Padding(
                        padding: const EdgeInsets.only(top: _kCounterGap),
                        child: Text(
                          '${value.text.length}/$maxLength',
                          style: text.caption,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 头像无图时的通用占位：圆形底 + 语义用户图标。
///
/// 供「内容由外部填充」的头像项使用，业务层不必再自己取
/// `colorScheme` / `tokens`，也就不会把样式逻辑带回业务组件。
class SheetFormAvatarPlaceholder extends StatelessWidget {
  const SheetFormAvatarPlaceholder({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final p = SheetPalette.of(context);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: p.unselectedTint,
        shape: BoxShape.circle,
      ),
      child: Icon(
        AppIcons.user,
        size: size * 0.5,
        color: p.mutedText,
      ),
    );
  }
}

/// 「左标签 + 右内容」的通用行，供标签组 / 自定义项复用。
///
/// 标签列宽来自全局令牌 `AppSheetSize.formLabelWidth`，全软件表单对齐一致。
class SheetFormLabeledRow extends StatelessWidget {
  const SheetFormLabeledRow({
    super.key,
    this.label,
    required this.child,
    this.alignTop = false,
  });

  final String? label;
  final Widget child;
  final bool alignTop;

  @override
  Widget build(BuildContext context) {
    final content = Expanded(child: child);
    if (label == null) return Row(children: <Widget>[content]);

    return Row(
      crossAxisAlignment:
          alignTop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: <Widget>[
        SizedBox(
          width: AppSheetSize.formLabelWidth,
          child: Padding(
            padding: EdgeInsets.only(top: alignTop ? AppSpacing.xs : 0),
            child: Text(label!, style: SheetText.of(context).optionLabel),
          ),
        ),
        content,
      ],
    );
  }
}

/// 开关行（「设为公开」）。Switch 走 ThemeData 的 M3 默认样式，
/// 会自动跟随当前 ColorScheme，不需要局部写颜色。
class SheetSwitchRow extends StatelessWidget {
  const SheetSwitchRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _kSwitchRowMinHeight,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: SheetText.of(context).optionLabel,
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// 头像占位圆 + 右下角相机角标（原型 ③）。
///
/// 公共组件只负责形状、尺寸、角标与点击热区；图像本体由使用方通过
/// [image] 注入（一般是 `SingleImagePickerWidget`），不碰任何图片存储逻辑。
///
/// 刻意不套 `ClipOval`：注入的图片组件自己已处理圆形与删除角标，
/// 外层再裁一次会把它的角标裁掉。`Material` 的圆形背景提供无图时的占位。
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
    final Widget content = image ??
        Icon(
          AppIcons.user,
          size: AppIconSize.empty,
          color: p.mutedText,
        );

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
                clipBehavior: Clip.none,
                child: onTap == null
                    ? content
                    : InkWell(
                        customBorder: const CircleBorder(),
                        onTap: onTap,
                        child: content,
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
