import 'package:flutter/material.dart';
import 'package:yuan/screens/commons/image/image_picker_widget.dart';
import 'package:yuan/screens/commons/sheet/app_sheet_shell.dart';
import 'package:yuan/screens/commons/sheet/contents/form_sheet_content.dart';
import 'package:yuan/screens/commons/sheet/parts/sheet_inputs.dart';
import 'package:yuan/screens/commons/sheet/parts/sheet_primitives.dart';
import 'package:yuan/screens/commons/sheet/sheet_form_items.dart';
import 'package:yuan/service/image/image_category.dart';
import 'package:yuan/service/image/image_ref.dart';

import '../../../commons/image/app_image.dart';

// ── 组件私有内容（只服务本文件）────────────────────────────────
const int _kNameMaxLength = 12;
const int _kSubMaxLength = 60;
const int _kSubMaxLines = 3;
const int _kSubMinLines = 2;
const String _kNameHint = '怎么称呼你？';
const String _kSubHint = '一句话介绍自己，例如：月薪族，正在攒钱买车';
const String _kPrivacyNote = '头像仅保存在本设备，不会上传云端。';
const String _kEmptyNameError = '昵称不能为空';
const String _kSheetTitle = '编辑资料';
const String _kSaveLabel = '保存';

/// 【我的】→ 用户部分 → 编辑资料。
///
/// 【项目约定】所有「修改 / 新增」类 Sheet 一律用 [FormSheetContent]，
/// 由本函数直接声明 items；不再为每个业务新建 `XxxSheetContent` /
/// `XxxSheet` 包装组件。控件使用方式与样式（圆角容器、字号、清除按钮、
/// 字数统计、分隔线、头像整圆、保存失败不关闭）全部由公共组件负责。
///
/// 结构（构造期静态可读完，与 showCategoryEditorSheet 逐行同构）：
///   ① new 一个 [FormSheetController]；
///   ② header：取消 / 标题 / 保存（静态槽位，壳固定在顶端）；
///   ③ child：[FormSheetContent]，同一个 controller 传进去 + items 声明；
///   ④ await 壳的 show，弹层关闭后函数才返回。
///
/// 【唯一一处动态逻辑】顶栏「保存」要触发 [FormSheetContent] 内部的提交
/// 链路（校验 → await onSave → 成功才关闭）。header 是静态 Widget，拿不到
/// 组件内部的 FormState / 各 TextEditingController / 防连点标记，所以用
/// 一个显式句柄接起来：点保存 → controller.submit() → 内部 _submit()。
/// 完整工作逻辑写在 form_sheet_content.dart 的 [FormSheetController] 注释里。
/// 没有 InheritedWidget / Notifier / 跨帧注册。
Future<void> showEditProfileSheet(
  BuildContext context, {
  required String initialName,
  required String initialSub,
  required ImageRef? initialRef,
  required Future<void> Function(SheetFormValues values) onSave,
}) async {
  final formController = FormSheetController();
  await AppSheetShell.show<SheetFormValues>(
    context,
    header: SheetHeader(
      title: _kSheetTitle,
      centered: true,
      leading: const SheetCancelAction(),
      trailing: SheetTextAction(
        label: _kSaveLabel,
        emphasized: true,
        onTap: formController.submit,
      ),
    ),
    child: FormSheetContent(
      controller: formController,
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
    ),
  );
}
