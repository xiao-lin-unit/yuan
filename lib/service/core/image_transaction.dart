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
class ImageTransaction {
  const ImageTransaction(this.uow, this.images);

  final UnitOfWork uow;
  final ImageService images;

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
