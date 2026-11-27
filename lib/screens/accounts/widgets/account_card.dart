import 'package:material_ui/material_ui.dart';

import '../../../database/account/account_record.dart';
import '../../../styles/app_decorations.dart';
import '../../../styles/app_typography.dart';
import '../../../styles/theme_tokens.dart';
import '../../../utils/money_format.dart';
import '../../commons/icon/app_icon_badge.dart';
import '../../commons/icons/app_icons.dart';

// ── 组件私有样式（只服务本文件，全部引用全局令牌）───────────────
const double _kIconSize = 36;
const double _kIconGlyphSize = AppIconSize.medium;
const double _kCardMinHeight = 76;
const double _kBadgeRadius = AppRadius.small;

/// 账户形态 → 语义图标。放在业务模块内（不是全局图标表），
/// 因为只有账户列表/明细用得到，且要认识 AccountType 这个业务枚举。
IconData accountTypeIcon(AccountType type) => switch (type) {
      AccountType.bank => AppIcons.accountBank,
      AccountType.cash => AppIcons.accountCash,
      AccountType.wechat => AppIcons.accountWechat,
      AccountType.alipay => AppIcons.accountAlipay,
      AccountType.creditCard => AppIcons.accountCreditCard,
      // 花呗 / 借呗暂复用现有矢量图标，不新增图标资产；
      // 两者都是信用类形态，等负债模块联动再考虑专属图标。
      AccountType.huabei => AppIcons.accountAlipay,
      AccountType.jiebei => AppIcons.accountCreditCard,
      AccountType.socialSecurity => AppIcons.accountSocial,
      AccountType.housingFund => AppIcons.accountHousing,
      AccountType.giftCard => AppIcons.accountGiftCard,
      AccountType.frozen => AppIcons.accountFrozen,
      // 契-14：K4 投资账户唯一形态，图标走已有的 investment 矢量，
      // 不新增图标资产。穷尽 switch 必须列出，否则加形态就编译不过。
      AccountType.stockAccount => AppIcons.investment,
      AccountType.other => AppIcons.accountOther,
    };

/// 原型 `.account-card` 的业务实现。
///
/// 三类账户共用同一张卡片（与「一张 accounts 表」对应），差异只在：
///   · 图标徽章（按形态）；
///   · 右侧主数字：流动资金/受限显示余额，信用卡显示可用额度；
///   · 信用卡多一个「还款日 N 号」提醒徽章（取 warning 语义色）；
///   · 受限账户在副标题前显示 🔒 的矢量等价（lock 图标）。
/// 样式全部走 AppDecorations / context.appText / context.tokens，
/// 没有硬编码颜色、字号、圆角。
///
/// 【拖柄是可选参数，不是第二种渲染模式】[dragIndex] 为 null 时不渲染
/// 左侧手柄，其余布局逐像素不变；传值时应给**当前列表内的下标**，
/// 由 [ReorderableDragStartListener] 交给外层 ReorderableListView。
/// 与分类页 CategoryListTile 的 `dragIndex` 是同一套写法，不新增机制。
/// 账户首页的搜索结果段不传，因为跨类别的临时结果没有稳定的排序语义。
class AccountCard extends StatelessWidget {
  const AccountCard({
    super.key,
    required this.account,
    required this.index,
    required this.onTap,
    this.dragIndex,
  });

  final AccountRecord account;

  /// 组内下标，只用于 AppIconBadge 的色相轮换（纯视觉）。
  final int index;
  final VoidCallback onTap;
  final int? dragIndex;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final bool credit = account.kind == AccountKind.credit;
    final bool locked = account.kind == AccountKind.restricted;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.item),
          child: Container(
            decoration: AppDecorations.item(context),
            constraints: const BoxConstraints(minHeight: _kCardMinHeight),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: <Widget>[
                if (dragIndex != null)
                  ReorderableDragStartListener(
                    index: dragIndex!,
                    child: Padding(
                      padding: const EdgeInsets.only(
                        right: AppSpacing.xxs,
                      ),
                      child: Icon(
                        AppIcons.dragHandle,
                        size: AppIconSize.medium,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                    ),
                  ),
                AppIconBadge(
                  icon: accountTypeIcon(account.type),
                  size: _kIconSize,
                  iconSize: _kIconGlyphSize,
                  tone: null,
                  index: index,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(account.name, style: context.appText.menuTitle),
                      const SizedBox(height: AppSpacing.xxs),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          if (locked)
                            Padding(
                              padding: const EdgeInsets.only(right: AppSpacing.xxs),
                              child: Icon(
                                AppIcons.locked,
                                size: AppIconSize.small,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          Flexible(
                            child: Text(
                              account.subtitle,
                              style: context.appText.caption,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      credit
                          ? '可用额度 ${MoneyFormat.orDash(account.availableCredit)}'
                          : MoneyFormat.yuan0(account.balance),
                      style: context.appText.amount.copyWith(
                        color: credit ? tokens.warning : null,
                      ),
                    ),
                    if (credit && account.dueDay != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.xxs),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                          vertical: AppSpacing.xxs,
                        ),
                        decoration: BoxDecoration(
                          color: tokens.warning.withValues(
                            alpha: AppOpacity.disabledContainer,
                          ),
                          borderRadius: BorderRadius.circular(_kBadgeRadius),
                        ),
                        child: Text(
                          '还款日每月 ${account.dueDay} 日',
                          style: context.appText.caption
                              .copyWith(color: tokens.warning),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
