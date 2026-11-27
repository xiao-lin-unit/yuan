import 'package:material_ui/material_ui.dart';
import 'package:yuan/screens/commons/icons/app_icons.dart';
import 'package:yuan/styles/app_decorations.dart';
import 'package:yuan/styles/sheet_tokens.dart';
import 'package:yuan/styles/theme_tokens.dart';

// ── 组件私有样式（只服务本文件，全部引用全局令牌）──────────────
/// 单行高度取表单行令牌（50dp），不跟着多行 / 独立输入框的全局
/// minHeight 走。「单行看起来过高」的根因就是两种控件共用一个 minHeight。
const double _kSingleLineFieldHeight = AppSheetSize.formRowHeight;
const double _kMultiLineFieldMinHeight = AppLayout.fieldMinHeight;
const double _kMultiLineFieldPaddingV = AppSpacing.xs;
const double _kFieldPaddingH = AppSpacing.sm;
const double _kLabelGap = AppSpacing.sm;
/// 多行 label 的顶部偏移 = 右侧框垂直内距(8) + 输入文字首行 leading(≈2)，
/// 保证 label 与输入框首行文字齐平，而不是齐框顶。
const double _kLabelTopInset = _kMultiLineFieldPaddingV + 2;
const double _kSwitchRowMinHeight = AppSheetSize.formRowHeight;
const double _kClearIconSize = AppIconSize.small;
const double _kCounterGap = AppSpacing.xxs;

/// 聚焦输入框时，Flutter 会用 `scrollPadding` 把输入框滚进可见区。
/// 默认只有 20dp，键盘弹出时远不够 —— 输入框会被滚到 viewport 底部
/// （键盘后面）却仍被判定为「可见」。
///
/// 取 `max(实际键盘高, 兜底值)`：兜底值覆盖中文输入法工具栏/候选栏
/// 导致的 viewInsets 滞后或偏小；无键盘时回到一个接近默认的小值，
/// 不改变平时的滚动手感。
double _keyboardScrollPadding(BuildContext context) {
  final double raw = MediaQuery.viewInsetsOf(context).bottom;
  if (raw <= 0) return AppSpacing.md;
  return raw > AppSheetSize.keyboardScrollPadding
      ? raw
      : AppSheetSize.keyboardScrollPadding;
}

/// 两种文本行共用的**行骨架**（不画背景）。
///
/// ★ 本轮的关键统一：label **一律站在输入框外面**。
/// 旧版把「整行灰底」画在这个外壳的 Container 上，于是单行 / 多行文本的
/// label 落在灰底里；而标签组、下拉、开关走 [SheetFormLabeledRow] /
/// [SheetSwitchRow]，label 在灰底外。同一张表单里两种 label 位置混着，
/// 就是「有的 label 在灰色背景内、有的在外面」的根因。
///
/// 现在外壳只负责「左 label 列 + 右内容区」的对齐，背景装饰下沉到
/// [_FieldBox] 且**只包右侧控件**；所有表单项的 label 就都站在框外，
/// 与下拉 / 标签组 / 开关完全一致。
///
/// 统一了「原来 label 没固定宽、标签组却有独立列宽」的错位：
/// 单行 / 多行 / 标签组 / 自定义项全部用 `AppSheetSize.formLabelWidth`。
///
/// [singleLine] 只决定对齐方式：
/// - 单行：label 与右侧框各占一行高，文字各自居中；
/// - 多行：顶部对齐，右侧框按内容自然增高，label 顶部微调对齐首行文字。
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
    return Row(
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
          child: _FieldBox(singleLine: singleLine, child: child),
        ),
      ],
    );
  }
}

/// 只包右侧控件的输入框外壳：**label 不进来**。
///
/// 装饰走全局 `AppDecorations.field`（亮底 + 可见细框），所以文本输入、
/// 下拉、搜索框、自定义字段的边界感完全一致；label 一律留在框外。
class _FieldBox extends StatelessWidget {
  const _FieldBox({required this.singleLine, required this.child});

  final bool singleLine;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        constraints: BoxConstraints(
          minHeight: singleLine
              ? _kSingleLineFieldHeight
              : _kMultiLineFieldMinHeight,
        ),
        decoration: AppDecorations.field(context),
        padding: EdgeInsets.symmetric(
          horizontal: _kFieldPaddingH,
          vertical: singleLine ? 0 : _kMultiLineFieldPaddingV,
        ),
        // 用 minHeight 而不是固定 height：validator 的 error 文案把
        // TextField 撑高时，整个框跟着长，不裁切。
        child: singleLine
            ? ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: _kSingleLineFieldHeight,
                ),
                child: child,
              )
            : child,
      );
}

/// 单行文本输入行。
///
/// ## 为什么之前一直贴顶（★ 真正的根因）
///
/// 全局 `ThemeSetting.inputDecorationTheme` 设了
/// `constraints: BoxConstraints(minHeight: AppLayout.fieldMinHeight)`。
/// `InputDecoration.applyDefaults()` 会把主题里**所有 null 字段**填进每个
/// decoration，其中就包括 `constraints`；`InputDecorator.build` 末尾看到
/// `decoration.constraints != null` 就再包一层 `ConstrainedBox`。
///
/// 结果：单行 TextFormField 被强制撑到全局 minHeight，而 `isCollapsed` 的
/// `containerHeight` 仍只有一个行高 → 「高框 + 顶部一行字 + 一大截空白」。
/// 多行内容本来就会把框填满，所以**只有单行贴顶**。
///
/// 之前三种居中全部失效，因为它们动的都是外层：
/// `ConstrainedBox(minHeight: 48)`、`Container.alignment`、
/// `textAlignVertical.center` —— 而那个 minHeight 是 TextField **自己**
/// 的高度，外层再怎么摆一个已经贴顶的框都没用。
///
/// 修复就是单行 decoration 里显式写 `constraints: const BoxConstraints()`
/// 覆盖主题值。这一行是本轮最关键的一处。
///
/// ## 这一版（完全不依赖 InputDecorator 内部行为）
///
/// 1. `InputDecoration(isCollapsed: true, contentPadding: zero)` →
///    TextFormField 的高度**就是一个行高**；
/// 2. 外壳把 label 与 child 各自放进**明确一行高**的盒子，两侧内部用
///    `Align` / `Row.crossAxisAlignment.center` 把文字居中；
/// 3. builder 的 Row 里放一个**恒定行高占位**（清除按钮不显示时也在），
///    空输入时不会退化成一个行高又把文字贴回顶部。
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
          // 聚焦时把本行滚到键盘上方，而不是滚到 viewport 底部（键盘后）。
          scrollPadding: EdgeInsets.only(
            bottom: _keyboardScrollPadding(context),
          ),
          style: text.fieldValueSingleLine,
          decoration: InputDecoration(
            isCollapsed: true,
            contentPadding: EdgeInsets.zero,
            // ★ 真正的根因：全局 InputDecorationTheme 设了 minHeight，
            // applyDefaults() 会把它注入到每一个没显式写 constraints 的
            // decoration；InputDecorator.build 末尾再包一层 ConstrainedBox。
            // 于是单行 TextFormField 被强制撑高，而 isCollapsed 的
            // containerHeight 仍只有一个行高 → 文字永远贴在框顶。
            // 多行内容 2~3 行 + padding 本就会填满，所以只有单行出问题。
            // 显式给空约束覆盖掉主题的 minHeight，TextField 才会只有一行高。
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
              // 恒定行高占位：空输入时 Row 也保持整行高，
              // crossAxisAlignment.center 才有空间把 TextField 居中。
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
/// 字数统计在下方；这几项都会撑高容器，所以保留全局 minHeight 下限 +
/// 较小的垂直内边距，与单行的紧凑节奏明确区分。
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
          // 与单行共用一份兜底逻辑：聚焦「描述」这类靠下的输入框时，
          // 自动滚到键盘上方，且滚动 extent 足够带上它下面的字数统计。
          scrollPadding: EdgeInsets.only(
            bottom: _keyboardScrollPadding(context),
          ),
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

/// 清除按钮：两种文本行共用，与表单行同高的无障碍热区 + 语义图标 + tooltip。
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
      constraints: BoxConstraints.tightFor(
        width: _kSingleLineFieldHeight,
        height: _kSingleLineFieldHeight,
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
/// 与 [_FormFieldShell] 共用同一条约定：**label 永远在框外**，右侧控件
/// 自己带 `AppDecorations.field` 或 chip 底色。标签列宽来自全局令牌
/// `AppSheetSize.formLabelWidth`，全软件表单对齐一致。
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
            child: Text(label!, style: SheetText.of(context).formLabel),
          ),
        ),
        content,
      ],
    );
  }
}

/// 开关行（「设为公开」）。label 与其它表单项一样站在框外，右侧是
/// Switch（无输入框容器，属于控件形态差异，不是 label 位置差异）。
/// 行高统一取 `AppSheetSize.formRowHeight`，避免和文本行错开一格。
/// Switch 走 ThemeData 的 M3 默认样式，会自动跟随当前 ColorScheme。
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
              style: SheetText.of(context).formLabel,
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
/// 刻意不套 `ClipOval`，也**不用** `Material(shape: CircleBorder())`：
/// 注入的图片组件把删除角标放在右上角并溢出到圆外（top/right = -6），
/// 绘制上不能裁它，命中判定更不能裁 —— 根因与修法见 build 里
/// [Positioned.fill] 上方的注释。圆形底色由 `DecoratedBox` 只画不裁。
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
            // 圆形底只负责「画」，不做任何形状裁剪。
            //
            // 【为什么不能用 Material(shape: CircleBorder())】
            // Material 会生成 PhysicalShape(clipper: ShapeBorderClipper(shape))，
            // 而 RenderPhysicalShape.hitTest 用这个 Path 判断命中，**与
            // clipBehavior 无关**（clipBehavior 只管 paint 是否裁剪）。
            // 注入的图片组件把删除角标放在右上角并溢出到圆外（top/right = -6）：
            // 那里画得出来，却落在圆形 Path 之外 → hitTest 直接返回 false，
            // 整棵 content 子树收不到点击，表现为「❌ 看得见、点不动」。
            // 所以底色改用 DecoratedBox（不裁剪命中）；Material 仅在需要
            // InkWell 时作为宿主出现，且不设 shape（默认矩形覆盖整个 96×96）。
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: p.unselectedTint,
                  shape: BoxShape.circle,
                ),
                child: onTap == null
                    ? content
                    : Material(
                        color: Colors.transparent,
                        clipBehavior: Clip.none,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: onTap,
                          child: content,
                        ),
                      ),
              ),
            ),
            // 相机角标是纯装饰：显式忽略指针，避免以后给它加子节点时
            // 意外挡住右上角删除角标的点击。
            Positioned(
              right: 0,
              bottom: 0,
              child: IgnorePointer(
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
            ),
          ],
        ),
      ),
    );
  }
}
