import 'package:sqflite/sqflite.dart';

import '../image/image_category.dart';
import '../image/image_ref.dart';
import '../image/image_service.dart';
import 'unit_of_work.dart';

/// 图片「文件落盘 + 数据库写入」的**唯一两阶段提交编排**。
///
/// 整改前 `UserController.updateProfile` 与 `CategoryController.save`
/// 各自手写一遍 `plan → 写 DB → commit / catch → discard`，且 DB 写不在
/// 事务里：DB 失败时靠 try/catch 回滚文件，但如果同一次操作还要写别的
/// 表（例如「换头像 + 记一条流水」），文件与 DB 的一致性就没有保证了。
///
/// 整改后：文件落盘在事务外，DB 写在 [UnitOfWork.run] 里；
/// **事务提交成功** → `plan.commit()` 删旧图；**任一 DB 操作失败回滚**
/// → `plan.discard()` 删掉本次新落盘的文件。两个 Controller 不再各自
/// 写 try/catch，换页面也不影响这条链路。
/// 【所属模块】service/core · 图片两阶段提交
/// 【实现功能】把"图片先落盘 → 事务内写 DB → 提交成功删旧图 / 回滚删新图"收口成唯一编排；用户资料与分类编辑共用，不再各写 try/catch。
/// 【使用限制】文件 IO 无法纳入 SQLite 事务，本接口只做到最终一致，不是数据库级原子；DB 写入必须放在 body 里并用传入的 txn；调用方不得自行调 plan.commit / plan.discard。
/// 【入参与结果】构造收 UnitOfWork 与 ImageService；run 收 category / entries / existing / body / ownerId / afterCommit，返回 body 的结果 T。
/// 【异常与调用方处理】新图落盘失败由 ImageService.plan 抛并自动回滚本次已落盘文件；DB 失败整体回滚并 plan.discard()；plan.commit() 删旧图失败不影响主流程但会抛给调用方。调用方需自行 try/catch 提示用户。
class ImageTransaction {
  /// 【所属模块】service/core · 图片两阶段提交
  /// 【实现功能】用共享的 UnitOfWork 与 ImageService 创建编排器。
  /// 【使用限制】必须注入与其它模块同一个 uow 实例，否则 DB 写入与刷新不在同一事务链上；全局一份即可。
  /// 【入参与结果】uow / images 均必填且非 null；无返回值（构造）。结果为可复用的 ImageTransaction。
  /// 【异常与调用方处理】构造不抛异常；传入未初始化的 uow 会在 run 时暴露，调用方需保证装配顺序。
  const ImageTransaction(this.uow, this.images);

  final UnitOfWork uow;
  final ImageService images;

  /// 【所属模块】service/core · 图片两阶段提交
  /// 【实现功能】落盘新图 → 在 uow.run 的一个事务里执行 body（写 DB）→ 提交后 plan.commit() 删旧图、afterCommit 刷新；任一 DB 操作回滚则 plan.discard() 删新图。
  /// 【使用限制】body 内写库必须用传入的 txn；不得在 body 里删旧图或落盘新图；afterCommit 只做刷新 / 通知。
  /// 【入参与结果】category / entries / existing / body 必填；ownerId 可选；body 收 (ImageCommitPlan plan, DatabaseExecutor txn) 并返回 T；方法返回 Future<T>，调用方必须 await 后再使用结果。
  /// 【异常与调用方处理】落盘失败抛 ImageService 的异常；body 内异常导致事务回滚且新图被删除后原样上抛；commit 删旧图异常上抛。调用方需自行 try/catch 提示用户、保持界面旧值。
  Future<T> run<T>({
    required ImageCategory category,
    required List<ImageEntry> entries,
    required Iterable<ImageRef> existing,
    required Future<T> Function(ImageCommitPlan plan, DatabaseExecutor txn) body,
    String? ownerId,
    Future<void> Function()? afterCommit,
  }) async {
    final ImageCommitPlan plan = await images.plan(
      category,
      entries,
      existing: existing,
      ownerId: ownerId,
    );
    late T result;
    await uow.run(
      (DatabaseExecutor txn) async {
        result = await body(plan, txn);
      },
      afterCommit: () async {
        await plan.commit();
        if (afterCommit != null) await afterCommit();
      },
      onRollback: () => plan.discard(),
    );
    return result;
  }
}
