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
/// - 单行：label 与 child **各自明确占 48dp**，两侧内部再各自把一行文字
///   居中。容器、label、input 三者同高，不存在「框比内容高」的错位，
///   也不依赖 `Container.alignment`（child 与容器等高时它是零位移）。
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
      // 不再用 Container.alignment：单行 label 与 child 都会明确占 48dp，
      // 居中的是「48dp 里的 19dp 文字」，不是「48dp 容器里的 48dp child」。
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
            height: singleLine ? _kSingleLineFieldHeight : null,
            child: singleLine
                // Align 给 child loose 约束 → Text 保持一行高，被精确居中。
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      label,
                      style: sheetText.fieldLabelSingleLine,
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.only(top: _kLabelTopInset),
                    child: Text(label, style: sheetText.fieldLabel),
                  ),
          ),
          const SizedBox(width: _kLabelGap),
          Expanded(
            // 单行 child 明确 48dp：内层 Row 因此恒为 48，
            // crossAxisAlignment.center 才有稳定空间把 TextField 居中。
            child: singleLine
                ? SizedBox(height: _kSingleLineFieldHeight, child: child)
                : child,
          ),
        ],
      ),
    );
  }
}

/// 单行文本输入行。
///
/// ## 为什么之前一直贴顶（★ 真正的根因）
///
/// 全局 `ThemeSetting.inputDecorationTheme` 设了
/// `constraints: BoxConstraints(minHeight: AppLayout.fieldMinHeight /* 56 */)`。
/// `InputDecoration.applyDefaults()` 会把主题里**所有 null 字段**填进每个
/// decoration，其中就包括 `constraints`；`InputDecorator.build` 末尾看到
/// `decoration.constraints != null` 就再包一层 `ConstrainedBox`。
///
/// 结果：单行 TextFormField 被强制 **56dp 高**，而 `isCollapsed` 的
/// `containerHeight` 仍只有一个行高 ≈19dp → 「56dp 框 + 顶部一行字 +
/// 37dp 空白」。多行 `minLines: 2` 的内容 + padding 正好约 56dp，
/// 把框填满了，所以**只有单行贴顶、多行正常**。
///
/// 之前三种居中全部失效，因为它们动的都是外层：
/// `ConstrainedBox(minHeight: 48)`、`Container.alignment`、
/// `textAlignVertical.center` —— 而 56dp 是 TextField **自己**的高度，
/// 外层再怎么摆一个已经贴顶的 56dp 框都没用。
///
/// 修复就是单行 decoration 里显式写 `constraints: const BoxConstraints()`
/// 覆盖主题值。这一行是本轮最关键的一处。
///
/// ## 这一版（完全不依赖 InputDecorator 内部行为）
///
/// 1. `InputDecoration(isCollapsed: true, contentPadding: zero)` →
///    TextFormField 的高度**就是一个行高**；
/// 2. 外壳把 label 与 child 各自放进**明确 48dp** 的盒子，两侧内部用
///    `Align` / `Row.crossAxisAlignment.center` 把 19dp 文字居中；
/// 3. builder 的 Row 里放一个**恒定 48dp 占位**（清除按钮不显示时也在），
///    空输入时不会退化成 19dp 行又把文字贴回顶部。
///
/// 手写 `isCollapsed` 而非 `InputDecoration.collapsed` 构造：后者禁止
/// `errorText`，validator 的错误提示会失效（3.47 源码已核对）。
/// 报错时 error 文案自然撑高，外层跟着长，不裁切。
/// `fieldValueSingleLine`（height 1.0）避免多行 1.40 行距的 leading。
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
        // isCollapsed: true → InputDecorator 高度就是一个行高，
        // 没有内部 padding / minContainerHeight / densityOffset 参与。
        child: TextFormField(
          controller: controller,
          maxLength: maxLength,
          maxLines: 1,
          minLines: 1,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          validator: validator,
          onChanged: onChanged,
          style: text.fieldValueSingleLine,
          decoration: InputDecoration(
            isCollapsed: true,
            contentPadding: EdgeInsets.zero,
            // ★ 真正的根因：全局 InputDecorationTheme 设了
            //   constraints: BoxConstraints(minHeight: 56)，
            // applyDefaults() 会把它注入到每一个没显式写 constraints 的
            // decoration；InputDecorator.build 末尾再包一层 ConstrainedBox。
            // 于是单行 TextFormField 被强制 56dp 高，而 isCollapsed 的
            // containerHeight 仍只有一个行高 ≈19dp → 文字永远贴在框顶。
            // 多行内容 2~3 行 + padding 正好约 56dp，所以只有单行出问题。
            // 显式给空约束覆盖掉主题的 56dp，TextField 才会只有一行高。
            constraints: const BoxConstraints(),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            filled: false,
            isDense: false,
            hintText: hintText,
            // 空 counter 用零高度 widget，避免 `counterText: ''` 生成
            // 一个空 Text 仍旧占一行高度。
            counter: const SizedBox.shrink(),
            errorMaxLines: 1,
            hintStyle: text.fieldValueSingleLine.copyWith(
              color: p.mutedText.withValues(alpha: AppOpacity.hint),
            ),
            errorStyle: text.caption.copyWith(color: cs.error),
          ),
        ),
        builder: (context, value, field) {
          final bool clear = showClearButton && value.text.isNotEmpty;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(child: field!),
              // 恒定 48dp 占位：空输入时 Row 也是 48dp，
              // crossAxisAlignment.center 才有空间把 19dp TextField 居中。
              SizedBox(
                width: _kSingleLineFieldHeight,
                height: _kSingleLineFieldHeight,
                child: clear
                    ? _ClearButton(controller: controller, color: p.mutedText)
                    : null,
              ),
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
