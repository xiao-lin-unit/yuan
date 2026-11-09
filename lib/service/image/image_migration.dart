import 'dart:convert';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'image_category.dart';
import 'image_policy.dart';
import 'image_ref.dart';
import 'image_service.dart';
import 'image_storage.dart';
import 'image_validator.dart';

/// v1 → v2 统一迁移：把历史遗留图片收编成 [ImageRef]。
///
/// 覆盖三种旧形态：
/// 1. 长 base64（最初版本）→ 解码 → 校验 → 落盘
/// 2. 纯文件名（上一版补丁，文件在 avatars/）→ 收编进 images/avatar/
/// 3. 已是 `avatar/xxx.jpg` → 跳过
///
/// 坏数据降级成「无图片」，绝不阻断 App 启动；可重复执行（幂等）。
/// 以后新增业务表若有旧 base64 列，往 [migrateColumn] 传参即可复用。
class ImageMigration {
  static Future<void> run(Database db) async {
    await migrateColumn(
      db,
      table: 'user_info',
      column: 'avatar',
      category: ImageCategory.avatar,
    );
  }

  /// 通用列迁移：任何表、任何图片列都能用。
  static Future<void> migrateColumn(
    Database db, {
    required String table,
    required String column,
    required ImageCategory category,
    String idColumn = 'id',
  }) async {
    final rows = await db.query(table, columns: [idColumn, column]);

    for (final row in rows) {
      final id = row[idColumn] as int?;
      final raw = row[column] as String?;
      if (id == null || raw == null || raw.isEmpty) continue;

      // 已是规范引用
      final decoded = ImageRef.tryDecode(raw);
      if (decoded != null && decoded.encode() == raw) continue;

      try {
        final ImageRef ref;

        if (ImageRef.isLegacyBase64(raw)) {
          final bytes = base64Decode(raw);
          final ext = ImageStorage.sniffExt(bytes).replaceFirst('.', '');
          final candidate = await ImageValidator.validateWithBytes(
            bytes: bytes,
            fileExt: ext,
            policy: ImagePolicy.of(category),
            checkSize: false, // 老图尺寸不受当前策略约束，保数据优先
          );
          ref = await ImageService.instance.prepare(
            category,
            candidate,
            ownerId: '$id',
          );
        } else {
          // 纯文件名：从旧目录收编
          final adopted = await ImageStorage.instance.adoptLegacy(
            raw,
            category: category,
          );
          if (adopted == null) throw StateError('旧图片文件不存在');
          ref = adopted;
        }

        await db.update(
          table,
          {column: ref.encode()},
          where: '$idColumn = ?',
          whereArgs: [id],
        );
      } catch (_) {
        await db.update(
          table,
          {column: ''},
          where: '$idColumn = ?',
          whereArgs: [id],
        );
      }
    }
  }
}
