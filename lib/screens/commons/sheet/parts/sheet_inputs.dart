import 'package:flutter/material.dart';
import 'package:yuan/screens/commons/icons/app_icons.dart';
import 'package:yuan/styles/app_decorations.dart';
import 'package:yuan/styles/sheet_tokens.dart';
import 'package:yuan/styles/theme_tokens.dart';

// ── 组件私有样式（只服务本文件，全部引用全局令牌）──────────────
/// 单行高度 = 全局最小点击区 48dp，不再跟着多行 / 独立输入框的 56dp。
/// 这是「单行看起来过高」的根因：两种控件共用一个 minHeight。
const double _kSingleLineFieldHeight = kMinTapTarget;
const double _kMultiLineFieldMinHeight = AppLayout.fieldMinHeight;
const double _kMultiLineFieldPaddingV = AppSpacing.sm;
const double _kFieldPaddingH = AppSpacing.md;
const double _kLabelGap = AppSpacing.md;
const double _kLabelTopInset = AppSpacing.xxs;
const double _kSwitchRowMinHeight = AppLayout.listItemMinHeight;
const double _kClearIconSize = AppIconSize.small;
const double _kCounterGap = AppSpacing.xxs;

/// 两种文本行共用的容器外壳。
///
/// 统一了「原来 label 没固定宽、标签组却有 72dp 列」的错位：
/// 现在单行 / 多行 / 标签组 / 自定义项全部用 `AppSheetSize.formLabelWidth`
/// 对齐，样式只有这一份（容器装饰、圆角、内边距、label 排版）。
///
/// [singleLine] 是两者唯一的布局差异开关：
/// - 单行：48dp 下限、垂直内边距 0、Row 垂直居中。Container 的 minHeight
///   会以约束形式传给 child，Row 被撑到 48dp 后由 crossAxisAlignment.center
///   把 label 与 input 一起居中 —— 不需要额外 Align，也不会影响宽度约束；
/// - 多行：56dp 下限、12dp 垂直内边距、Row 顶部对齐、label 顶部微调。
class _FormFieldShell extends StatelessWidget {
  const _FormFieldShell({
    required this.label,
    required this.child,
    required this.singleLine,
  });

  final String label;
  final Widget child;
  final bool singleLine;

  @override
  Widget build(BuildContext context) {
    final sheetText = SheetText.of(context);
    return Container(
      constraints: BoxConstraints(
        minHeight: singleLine
            ? _kSingleLineFieldHeight
            : _kMultiLineFieldMinHeight,
      ),
      // 关键：Container 的 minHeight 只约束自身，不会把矮 child 撑开。
      // 单行 child（一行文字 ≈ 16dp）远小于 48dp 时，默认 alignment 会把
      // 它顶在上边缘 —— 这正是「input 顶到上边框」的真正原因。
      // 显式 centerLeft 保证 label 与 input 一起垂直居中。
      alignment: singleLine ? Alignment.centerLeft : null,
      decoration: AppDecorations.field(context),
      padding: EdgeInsets.symmetric(
        horizontal: _kFieldPaddingH,
        vertical: singleLine ? 0 : _kMultiLineFieldPaddingV,
      ),
      child: Row(
        crossAxisAlignment: singleLine
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: AppSheetSize.formLabelWidth,
            child: Padding(
              padding: EdgeInsets.only(top: singleLine ? 0 : _kLabelTopInset),
              child: Text(
                label,
                style: singleLine
                    ? sheetText.fieldLabelSingleLine
                    : sheetText.fieldLabel,
              ),
            ),
          ),
          const SizedBox(width: _kLabelGap),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// 单行文本输入行。
///
/// 与多行**显式区分三处**，不再共用一个 style / 一套对齐：
/// 1. 外壳 `Alignment.centerLeft` —— Container 的 minHeight 只撑自身，
///    不撑 child；以前只有 `crossAxisAlignment.center` 时，矮小的
///    TextFormField 仍被顶在上边缘，看起来「input 贴着上边框」；
/// 2. TextField 自身拿 `minHeight: 48` 约束 + `textAlignVertical.center`，
///    文字在输入框内部就垂直居中，不依赖外层猜位置；
/// 3. `fieldValueSingleLine` / `fieldLabelSingleLine` 把行高压到 1.0，
///    去掉多行用的 1.40 额外 leading（它会把单行文字往上推）。
///
/// 48dp 行高、零垂直内边距，上下留白由行高与文字高度差自然形成；
/// 不渲染字数统计；清除按钮只占行内右侧，不改变行高。
class SheetSingleLineFormField extends StatelessWidget {
  const SheetSingleLineFormField({
    super.key,
    required this.label,
    required this.controller,
    this.hintText,
    this.maxLength,
    this.showClearButton = false,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final String? hintText;
  final int? maxLength;
  final bool showClearButton;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String? value)? validator;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final text = SheetText.of(context);
    final p = SheetPalette.of(context);
    final cs = Theme.of(context).colorScheme;

    return _FormFieldShell(
      label: label,
      singleLine: true,
      // child 参数不会随文本变化重建，保证 FormFieldState / validator
      // 注册稳定；只有「清除按钮」这一个随输入变化的部分在 builder 里。
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        // 让 TextField 自身拿到 48dp 的最小高度，文字在它内部就居中，
        // 而不是靠外层去猜一个 16dp 小框该放哪。minHeight 而非固定
        // height：校验失败时 error 文案仍能把行撑高，不会被裁掉。
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: _kSingleLineFieldHeight,
          ),
          child: TextFormField(
            controller: controller,
            maxLength: maxLength,
            maxLines: 1,
            minLines: 1,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            validator: validator,
            onChanged: onChanged,
            // 与多行区分：height 1.0 + 垂直居中，不再带 1.40 的额外 leading。
            textAlignVertical: TextAlignVertical.center,
            style: text.fieldValueSingleLine,
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
              errorMaxLines: 1,
              hintStyle: text.fieldValueSingleLine.copyWith(
                color: p.mutedText.withValues(alpha: AppOpacity.hint),
              ),
              errorStyle: text.caption.copyWith(color: cs.error),
            ),
          ),
        ),
        builder: (context, value, field) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(child: field!),
              if (showClearButton && value.text.isNotEmpty)
                _ClearButton(controller: controller, color: p.mutedText),
            ],
          );
        },
      ),
    );
  }
}

/// 多行文本输入行。
///
/// label 顶部对齐首行文字，输入框按 minLines / maxLines 自然增高，
/// 字数统计在下方；这几项都会撑高容器，所以保留 56dp 下限 + 12dp
/// 垂直内边距，与单行的紧凑节奏明确区分。
class SheetMultiLineFormField extends StatelessWidget {
  const SheetMultiLineFormField({
    super.key,
    required this.label,
    required this.controller,
    this.hintText,
    this.maxLength,
    this.maxLines = 3,
    this.minLines = 2,
    this.showClearButton = false,
    this.showCounter = true,
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
  final int minLines;
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

    return _FormFieldShell(
      label: label,
      singleLine: false,
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(child: field!),
                  if (showClearButton && value.text.isNotEmpty)
                    _ClearButton(controller: controller, color: p.mutedText),
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
    );
  }
}

/// 清除按钮：两种文本行共用，48dp 无障碍热区 + 语义图标 + tooltip。
class _ClearButton extends StatelessWidget {
  const _ClearButton({required this.controller, required this.color});

  final TextEditingController controller;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: controller.clear,
      tooltip: '清空',
      icon: const Icon(AppIcons.clear, size: _kClearIconSize),
      color: color,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(
        width: kMinTapTarget,
        height: kMinTapTarget,
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
