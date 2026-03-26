// lib/features/comment/domain/usecases/toggle_like_comment_usecase.dart

import '../../../../core/utils/either.dart';
import '../failures/comment_failure.dart';
import '../repositories/comment_repository.dart';

class ToggleLikeCommentUseCase {
  final CommentRepository _repository;

  const ToggleLikeCommentUseCase(this._repository);

  Future<Either<CommentFailure, bool>> call({
    required String commentId,
    required bool isLiked,
  }) async {
    return _repository.toggleLikeComment(
      commentId: commentId,
      isLiked: isLiked,
    );
  }
}
