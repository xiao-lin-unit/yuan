import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../database/category/category_record.dart';
import '../../../service/category_controller.dart';
import '../../../service/image/image_category.dart';
import '../../../service/image/image_ref.dart';
import '../../../service/image/image_validator.dart';
import '../../../styles/app_decorations.dart';
import '../../../styles/sheet_tokens.dart';
import '../../../styles/theme_tokens.dart';
import '../../commons/function/app_function_layout.dart';
import '../../commons/icon/app_icon_badge.dart';
import '../../commons/icons/app_icons.dart';
import '../../commons/image/app_image.dart';
import '../../commons/image/image_picker_widget.dart';
import '../../commons/sheet/app_sheet_shell.dart';
import '../../commons/sheet/contents/form_sheet_content.dart';
import '../../commons/sheet/parts/sheet_primitives.dart';
import '../../commons/sheet/sheet_form_items.dart';

// ── 组件私有内容（只服务本文件）────────────────────────────────
const String _kNameHint = '比如：早餐、宠物用品、房租';
const int _kNameMaxLength = 8;
const String _kPresetLock =
    '这是预定义分类，名字和图标可以改，但不能删除；不想看到它就直接隐藏。';
const String _kIconLabel = '图标 · 点选一个，或上传自己的图片';
const String _kUploadTip =
    '不传就用内置图标；上传的图片会按统一图片层压缩、落盘，数据库只存引用。';
const String _kOrderTip = '数字越小越靠前，记账时排在上面的更好点。';
const String _kNecessityTip =
    '算「失业能撑几个月」时，只统计标了「必须花的」分类。不打标记就不参与判断。';
const String _kStabilityTip =
    '标了「每月都有」的会计入每月固定收入，用来判断现金流是否健康。';
const int _kIconColumns = 8;
const double _kIconPreviewSize = 44;
const double _kIconCellSize = 34;

/// 打开分类编辑器（新增 / 编辑共用同一个入口）。
///
/// 【项目约定】所有「修改 / 新增」类 Sheet 一律用 [FormSheetContent]，
/// 由本函数直接声明 items；不新建 `XxxSheetContent` 之类的业务包装
/// 组件。「图标网格 / 排序输入 / 语义标记」三个特殊控件只是
/// [SheetFormCustomItem.builder] 里的私有字段，留在文件下半部分。
///
/// 结构（构造期静态可读完，与 showEditProfileSheet 逐行同构）：
///   ① 算出显示用排序号（1-based），供排序初值与提交兜底；
///   ② new 一个 [FormSheetController]；
///   ③ header：取消 / 标题 / 保存（静态槽位，壳固定在顶端）；
///   ④ child：[FormSheetContent]，同一个 controller 传进去 + items 声明；
///   ⑤ await 壳的 show，弹层关闭后函数才返回。
///
/// 【唯一一处动态逻辑】顶栏「保存」要触发 [FormSheetContent] 内部的提交
/// 链路（校验 → await _saveCategory → 成功才关闭）。header 是静态 Widget，
/// 拿不到组件内部的 FormState / 防连点标记，所以用显式句柄接起来：
/// 点保存 → controller.submit() → 内部 _submit()。
/// 工作逻辑与 showEditProfileSheet 完全相同，见 form_sheet_content.dart
/// 的 [FormSheetController] 注释。没有 Notifier / InheritedWidget / 跨帧注册。
Future<void> showCategoryEditorSheet(
  BuildContext context, {
  required CategoryKind kind,
  required CategoryController controller,
  CategoryRecord? category,
}) async {
  final CategoryRecord? editing = category;

  // ① 排序号：新增排末尾，编辑取当前位置（1-based）
  final List<CategoryRecord> siblings =
      controller.managed(kind, includeHidden: true);
  final int displayOrder = editing == null
      ? siblings.length + 1
      : siblings.indexWhere((CategoryRecord r) => r.id == editing.id) + 1;

  // ②③④ 与 showEditProfileSheet 逐行同构
  final formController = FormSheetController();
  await AppSheetShell.show<SheetFormValues>(
    context,
    header: SheetHeader(
      title: editing == null
          ? (kind == CategoryKind.expense ? '新增支出分类' : '新增收入分类')
          : '编辑分类',
      leading: const SheetCancelAction(),
      trailing: SheetTextAction(
        label: '保存',
        emphasized: true,
        onTap: formController.submit,
      ),
    ),
    child: FormSheetContent(
      controller: formController,
      onSubmit: (SheetFormValues values) => _saveCategory(
        controller: controller,
        kind: kind,
        category: editing,
        fallbackOrder: displayOrder,
        values: values,
      ),
      items: <SheetFormItem>[
        if (editing?.preset == true)
          const SheetFormNoteItem(
            key: 'presetLock',
            text: _kPresetLock,
            align: TextAlign.start,
          ),

        // ① 名称：单行 + 8 字上限 + 清除按钮 + 非空/重名校验
        SheetFormSingleLineTextItem(
          key: 'name',
          label: '分类名称',
          initialValue: editing?.name ?? '',
          hint: _kNameHint,
          maxLength: _kNameMaxLength,
          showClearButton: true,
          validator: (String value) {
            final String name = value.trim();
            if (name.isEmpty || name.length > _kNameMaxLength) {
              return '分类名要填 1 ~ $_kNameMaxLength 个字，太长了记账时显示不下。';
            }
            if (controller.nameExists(kind, name,
                excludeId: editing?.id)) {
              return '已经有同名分类「$name」了，换个名字。';
            }
            return null;
          },
        ),

        // ② 图标：内置矢量图标网格 / 上传图片（统一图片层）
        SheetFormCustomItem(
          key: 'icon',
          builder: (BuildContext context, ValueChanged<Object?> onChanged) =>
              _IconField(
            initial: editing?.icon ??
                const CategoryIcon(kind: CategoryIconKind.icon, value: 'other'),
            onChanged: onChanged,
          ),
        ),

        // ③ 排序：填 1~N 的数字，插到目标位置其余顺移
        SheetFormCustomItem(
          key: 'order',
          label: '排序',
          builder: (BuildContext context, ValueChanged<Object?> onChanged) =>
              _OrderField(
            initial: displayOrder,
            max: siblings.length + (editing == null ? 1 : 0),
            onChanged: onChanged,
          ),
        ),

        // ④ 显示开关（隐藏后记账时不会出现，已记过的账不受影响）
        SheetFormToggleItem(
          key: 'visible',
          label: '在记账时显示',
          initialValue: !(editing?.hidden ?? false),
        ),

        // ⑤ 语义标记：支出「必须花的 / 可省的」，收入「每月都有 / 偶尔才有」
        SheetFormCustomItem(
          key: kind == CategoryKind.expense ? 'necessity' : 'stability',
          label: kind == CategoryKind.expense ? '开支性质' : '收入稳定性',
          builder: (BuildContext context, ValueChanged<Object?> onChanged) =>
              _ChoiceField(
            options: kind == CategoryKind.expense
                ? const <AppSegmentOption<String>>[
                    AppSegmentOption<String>(value: 'unset', label: '不标记'),
                    AppSegmentOption<String>(value: 'must', label: '必须花的'),
                    AppSegmentOption<String>(value: 'flex', label: '可省的'),
                  ]
                : const <AppSegmentOption<String>>[
                    AppSegmentOption<String>(value: 'unset', label: '不标记'),
                    AppSegmentOption<String>(value: 'fixed', label: '每月都有'),
                    AppSegmentOption<String>(
                        value: 'occasional', label: '偶尔才有'),
                  ],
            initial: kind == CategoryKind.expense
                ? (editing?.necessity.dbValue ?? 'unset')
                : (editing?.stability.dbValue ?? 'unset'),
            tip: kind == CategoryKind.expense ? _kNecessityTip : _kStabilityTip,
            onChanged: onChanged,
          ),
        ),
      ],
    ),
  );
}

/// 分类表单的提交逻辑（本文件唯一一处业务动态逻辑）。
///
/// 工作逻辑：由 [FormSheetContent] 校验通过后回调 → 从 [SheetFormValues]
/// 按 key 取值（用户没动过的字段用编辑对象初值兜底）→ `await controller.save`
/// → 成功才由公共组件关闭弹层；抛异常则公共组件提示且弹窗保持打开。
/// 图片落盘 / 删旧图的两阶段提交在 CategoryController 内部完成。
Future<void> _saveCategory({
  required CategoryController controller,
  required CategoryKind kind,
  required CategoryRecord? category,
  required int fallbackOrder,
  required SheetFormValues values,
}) async {
  final String name = values.text('name').trim();

  // 用户没动过的字段用编辑对象的初值兜底（FormSheetValues 里是 null）。
  final CategoryIconInput icon =
      values.raw('icon') as CategoryIconInput? ?? _initialIconFor(category);
  final int targetIndex = ((values.raw('order') as int?) ?? fallbackOrder) - 1;
  final bool visible = values.flag('visible');
  final String mark = (values.raw(kind == CategoryKind.expense
          ? 'necessity'
          : 'stability') as String?) ??
      'unset';

  await controller.save(
    id: category?.id,
    kind: kind,
    name: name,
    icon: icon,
    targetIndex: targetIndex < 0 ? 0 : targetIndex,
    hidden: !visible,
    necessity: kind == CategoryKind.expense
        ? CategoryNecessity.fromDb(mark)
        : CategoryNecessity.unset,
    stability: kind == CategoryKind.income
        ? CategoryStability.fromDb(mark)
        : CategoryStability.unset,
  );
}

/// 编辑对象没动图标时的兜底值（用户不改图标 → FormSheetValues 里是 null）。
CategoryIconInput _initialIconFor(CategoryRecord? category) {
  final CategoryIcon icon = category?.icon ??
      const CategoryIcon(kind: CategoryIconKind.icon, value: 'other');
  return switch (icon.kind) {
    CategoryIconKind.icon => CategoryIconInput(
        kind: CategoryIconKind.icon,
        iconKey: icon.value,
      ),
    CategoryIconKind.image => CategoryIconInput(
        kind: CategoryIconKind.image,
        imageRef: icon.imageRef,
      ),
    CategoryIconKind.text => CategoryIconInput(
        kind: CategoryIconKind.text,
      ),
  };
}

/// 图标选择：内置矢量图标网格 + 上传图片 / 恢复默认。
///
/// 【局部状态工作逻辑】
///   · `_imageMode` 决定预览区显示「统一单图选择器」还是内置图标徽章；
///   · 点内置图标 → 切回内置模式、清空待上传图片 → 上抛 CategoryIconInput；
///   · 上传新图 → SingleImagePickerWidget 回传 ImageCandidate → 保存候选、
///     上抛；点它右上角的 ❌ 回传 null → 回到内置模式；
///   · 组件只把「意图」上抛，图片落盘/删旧图由 CategoryController 的
///     两阶段提交负责，这里不碰文件系统、不碰数据库。
class _IconField extends StatefulWidget {
  const _IconField({required this.initial, required this.onChanged});

  final CategoryIcon initial;
  final ValueChanged<Object?> onChanged;

  @override
  State<_IconField> createState() => _IconFieldState();
}

class _IconFieldState extends State<_IconField> {
  late String _iconKey;
  ImageRef? _imageRef;
  ImageCandidate? _candidate;
  late bool _imageMode;

  @override
  void initState() {
    super.initState();
    _iconKey = widget.initial.kind == CategoryIconKind.icon
        ? widget.initial.value
        : 'other';
    _imageRef = widget.initial.imageRef;
    _imageMode = widget.initial.kind == CategoryIconKind.image;
  }

  CategoryIconInput _input() => _imageMode
      ? CategoryIconInput(
          kind: CategoryIconKind.image,
          imageRef: _candidate == null ? _imageRef : null,
          candidate: _candidate,
        )
      : CategoryIconInput(
          kind: CategoryIconKind.icon,
          iconKey: _iconKey,
        );

  void _emit() => widget.onChanged(_input());

  void _pickBuiltIn(String key) {
    setState(() {
      _iconKey = key;
      _imageMode = false;
      _candidate = null;
      _imageRef = null;
    });
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final p = SheetPalette.of(context);
    final cs = Theme.of(context).colorScheme;
    final SheetText text = SheetText.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(_kIconLabel, style: text.sectionLabel),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: <Widget>[
            _imageMode
                ? SingleImagePickerWidget(
                    initialRef: _imageRef,
                    category: ImageCategory.categoryIcon,
                    size: _kIconPreviewSize,
                    shape: ImageShape.circle,
                    placeholder: _BuiltInPreview(iconKey: _iconKey),
                    onImageChanged: (Object? value) {
                      setState(() {
                        if (value is ImageCandidate) {
                          _candidate = value;
                        } else {
                          // ❌ 清空 → 回到内置图标模式
                          _candidate = null;
                          _imageRef = null;
                          _imageMode = false;
                        }
                      });
                      _emit();
                    },
                  )
                : GestureDetector(
                    onTap: () {
                      setState(() => _imageMode = true);
                      _emit();
                    },
                    child: _BuiltInPreview(iconKey: _iconKey),
                  ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _MiniButton(
                    label: _imageMode ? '恢复默认图标' : '上传图片',
                    emphasized: !_imageMode,
                    onTap: () {
                      setState(() {
                        if (_imageMode) {
                          _imageMode = false;
                          _candidate = null;
                          _imageRef = null;
                        } else {
                          _imageMode = true;
                        }
                      });
                      _emit();
                    },
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(_kUploadTip, style: text.caption),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _kIconColumns,
            mainAxisSpacing: AppSpacing.xxs,
            crossAxisSpacing: AppSpacing.xxs,
          ),
          itemCount: AppIcons.categoryIconKeys.length,
          itemBuilder: (BuildContext context, int i) {
            final String key = AppIcons.categoryIconKeys[i];
            final bool selected = !_imageMode && key == _iconKey;
            return GestureDetector(
              onTap: () => _pickBuiltIn(key),
              child: Container(
                height: _kIconCellSize,
                decoration: BoxDecoration(
                  color: selected
                      ? p.selectedTint
                      : cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppRadius.small),
                  border: selected
                      ? Border.all(color: cs.primary, width: AppBorder.focused)
                      : null,
                ),
                alignment: Alignment.center,
                child: Icon(
                  AppIcons.categoryIcon(key),
                  size: AppIconSize.medium,
                  color: selected ? cs.primary : cs.onSurfaceVariant,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _BuiltInPreview extends StatelessWidget {
  const _BuiltInPreview({required this.iconKey});

  final String iconKey;

  @override
  Widget build(BuildContext context) => AppIconBadge(
        icon: AppIcons.categoryIcon(iconKey),
        size: _kIconPreviewSize,
        iconSize: AppIconSize.medium,
        tone: null,
        index: 0,
      );
}

/// 排序输入：只允许 1~max 的数字，换成 0-based 下标上抛。
class _OrderField extends StatefulWidget {
  const _OrderField({
    required this.initial,
    required this.max,
    required this.onChanged,
  });

  final int initial;
  final int max;
  final ValueChanged<Object?> onChanged;

  @override
  State<_OrderField> createState() => _OrderFieldState();
}

class _OrderFieldState extends State<_OrderField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.initial}');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String raw) {
    final int parsed = int.tryParse(raw) ?? 1;
    final int clamped = parsed.clamp(1, widget.max < 1 ? 1 : widget.max).toInt();
    // 0-based 目标下标直接交给 Controller.save(targetIndex)。
    widget.onChanged(clamped);
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            decoration: AppDecorations.field(context),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              onChanged: _onChanged,
              style: SheetText.of(context).fieldValue,
              decoration: const InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
                contentPadding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(_kOrderTip, style: SheetText.of(context).caption),
        ],
      );
}

/// 语义标记：单选三段（不打标记 / A / B）。
class _ChoiceField extends StatefulWidget {
  const _ChoiceField({
    required this.options,
    required this.initial,
    required this.tip,
    required this.onChanged,
  });

  final List<AppSegmentOption<String>> options;
  final String initial;
  final String tip;
  final ValueChanged<Object?> onChanged;

  @override
  State<_ChoiceField> createState() => _ChoiceFieldState();
}

class _ChoiceFieldState extends State<_ChoiceField> {
  late String _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initial;
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SegmentedButton<String>(
            segments: <ButtonSegment<String>>[
              for (final AppSegmentOption<String> o in widget.options)
                ButtonSegment<String>(value: o.value, label: Text(o.label)),
            ],
            selected: <String>{_value},
            showSelectedIcon: false,
            onSelectionChanged: (Set<String> next) {
              if (next.isEmpty) return;
              setState(() => _value = next.first);
              widget.onChanged(_value);
            },
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(widget.tip, style: SheetText.of(context).caption),
        ],
      );
}

/// 编辑器里的小按钮（上传图片 / 恢复默认）。
class _MiniButton extends StatelessWidget {
  const _MiniButton({
    required this.label,
    required this.onTap,
    this.emphasized = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: kMinTapTarget - AppSpacing.sm,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: emphasized ? cs.primaryContainer : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadius.small + 2),
        ),
        child: Text(
          label,
          style: SheetText.of(context).chipLabel.copyWith(
                color: emphasized ? cs.onPrimaryContainer : cs.onSurfaceVariant,
              ),
        ),
      ),
    );
  }
}
