import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:yuan/screens/commons/icons/app_icons.dart';

import '../../../commons/image/image_picker_widget.dart';

class UserAvatar extends StatelessWidget {
  final String? avatar;

  const UserAvatar({super.key, required this.avatar});

  @override
  Widget build(BuildContext context) {

    return ClipOval(
      child: SizedBox(
        width: 38,
        height: 38,
        child: avatar == null || avatar == ''
            ? FittedBox(
                fit: BoxFit.cover,
                child: Icon(
                  AppIcons.user,
                ),
              )
            : FittedBox(
                fit: BoxFit.cover,
                child: SingleImagePickerWidget(
                  initialBase64: avatar,
                  enableUpload: false,
                  size: 56,
                  shape: ImageShape.circle,
                  onImageChanged: (_) {},
                ),
              ),
      ),
    );
  }
}
