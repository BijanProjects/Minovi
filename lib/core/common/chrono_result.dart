/// Sealed result type mirroring Kotlin's ChronoResult.
sealed class ChronoResult<T> {
  const ChronoResult();

  factory ChronoResult.success(T data) = ChronoSuccess<T>;
  factory ChronoResult.error(String message, [Object? cause]) = ChronoError<T>;
  factory ChronoResult.loading() = ChronoLoading<T>;

  R when<R>({
    required R Function(T data) success,
    required R Function(String message, Object? cause) error,
    required R Function() loading,
  }) {
    return switch (this) {
      ChronoSuccess<T>(:final data) => success(data),
      ChronoError<T>(:final message, :final cause) => error(message, cause),
      ChronoLoading<T>() => loading(),
    };
  }

  ChronoResult<R> map<R>(R Function(T data) transform) {
    return switch (this) {
      ChronoSuccess<T>(:final data) => ChronoResult.success(transform(data)),
      ChronoError<T>(:final message, :final cause) => ChronoResult.error(message, cause),
      ChronoLoading<T>() => ChronoResult.loading(),
    };
  }

  T? get dataOrNull => switch (this) {
    ChronoSuccess<T>(:final data) => data,
    _ => null,
  };

  bool get isSuccess => this is ChronoSuccess<T>;
  bool get isError => this is ChronoError<T>;
  bool get isLoading => this is ChronoLoading<T>;

  static Future<ChronoResult<T>> of<T>(Future<T> Function() block) async {
    try {
      return ChronoResult.success(await block());
    } catch (e) {
      return ChronoResult.error(e.toString(), e);
    }
  }
}

final class ChronoSuccess<T> extends ChronoResult<T> {
  final T data;
  const ChronoSuccess(this.data);
}

final class ChronoError<T> extends ChronoResult<T> {
  final String message;
  final Object? cause;
  const ChronoError(this.message, [this.cause]);
}

final class ChronoLoading<T> extends ChronoResult<T> {
  const ChronoLoading();
}
