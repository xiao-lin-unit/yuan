import 'package:yuan/service/image/image_validator.dart';

/// 图片校验逻辑已统一到 `lib/service/image/image_validator.dart`。
///
/// 保留本文件只是为了不打断旧 import；新代码请直接引用统一图片层。
/// 全项目只有一套校验实现，这里不复制任何逻辑。
export 'package:yuan/service/image/image_validator.dart';

/// 旧名称兼容：新代码改用 ImageCandidate。
typedef ImagePickResult = ImageCandidate;
