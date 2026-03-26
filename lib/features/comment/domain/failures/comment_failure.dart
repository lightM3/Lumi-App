// lib/features/comment/domain/failures/comment_failure.dart

abstract class CommentFailure {
  final String message;
  const CommentFailure(this.message);
}

class NetworkFailure extends CommentFailure {
  const NetworkFailure([super.message = 'No internet connection. Please try again.']);
}

class ServerFailure extends CommentFailure {
  const ServerFailure([super.message = 'An unexpected server error occurred.']);
}

class ValidationFailure extends CommentFailure {
  const ValidationFailure(super.message);
}

class AuthenticationFailure extends CommentFailure {
  const AuthenticationFailure([super.message = 'You must be logged in to comment.']);
}
