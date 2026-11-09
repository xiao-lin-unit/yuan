/// 图片的业务分类。
///
/// 所有图片共用同一套「选择 → 校验 → 落盘 → 引用 → 展示」逻辑，
/// 分类只决定：存在哪个子目录、用哪套尺寸/体积策略。
/// 以后新增图片功能（账单凭证、分类图标、反馈截图…）只需在这里加一个枚举值，
/// 并在 ImagePolicy.presets 补一条策略，UI 与存储层一行都不用改。
enum ImageCategory {
  avatar('avatar', '头像'),
  receipt('receipt', '账单凭证'),
  categoryIcon('category_icon', '分类图标'),
  attachment('attachment', '附件'),
  general('general', '通用');

  const ImageCategory(this.dirName, this.label);

  /// 磁盘子目录名，同时也是持久化引用的前缀
  final String dirName;
  final String label;

  static ImageCategory? fromDirName(String value) {
    for (final c in ImageCategory.values) {
      if (c.dirName == value) return c;
    }
    return null;
  }
}
