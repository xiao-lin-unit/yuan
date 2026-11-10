import 'package:flutter/material.dart';
import 'package:yuan/screens/commons/icons/app_icons.dart';
import 'package:yuan/screens/commons/sheet/sheet_models.dart';
import 'package:yuan/styles/sheet_tokens.dart';
import 'package:yuan/styles/theme_tokens.dart';

// ── 组件私有常量（只服务本文件）────────────────────────────────
const double _kTrackHeight = 4;
const double _kTimeGap = AppSpacing.xs;
const double _kControlsGap = AppSpacing.sm;
const double _kCoverRadius = AppRadius.item;
const double _kCoverGap = AppSpacing.md;

/// 原型「播放控制」弹层的内容：封面 + 标题/副标题 + 进度条 +
/// 时间 + 5 个图标控制 + 底部两栏文字动作。
///
/// 进度条刻意自绘而不用 Slider：原型是细线 + 圆形滑块，没有拖拽交互，
/// 自绘能完全贴合且不受 SliderTheme 影响；颜色仍全部来自 SheetPalette。
class SheetMediaControls extends StatelessWidget {
  const SheetMediaControls({
    super.key,
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.elapsed,
    required this.total,
    required this.isPlaying,
    this.cover,
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
    final p = SheetPalette.of(context);
    final text = SheetText.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            _Cover(cover: cover, p: p),
            const SizedBox(width: _kCoverGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(title, style: text.mediaTitle),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(subtitle, style: text.mediaSubtitle),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSheetSize.sectionGap),
        _ProgressBar(
          progress: progress.clamp(0.0, 1.0).toDouble(),
          p: p,
          onChanged: onProgressChanged,
        ),
        const SizedBox(height: _kTimeGap),
        Row(
          children: <Widget>[
            Text(elapsed, style: text.caption),
            const Spacer(),
            Text(total, style: text.caption),
          ],
        ),
        const SizedBox(height: _kControlsGap),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            _ControlIcon(
              icon: AppIcons.repeat,
              onTap: onRepeat,
              p: p,
            ),
            _ControlIcon(
              icon: AppIcons.skipPrevious,
              onTap: onPrevious,
              p: p,
            ),
            _PlayButton(
              isPlaying: isPlaying,
              onTap: onTogglePlay,
              p: p,
            ),
            _ControlIcon(
              icon: AppIcons.skipNext,
              onTap: onNext,
              p: p,
            ),
            _ControlIcon(
              icon: AppIcons.volume,
              onTap: onVolume,
              p: p,
            ),
          ],
        ),
        const SizedBox(height: AppSheetSize.sectionGap),
        Row(
          children: <Widget>[
            Expanded(
              child: _FooterAction(action: footerLeft, p: p, text: text),
            ),
            Expanded(
              child: _FooterAction(action: footerRight, p: p, text: text),
            ),
          ],
        ),
      ],
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.cover, required this.p});

  final Widget? cover;
  final SheetPalette p;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(_kCoverRadius),
      child: SizedBox(
        width: AppSheetSize.mediaCoverSize,
        height: AppSheetSize.mediaCoverSize,
        child: cover ??
            Container(
              decoration: BoxDecoration(gradient: p.primaryGradient),
            ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.progress,
    required this.p,
    this.onChanged,
  });

  final double progress;
  final SheetPalette p;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final double played = width * progress;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: onChanged == null
              ? null
              : (details) => onChanged!(
                    (details.localPosition.dx / width).clamp(0.0, 1.0).toDouble(),
                  ),
          child: SizedBox(
            height: AppSheetSize.sliderThumbRadius * 2,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: <Widget>[
                Container(
                  height: _kTrackHeight,
                  width: width,
                  decoration: BoxDecoration(
                    color: p.inactiveBar,
                    borderRadius: BorderRadius.circular(_kTrackHeight),
                  ),
                ),
                Container(
                  height: _kTrackHeight,
                  width: played,
                  decoration: BoxDecoration(
                    color: p.cs.primary,
                    borderRadius: BorderRadius.circular(_kTrackHeight),
                  ),
                ),
                Positioned(
                  left: (played - AppSheetSize.sliderThumbRadius)
                      .clamp(0.0, width - AppSheetSize.sliderThumbRadius * 2)
                      .toDouble(),
                  child: Container(
                    width: AppSheetSize.sliderThumbRadius * 2,
                    height: AppSheetSize.sliderThumbRadius * 2,
                    decoration: BoxDecoration(
                      color: p.glassColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: p.cs.primary,
                        width: AppBorder.focused,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({
    required this.isPlaying,
    required this.onTap,
    required this.p,
  });

  final bool isPlaying;
  final VoidCallback? onTap;
  final SheetPalette p;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppSheetSize.mediaPlayButtonSize,
      height: AppSheetSize.mediaPlayButtonSize,
      decoration: BoxDecoration(
        gradient: p.primaryGradient,
        shape: BoxShape.circle,
        boxShadow: p.primaryGlow,
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Icon(
            isPlaying ? AppIcons.pause : AppIcons.play,
            size: AppSheetSize.mediaControlIconSize,
            color: p.onPrimaryGradient,
          ),
        ),
      ),
    );
  }
}

class _ControlIcon extends StatelessWidget {
  const _ControlIcon({
    required this.icon,
    required this.onTap,
    required this.p,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final SheetPalette p;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: kMinTapTarget,
      height: kMinTapTarget,
      child: IconButton(
        icon: Icon(icon),
        iconSize: AppSheetSize.mediaControlIconSize,
        color: p.mutedText,
        onPressed: onTap,
      ),
    );
  }
}

class _FooterAction extends StatelessWidget {
  const _FooterAction({
    required this.action,
    required this.p,
    required this.text,
  });

  final SheetFooterAction? action;
  final SheetPalette p;
  final SheetText text;

  @override
  Widget build(BuildContext context) {
    if (action == null) return const SizedBox.shrink();
    return TextButton(
      onPressed: action!.onTap,
      style: TextButton.styleFrom(
        minimumSize: const Size(kMinTapTarget, kMinTapTarget),
      ),
      child: Text(
        action!.label,
        style: text.optionLabel.copyWith(color: p.mutedText),
      ),
    );
  }
}
