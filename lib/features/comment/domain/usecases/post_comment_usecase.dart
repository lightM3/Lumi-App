// lib/features/comment/domain/usecases/post_comment_usecase.dart

import '../../../../core/utils/either.dart';
import '../failures/comment_failure.dart';
import '../models/comment_model.dart';
import '../repositories/comment_repository.dart';

class PostCommentUseCase {
  final CommentRepository _repository;

  const PostCommentUseCase(this._repository);

  Future<Either<CommentFailure, CommentModel>> call({
    required String collectionId,
    required String userId,
    required String content,
    String? parentId,
  }) {
    if (content.trim().isEmpty) {
      return Future.value(const Left(ValidationFailure('Comment cannot be empty.')));
    }
    
    return _repository.postComment(
      collectionId: collectionId,
      userId: userId,
      content: content.trim(),
      parentId: parentId,
    );
  }
}
