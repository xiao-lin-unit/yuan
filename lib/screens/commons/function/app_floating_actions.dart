import 'package:material_ui/material_ui.dart';

import '../../../styles/theme_tokens.dart';
import '../icons/app_icons.dart';

// ── 模块私有文案 / 尺寸（样式一律走全局令牌）────────────────────
const String _kMoreLabel = '更多操作';
const String _kCollapseLabel = '收起';

/// 悬浮按钮的一项配置（**纯数据契约**，不含任何样式）。
///
/// [label] 不会画在按钮上：按钮与展开列表**只展示图标**，名称走
/// FloatingActionButton 自带的 `tooltip`（桌面 hover / 键盘 focus 显示，
/// 移动端长按显示，是 Flutter Tooltip 的标准行为，不是自定义浮层）。
/// [onPressed] 是同步回调；业务里要打开 Sheet / 写库这类异步动作，
/// 由调用方自己写 `() => unawaited(xxx())`（工程开了 unawaited_futures）。
class AppFloatingAction {
  const AppFloatingAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.emphasized = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  /// true 时用主色实底（关键动作），false 用全局 FAB 主题的
  /// primaryContainer 底。只影响配色，不影响尺寸与布局。
  final bool emphasized;
}

/// 右下角可复用悬浮按钮组。
///
/// ── 形态（构造期由 actions.length 一次判定）────────────────────
///   · 0 项 → 不渲染（SizedBox.shrink）；
///   · 1 项 → 直接显示这一项的圆形按钮，没有「更多」；
///   · ≥2 项 → 显示一个「更多」主按钮，点击展开一列小圆形按钮。
///
/// ── 唯一一处动态逻辑：`_expanded`，工作逻辑写清楚 ──────────────
/// 为什么动态：展开与否是用户点击后才有的状态，构造期定不死。
/// 用最朴素的 StatefulWidget + setState，没有 Notifier / InheritedWidget
/// 提升 / 跨帧回调 / 动画控制器：
///   ① 点主按钮 → `setState(() => _expanded = !_expanded)`；
///   ② `_expanded` 为 true 时，在主按钮**上方**渲染每一项小按钮；
///   ③ 点任一项 → 先执行 `action.onPressed()`，再 `if (mounted)
///      setState(() => _expanded = false)`（避免列表一直挂着；
///      若回调里同步 pop 了页面，mounted 检查保证不报错）；
///   ④ 边界：不建 barrier，点外部不会自动收起，再点一次主按钮即可；
///      组件销毁时 state 随之消失，路由切换不会残留。
/// 刻意**不做展开动画 / 不加 AnimationController**：那会引入一层需要
/// 解释的隐式机制，与本项目的静态优先约定不符。
///
/// ── 位置不在这里决定 ────────────────────────────────────────────
/// 本组件只返回一个 Column，**不含 Positioned / Align**。右下角由
/// `AppPageScaffold` 的 `floating` 槽位用 Stack + Positioned 定位，
/// 这是布局决定位置，不是组件互相控制。
///
/// ── 为什么每个 FAB 都写 `heroTag: null` ─────────────────────────
/// 展开后同一屏会出现多个 FloatingActionButton；默认 heroTag 是同一个
/// 内部对象，Flutter 会抛「multiple heroes share the same tag」。
/// 显式传 null 关闭 Hero 动画，是这个形态的必需项，别删。
class AppFloatingActions extends StatefulWidget {
  const AppFloatingActions({
    super.key,
    required this.actions,
    this.moreLabel = _kMoreLabel,
    this.collapseLabel = _kCollapseLabel,
  });

  final List<AppFloatingAction> actions;
  final String moreLabel;
  final String collapseLabel;

  @override
  State<AppFloatingActions> createState() => _AppFloatingActionsState();
}

class _AppFloatingActionsState extends State<AppFloatingActions> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final List<AppFloatingAction> actions = widget.actions;
    if (actions.isEmpty) return const SizedBox.shrink();
    if (actions.length == 1) {
      return _single(actions.single);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        if (_expanded)
          for (final AppFloatingAction a in actions)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              // 子按钮 40dp、主按钮 56dp；包一层固定宽度让小按钮
              // 在 56dp 列内居中，右边缘与主按钮对齐。
              child: SizedBox(
                width: AppComponentSize.fabSize,
                child: Center(child: _small(a)),
              ),
            ),
        _mainMore(),
      ],
    );
  }

  /// 单按钮形态：直接用大 FAB，没有展开逻辑。
  Widget _single(AppFloatingAction a) => _fab(
        a,
        small: false,
        onPressed: a.onPressed,
      );

  /// 展开列表里的一项：小 FAB，点击后收起。
  Widget _small(AppFloatingAction a) => _fab(
        a,
        small: true,
        onPressed: () {
          a.onPressed();
          if (mounted && _expanded) setState(() => _expanded = false);
        },
      );

  Widget _mainMore() => FloatingActionButton(
        heroTag: null,
        tooltip: _expanded ? widget.collapseLabel : widget.moreLabel,
        onPressed: () => setState(() => _expanded = !_expanded),
        child: Icon(
          _expanded ? AppIcons.clear : AppIcons.more,
          size: AppIconSize.large,
        ),
      );

  Widget _fab(
    AppFloatingAction a, {
    required bool small,
    required VoidCallback onPressed,
  }) {
    final cs = Theme.of(context).colorScheme;
    final Color? background =
        a.emphasized ? cs.primary : null; // null = 走全局 FAB 主题
    final Color? foreground =
        a.emphasized ? cs.onPrimary : null;
    final Widget icon = Icon(a.icon, size: AppIconSize.large);

    // tooltip = 名称：hover / focus / 长按才显示，平时按钮里只有图标。
    if (small) {
      return FloatingActionButton.small(
        heroTag: null,
        tooltip: a.label,
        backgroundColor: background,
        foregroundColor: foreground,
        onPressed: onPressed,
        child: icon,
      );
    }
    return FloatingActionButton(
      heroTag: null,
      tooltip: a.label,
      backgroundColor: background,
      foregroundColor: foreground,
      onPressed: onPressed,
      child: icon,
    );
  }
}
