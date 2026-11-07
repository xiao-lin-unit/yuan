import 'package:flutter/material.dart';
import '../styles/app_styles.dart';

/// 列表项数据模型：新增功能只需在分区组件的数据数组里加一条
class MenuItemData {
  final String emoji;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final String? key;

  const MenuItemData({
    required this.emoji,
    required this.title,
    this.subtitle,
    this.onTap,
    this.key,
  });
}

/// 公共单项组件：emoji + 标题 + 副标题 + 箭头（对应 .menu-item）
class MenuItem extends StatelessWidget {
  final MenuItemData data;

  const MenuItem({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppStyles.itemRadius),
        onTap: data.onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: AppStyles.itemDecoration(context),
          child: Row(
            children: [
              SizedBox(width: 30,child: Text(data.emoji, style: const TextStyle(fontSize: 22))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data.title, style: AppStyles.menuTextStyle),
                    if (data.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(data.subtitle!, style: AppStyles.menuSubStyle),
                    ],
                  ],
                ),
              ),
              const Text('›', style: AppStyles.menuArrowStyle),
            ],
          ),
        ),
      ),
    );
  }
}
