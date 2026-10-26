/// 业务层统一返回类型。
///
/// 不抛异常，所有跨模块业务操作都通过 [Result] 返回，
/// UI 层据此决定提示成功还是失败，避免裸露 try/catch。
sealed class Result<T> {
  const Result();
}

class Ok<T> extends Result<T> {
  final T value;
  const Ok(this.value);
}

class Err<T> extends Result<T> {
  final String message;
  const Err(this.message);
}

extension ResultOps<T> on Result<T> {
  bool get isOk => this is Ok<T>;
  bool get isErr => this is Err<T>;

  /// 折叠处理，类似 Rust 的 match
  R fold<R>(R Function(T value) onOk, R Function(String message) onErr) {
    final self = this;
    if (self is Ok<T>) return onOk(self.value);
    if (self is Err<T>) return onErr(self.message);
    throw StateError('unreachable');
  }

  /// 链式转换：成功则继续，失败则透传
  Result<U> andThen<U>(Result<U> Function(T value) f) {
    final self = this;
    if (self is Ok<T>) return f(self.value);
    return Err((self as Err<T>).message);
  }
}
