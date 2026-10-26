import '../../models/category.dart';

/// 支出分类数据访问对象。
///
/// 提供对 expense_categories 表的增删改查。
/// 与 UI 层完全解耦，只暴露领域模型 [Category]。
class ExpenseCategoryDao {
  /// 查询所有未删除的分类（含隐藏）
  Future<List<Category>> list({bool includeHidden = false}) async {
    await Future<void>.delayed(Duration.zero);
    var list = [...defaultExpenseCategories];
    if (!includeHidden) list = list.where((c) => !c.hidden).toList();
    return list;
  }

  /// 按 id 查询
  Future<Category?> getById(String id) async {
    await Future<void>.delayed(Duration.zero);
    for (final c in defaultExpenseCategories) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// 查询可见分类（用于选择器和网格展示）
  Future<List<Category>> listVisible() => list(includeHidden: false);

  /// 新增自定义分类
  Future<Category> insert(Category category) async {
    await Future<void>.delayed(Duration.zero);
    return category;
  }

  /// 更新分类（目前仅支持隐藏/显示切换）
  Future<void> update(Category category) async {
    await Future<void>.delayed(Duration.zero);
  }

  /// 隐藏分类
  Future<void> hide(String id) async {
    await Future<void>.delayed(Duration.zero);
  }

  /// 显示分类
  Future<void> show(String id) async {
    await Future<void>.delayed(Duration.zero);
  }

  /// 批量查询
  Future<List<Category>> getByIds(List<String> ids) async {
    await Future<void>.delayed(Duration.zero);
    return [
      for (final id in ids)
        defaultExpenseCategories.firstWhere(
          (c) => c.id == id,
          orElse: () => defaultExpenseCategories.first,
        )
    ];
  }
}
