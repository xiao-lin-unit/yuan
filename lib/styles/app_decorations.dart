import 'package:material_ui/material_ui.dart';

import 'app_stroke.dart';
import 'theme_tokens.dart';

/// 全软件共用的**容器装饰**工厂。
///
/// 判定标准：只有被 ≥2 个不同组件使用的装饰才允许放在这里。
/// 只属于某个组件的形状（如头像的圆形占位、图片删除角标）必须留在
/// 该组件文件顶部的 `_k*` 私有常量区，不许上提到全局。
///
/// 所有颜色取自 ThemeExtension 与 ColorScheme，切换主题色 / 明暗时
/// 一处重算、全软件同步；阴影透明度、描边宽度、圆角档位也全部走令牌。
abstract final class AppDecorations {
  /// 页面级卡片：surfaceContainer 底色 + 细描边 + 轻阴影（暗色靠色差分层）
  static BoxDecoration card(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = context.tokens;
    final dark = cs.brightness == Brightness.dark;
    return BoxDecoration(
      color: t.card,
      borderRadius: BorderRadius.circular(AppRadius.card),
      border: Border.all(
        color: t.divider.withValues(
          alpha: dark ? AppOpacity.outlineDark : AppOpacity.outline,
        ),
        width: AppBorder.thin,
      ),
      boxShadow: dark
          ? null
          : <BoxShadow>[
              BoxShadow(
                color: t.shadow.withValues(alpha: AppElevation.cardAlpha),
                offset: AppElevation.cardOffset,
                blurRadius: AppElevation.cardBlur,
              ),
            ],
    );
  }

  /// 列表项 / 分区内容：靠底色与极轻阴影分层，**不画描边**。
  /// 一屏十几张卡若每张都带一圈框，视觉上就成了「圆角表格」；
  /// 去掉框之后层级改由留白、字号与阴影承担，整屏立刻松下来。
  static BoxDecoration item(BuildContext context) {
    final t = context.tokens;
    final dark = Theme.of(context).colorScheme.brightness == Brightness.dark;
    return BoxDecoration(
      color: t.card,
      borderRadius: BorderRadius.circular(AppRadius.item),
      boxShadow: dark
          ? null
          : <BoxShadow>[
              BoxShadow(
                color: t.shadow.withValues(alpha: AppElevation.cardAlpha * 0.6),
                offset: AppElevation.cardOffset,
                blurRadius: AppElevation.cardBlur,
              ),
            ],
    );
  }

  /// 弹层 / BottomSheet 容器
  static BoxDecoration sheet(BuildContext context) {
    final t = context.tokens;
    return BoxDecoration(
      color: t.sheet,
      borderRadius:
          const BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: t.shadow.withValues(alpha: AppElevation.sheetAlpha),
          blurRadius: AppElevation.sheetBlur,
          offset: AppElevation.sheetOffset,
        ),
      ],
    );
  }

  /// 表单输入框容器：**亮底 + 可见细框**。
  ///
  /// 这里和列表卡是两套逻辑，别混：列表的描边是视觉噪声，所以
  /// `item()` 不画框；输入框的描边是「这里能填」的功能信号，必须看得见。
  /// 旧版用 `t.field` 灰填充 + `divider × 0.16` 的边框，框几乎融进底色，
  /// 整屏灰度过高、聚焦时也看不出哪个字段是活的。现在底色回到
  /// `cs.surface`（明暗自适应），边框取划分线实色、不再二次衰减 alpha。
  ///
  /// 所有输入框类容器（文本行 / 下拉 / 搜索框 / 自定义字段）共用这一份，
  /// 因此 label 挪到框外之后，左右两列的边界感仍然完全一致。
  static BoxDecoration field(BuildContext context) {
    final t = context.tokens;
    final cs = Theme.of(context).colorScheme;
    return BoxDecoration(
      color: cs.surface,
      borderRadius: BorderRadius.circular(AppRadius.item),
      border: Border.all(
        color: t.divider,
        width: AppBorder.thin,
      ),
    );
  }

  /// 图标徽章容器：色对由 [AppIconTone] 解析好再传进来。
  ///
  /// 旧版固定 12% 淡底 + 同色图标，等于给单色图标蒙了层看不见的雾；
  /// 后来改成实色容器又给每个徽章套了一圈描边，一屏下来全是小方框。
  /// 现在容器实色（tonal 浅 / filled 深）、前景取反色、**不画描边**，
  /// 圆角统一走 [AppRadius.item]；只有鲜明档才叠加光晕。
  static BoxDecoration iconBadge(
    BuildContext context,
    Color container, {
    Gradient? gradient,
    bool glow = false,
  }) {
    final transparent = container == Colors.transparent;
    return BoxDecoration(
      // BoxDecoration 不允许 color 与 gradient 同时非 null
      color: gradient == null ? container : null,
      gradient: gradient,
      borderRadius: BorderRadius.circular(AppRadius.item),
      // 徽章本身已是色块，再套一圈描边会碎成一堆小方框；去掉。
      boxShadow: glow && !transparent
          ? <BoxShadow>[
              BoxShadow(
                color: container.withValues(alpha: AppOpacity.outline),
                blurRadius: AppElevation.cardBlur,
                offset: AppElevation.cardOffset,
              ),
            ]
          : null,
    );
  }

  /// 纯描边（禁用态、空槽位）
  static BoxDecoration outline(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return BoxDecoration(
      color: cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppRadius.item),
      border: AppStroke.all(context),
    );
  }
}
