// import 'package:flutter/material.dart';
//
// import '../icon/app_icon_badge.dart';
// import '../icons/app_icons.dart';
// import '../scaffold/app_page_scaffold.dart';
// import '../../../styles/app_icon_tone.dart';
// import '../../../styles/app_typography.dart';
// import '../../../styles/sheet_tokens.dart';
// import '../../../styles/theme_tokens.dart';
//
// // ── 预览页私有内容 ────────────────────────────────────────────
// const String _kPageTitle = '彩色图标体系 · 鲜明档';
// const List<String> _kMenuKeys = <String>[
//   'knowledge',
//   'export',
//   'import',
//   'color',
//   'appearance',
//   'category',
//   'trash',
//   'about',
// ];
// const List<IconData> _kRingIcons = <IconData>[
//   AppIcons.entry,
//   AppIcons.ledger,
//   AppIcons.accounts,
//   AppIcons.analysis,
//   AppIcons.profile,
//   AppIcons.finance,
//   AppIcons.gift,
//   AppIcons.medical,
//   AppIcons.restaurant,
//   AppIcons.utility,
//   AppIcons.study,
//   AppIcons.other,
// ];
//
// /// 彩色图标的可运行验证页。
// ///
// /// 临时挂一条路由或 `runApp(MaterialApp(home: IconTonePreview()))` 即可查看；
// /// 然后在【我的】→ 主题里换 8 个预设 / 切明暗，观察三档徽章、
// /// 语义色、12 色相环与底导 indicator 是否一起重算。
// ///
// /// 这一页只放示例数据，不含任何颜色 / 字号 / 圆角定义。
// class IconTonePreview extends StatelessWidget {
//   const IconTonePreview({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     final text = context.appText;
//     final tone = AppIconTone.of(context);
//
//     return AppPageScaffold(
//       title: _kPageTitle,
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: <Widget>[
//           Text(
//             '当前浓度：${AppIconTone.intensity.name}（改 AppIconTone.intensity 一处即可'
//             '整体切回 restrained）。鲜明档把 12 色相环铺到菜单 / 分区 / 底导，'
//             '容器改双色渐变 + 光晕；16–24px 高频功能图标仍保持单色。',
//             style: text.body,
//           ),
//           const SizedBox(height: AppSpacing.lg),
//           for (final emphasis in AppIconEmphasis.values) ...<Widget>[
//             _SampleRow(
//               label: emphasis.name,
//               badges: <Widget>[
//                 for (var i = 0; i < 4; i++)
//                   AppIconBadge(
//                     icon: AppIcons.function,
//                     tone: tone.forIndex(i * 3),
//                     emphasis: emphasis,
//                   ),
//               ],
//             ),
//           ],
//
//           const SizedBox(height: AppSpacing.lg),
//           Text('菜单语义色（按 key + index 映射，业务层零改动）',
//               style: text.menuTitle),
//           const SizedBox(height: AppSpacing.sm),
//           Wrap(
//             spacing: AppSpacing.md,
//             runSpacing: AppSpacing.md,
//             children: <Widget>[
//               for (var i = 0; i < _kMenuKeys.length; i++)
//                 _KeyBadge(toneKey: _kMenuKeys[i], index: i),
//             ],
//           ),
//
//           const SizedBox(height: AppSpacing.lg),
//           Text('12 色相环（与分类网格同一套算法，换主题自动平移）',
//               style: text.menuTitle),
//           const SizedBox(height: AppSpacing.sm),
//           Wrap(
//             spacing: AppSpacing.sm,
//             runSpacing: AppSpacing.sm,
//             children: <Widget>[
//               for (var i = 0; i < 12; i++)
//                 AppIconBadge(
//                   icon: _kRingIcons[i],
//                   tone: tone.forIndex(i),
//                   emphasis: AppIconEmphasis.filled,
//                 ),
//             ],
//           ),
//
//           const SizedBox(height: AppSpacing.lg),
//           Text(
//             '每个色对都经过 4.5:1 对比度校验；渐变两端明度差 0.08，'
//             '同一前景色在两端都可读。危险红 / 警告琥珀不随浓度漂移。',
//             style: text.caption,
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// class _SampleRow extends StatelessWidget {
//   const _SampleRow({required this.label, required this.badges});
//
//   final String label;
//   final List<Widget> badges;
//
//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.only(bottom: AppSpacing.md),
//       child: Row(
//         children: <Widget>[
//           SizedBox(
//             width: AppSheetSize.formLabelWidth,
//             child: Text(label, style: context.appText.caption),
//           ),
//           const SizedBox(width: AppSpacing.md),
//           ...<Widget>[
//             for (final badge in badges) ...<Widget>[
//               badge,
//               const SizedBox(width: AppSpacing.sm),
//             ],
//           ],
//         ],
//       ),
//     );
//   }
// }
//
// class _KeyBadge extends StatelessWidget {
//   const _KeyBadge({required this.toneKey, required this.index});
//
//   // 不能叫 key：Widget 已有 Key? key，同名不同类型会覆盖父类成员。
//   final String toneKey;
//   final int index;
//
//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       mainAxisSize: MainAxisSize.min,
//       children: <Widget>[
//         AppIconBadge(
//           icon: AppIcons.function,
//           toneKey: toneKey,
//           index: index,
//         ),
//         const SizedBox(height: AppSpacing.xxs),
//         Text(toneKey, style: context.appText.caption),
//       ],
//     );
//   }
// }
