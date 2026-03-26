// lib/features/comment/domain/usecases/delete_comment_usecase.dart

import '../../../../core/utils/either.dart';
import '../failures/comment_failure.dart';
import '../repositories/comment_repository.dart';

class DeleteCommentUseCase {
  final CommentRepository _repository;

  const DeleteCommentUseCase(this._repository);

  Future<Either<CommentFailure, bool>> call({
    required String commentId,
  }) async {
    return _repository.deleteComment(commentId: commentId);
  }
}
