// lib/core/utils/either.dart

/// A simple Either type to represent a value of one of two possible types (a disjoint union).
/// It represents a value of type [L] (Left, usually meaning failure/error) 
/// or of type [R] (Right, usually meaning success/value).
abstract class Either<L, R> {
  const Either();

  bool get isLeft => this is Left<L, R>;
  bool get isRight => this is Right<L, R>;

  T fold<T>(T Function(L l) onLeft, T Function(R r) onRight) {
    if (this is Left<L, R>) {
      return onLeft((this as Left<L, R>).value);
    } else if (this is Right<L, R>) {
      return onRight((this as Right<L, R>).value);
    }
    throw Exception('Invalid Either type');
  }

  L get left => (this as Left<L, R>).value;
  R get right => (this as Right<L, R>).value;
}

class Left<L, R> extends Either<L, R> {
  final L value;
  const Left(this.value);
}

class Right<L, R> extends Either<L, R> {
  final R value;
  const Right(this.value);
}
