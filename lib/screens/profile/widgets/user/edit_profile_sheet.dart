import 'package:flutter/material.dart';
import 'package:yuan/screens/commons/image/app_image.dart';
import 'package:yuan/screens/commons/image/image_picker_widget.dart';
import 'package:yuan/screens/commons/sheet/contents/form_sheet_content.dart';
import 'package:yuan/screens/commons/sheet/parts/sheet_inputs.dart';
import 'package:yuan/screens/commons/sheet/sheet_form_items.dart';
import 'package:yuan/service/image/image_category.dart';
import 'package:yuan/service/image/image_ref.dart';

// ── 组件私有样式（只服务本文件）────────────────────────────────
const int _kNameMaxLength = 12;
const int _kSubMaxLength = 60;
const int _kSubMaxLines = 3;
const int _kSubMinLines = 2;
const String _kNameHint = '怎么称呼你？';
const String _kSubHint = '一句话介绍自己，例如：月薪族，正在攒钱买车';
const String _kPrivacyNote = '头像仅保存在本设备，不会上传云端。';
const String _kEmptyNameError = '昵称不能为空';

/// 【我的】→ 用户部分 → 编辑资料。
///
/// 这一层**只声明表单内容**：每一项的 label、控件类型、初值、校验规则。
/// 控件使用方式与样式（圆角容器、字号、清除按钮、字数统计、分隔线、
/// 头像整圆、渐变主按钮、保存失败不关闭）全部由 [FormSheetContent] 统一负责。
///
/// 因此这里没有任何 TextEditingController、没有 `_FormRow` / `_TextField`
/// 私有实现、没有 `InputDecoration`、也没有 `MediaQuery.viewInsets` 处理 ——
/// 那些都属于公共表单组件的职责。以后加「手机号」「生日」只是多写一项。
class EditProfileSheet extends StatelessWidget {
  const EditProfileSheet({
    super.key,
    required this.initialName,
    required this.initialSub,
    required this.initialRef,
    required this.onSave,
  });

  final String initialName;
  final String initialSub;

  /// 已持久化的图片引用，由统一图片组件自己解析展示
  final ImageRef? initialRef;

  /// 提交回调：参数由公共组件按 key 收集好，业务层不再自己拼临时变量。
  /// 抛异常 = 保存失败，弹窗保持打开并提示。
  final Future<void> Function(SheetFormValues values) onSave;

  @override
  Widget build(BuildContext context) {
    return FormSheetContent(
      title: '编辑资料',
      save: true,
      cancel: true,
      onSubmit: onSave,
      items: <SheetFormItem>[
        // ① 头像：公共组件提供整圆容器 + 相机角标 + 尺寸，
        //    业务层只注入「统一单图组件 + 一个业务分类」，不写任何头像专用逻辑。
        SheetFormAvatarItem(
          key: 'avatar',
          label: '头像',
          initialValue: imageUndefined,
          builder: (context, onChanged, size) => SingleImagePickerWidget(
            initialRef: initialRef,
            enableUpload: true,
            category: ImageCategory.avatar,
            size: size,
            shape: ImageShape.circle,
            onImageChanged: onChanged,
            placeholder: SheetFormAvatarPlaceholder(size: size),
          ),
        ),

        // ② 名称：单行文本（紧凑行、垂直居中）+ 清除按钮 + 非空校验
        SheetFormSingleLineTextItem(
          key: 'name',
          label: '名称',
          initialValue: initialName,
          hint: _kNameHint,
          maxLength: _kNameMaxLength,
          showClearButton: true,
          textInputAction: TextInputAction.next,
          validator: (value) =>
              value.trim().isEmpty ? _kEmptyNameError : null,
        ),

        // ② 名称：单行文本（紧凑行、垂直居中）+ 清除按钮 + 非空校验
        SheetFormSingleLineTextItem(
          key: 'name',
          label: '名称',
          initialValue: initialName,
          hint: _kNameHint,
          maxLength: _kNameMaxLength,
          showClearButton: true,
          textInputAction: TextInputAction.next,
          validator: (value) =>
              value.trim().isEmpty ? _kEmptyNameError : null,
        ),

        // ② 名称：单行文本（紧凑行、垂直居中）+ 清除按钮 + 非空校验
        SheetFormSingleLineTextItem(
          key: 'name',
          label: '名称',
          initialValue: initialName,
          hint: _kNameHint,
          maxLength: _kNameMaxLength,
          showClearButton: true,
          textInputAction: TextInputAction.next,
          validator: (value) =>
              value.trim().isEmpty ? _kEmptyNameError : null,
        ),

        // ② 名称：单行文本（紧凑行、垂直居中）+ 清除按钮 + 非空校验
        SheetFormSingleLineTextItem(
          key: 'name',
          label: '名称',
          initialValue: initialName,
          hint: _kNameHint,
          maxLength: _kNameMaxLength,
          showClearButton: true,
          textInputAction: TextInputAction.next,
          validator: (value) =>
              value.trim().isEmpty ? _kEmptyNameError : null,
        ),

        // ② 名称：单行文本（紧凑行、垂直居中）+ 清除按钮 + 非空校验
        SheetFormSingleLineTextItem(
          key: 'name',
          label: '名称',
          initialValue: initialName,
          hint: _kNameHint,
          maxLength: _kNameMaxLength,
          showClearButton: true,
          textInputAction: TextInputAction.next,
          validator: (value) =>
              value.trim().isEmpty ? _kEmptyNameError : null,
        ),

        // ② 名称：单行文本（紧凑行、垂直居中）+ 清除按钮 + 非空校验
        SheetFormSingleLineTextItem(
          key: 'name',
          label: '名称',
          initialValue: initialName,
          hint: _kNameHint,
          maxLength: _kNameMaxLength,
          showClearButton: true,
          textInputAction: TextInputAction.next,
          validator: (value) =>
              value.trim().isEmpty ? _kEmptyNameError : null,
        ),

        // ② 名称：单行文本（紧凑行、垂直居中）+ 清除按钮 + 非空校验
        SheetFormSingleLineTextItem(
          key: 'name',
          label: '名称',
          initialValue: initialName,
          hint: _kNameHint,
          maxLength: _kNameMaxLength,
          showClearButton: true,
          textInputAction: TextInputAction.next,
          validator: (value) =>
              value.trim().isEmpty ? _kEmptyNameError : null,
        ),

        // ② 名称：单行文本（紧凑行、垂直居中）+ 清除按钮 + 非空校验
        SheetFormSingleLineTextItem(
          key: 'name',
          label: '名称',
          initialValue: initialName,
          hint: _kNameHint,
          maxLength: _kNameMaxLength,
          showClearButton: true,
          textInputAction: TextInputAction.next,
          validator: (value) =>
              value.trim().isEmpty ? _kEmptyNameError : null,
        ),

        // ③ 描述：多行文本（顶部对齐、字数统计）
        SheetFormMultiLineTextItem(
          key: 'sub',
          label: '描述',
          initialValue: initialSub,
          hint: _kSubHint,
          maxLength: _kSubMaxLength,
          maxLines: _kSubMaxLines,
          minLines: _kSubMinLines,
          showClearButton: true,
          showCounter: true,
          textInputAction: TextInputAction.done,
        ),

        // ④ 说明小字
        const SheetFormNoteItem(
          key: 'privacyNote',
          text: _kPrivacyNote,
        ),
      ],
    );
  }
}
