/// 分类类型：支出 or 收入
enum CategoryKind { expense, income }

/// 支出分类的必要性
enum Necessity { necessary, flexible }

/// 收入分类的稳定性
enum Stability { stable, unstable, occasional }

/// 扁平一层分类。不设置二级分类，用户点一下即选中。
class Category {
  final String id;
  final String name;
  final CategoryKind kind;
  final String? icon;
  final bool isSystem; // 系统预设，不可删
  final bool hidden;   // 可隐藏

  // 支出分类可标记为必要/弹性
  final Necessity? necessity;

  // 收入分类可标记为稳定/不稳定/偶发
  final Stability? stability;

  const Category({
    required this.id,
    required this.name,
    required this.kind,
    this.icon,
    this.isSystem = true,
    this.hidden = false,
    this.necessity,
    this.stability,
  });

  Category copyWith({bool? hidden}) => Category(
        id: id,
        name: name,
        kind: kind,
        icon: icon,
        isSystem: isSystem,
        hidden: hidden ?? this.hidden,
        necessity: necessity,
        stability: stability,
      );
}

/// 内置的支出分类预设
const List<Category> defaultExpenseCategories = [
  Category(id: 'food',     name: '餐饮', icon: '🍚', necessity: Necessity.necessary),
  Category(id: 'traffic',  name: '交通', icon: '🚗', necessity: Necessity.flexible),
  Category(id: 'market',   name: '买菜', icon: '🛒', necessity: Necessity.necessary),
  Category(id: 'housing',  name: '住房', icon: '🏠', necessity: Necessity.necessary),
  Category(id: 'utilities',name: '水电', icon: '⚡', necessity: Necessity.necessary),
  Category(id: 'medical',  name: '医疗', icon: '💊', necessity: Necessity.necessary),
  Category(id: 'clothing', name: '服饰', icon: '👕', necessity: Necessity.flexible),
  Category(id: 'entertain',name: '娱乐', icon: '🎮', necessity: Necessity.flexible),
  Category(id: 'study',    name: '学习', icon: '📚', necessity: Necessity.flexible),
  Category(id: 'social',   name: '人情', icon: '🎁', necessity: Necessity.flexible),
  Category(id: 'finance',  name: '金融', icon: '💰', necessity: Necessity.flexible),
  Category(id: 'other',    name: '其他', icon: '📦', necessity: Necessity.flexible),
];

/// 内置的收入分类预设
const List<Category> defaultIncomeCategories = [
  Category(id: 'salary',     name: '工资',   icon: '💼', stability: Stability.stable),
  Category(id: 'parttime',   name: '兼职',   icon: '🛠️', stability: Stability.unstable),
  Category(id: 'investment', name: '投资回报', icon: '📈', stability: Stability.unstable),
  Category(id: 'gift',       name: '礼金',   icon: '🎀', stability: Stability.occasional),
  Category(id: 'other_income', name: '其他', icon: '📦', stability: Stability.occasional),
];
