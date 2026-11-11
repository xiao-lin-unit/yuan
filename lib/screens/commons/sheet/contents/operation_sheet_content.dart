import 'package:flutter/material.dart';
import 'package:yuan/screens/commons/sheet/parts/sheet_media.dart';
import 'package:yuan/screens/commons/sheet/parts/sheet_primitives.dart';
import 'package:yuan/screens/commons/sheet/sheet_models.dart';
import 'package:yuan/styles/theme_tokens.dart';

/// 原型 ④「操作 / 媒体控制」：右上「收起」+ 封面与元信息 + 进度条 +
/// 时间 + 五个控制图标 + 底部两栏文字动作。
///
/// 媒体状态（播放中、进度、时间）由业务层传入，组件本身无状态，
/// 便于接播放器 Controller 或记账 App 里的其它「进行中」操作。
class OperationSheetContent extends StatelessWidget {
  const OperationSheetContent({
    super.key,
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.elapsed,
    required this.total,
    required this.isPlaying,
    this.cover,
    this.collapseLabel = '收起',
    this.onCollapse,
    this.onTogglePlay,
    this.onPrevious,
    this.onNext,
    this.onRepeat,
    this.onVolume,
    this.onProgressChanged,
    this.footerLeft,
    this.footerRight,
  });

  final String title;
  final String subtitle;
  final double progress;
  final String elapsed;
  final String total;
  final bool isPlaying;
  final Widget? cover;
  final String collapseLabel;
  final VoidCallback? onCollapse;
  final VoidCallback? onTogglePlay;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onRepeat;
  final VoidCallback? onVolume;
  final ValueChanged<double>? onProgressChanged;
  final SheetFooterAction? footerLeft;
  final SheetFooterAction? footerRight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            const SizedBox(width: kMinTapTarget),
            const Spacer(),
            SheetTextAction(
              label: collapseLabel,
              onTap: onCollapse ?? () => SheetActions.close(context),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        SheetMediaControls(
          title: title,
          subtitle: subtitle,
          progress: progress,
          elapsed: elapsed,
          total: total,
          isPlaying: isPlaying,
          cover: cover,
          onTogglePlay: onTogglePlay,
          onPrevious: onPrevious,
          onNext: onNext,
          onRepeat: onRepeat,
          onVolume: onVolume,
          onProgressChanged: onProgressChanged,
          footerLeft: footerLeft,
          footerRight: footerRight,
        ),
      ],
    );
  }
}
