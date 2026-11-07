import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:yuan/screens/commons/icons/app_icons.dart';

class UserAvatar extends StatelessWidget {
  final String? base64;

  const UserAvatar({super.key, required this.base64});

  @override
  Widget build(BuildContext context) {

    return ClipOval(
      child: SizedBox(
        width: 38,
        height: 38,
        child: base64 == null || base64 == ''
            ? FittedBox(
                fit: BoxFit.cover,
                child: Icon(
                  AppIcons.user,
                ),
              )
            : FittedBox(
                fit: BoxFit.cover,
                child: Image.memory(base64Decode(base64!)),
              ),
      ),
    );
  }
}
