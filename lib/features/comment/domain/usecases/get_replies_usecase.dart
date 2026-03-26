// lib/features/comment/domain/usecases/get_replies_usecase.dart

import '../../../../core/utils/either.dart';
import '../failures/comment_failure.dart';
import '../models/comment_model.dart';
import '../repositories/comment_repository.dart';

class GetRepliesUseCase {
  final CommentRepository _repository;

  const GetRepliesUseCase(this._repository);

  Future<Either<CommentFailure, List<CommentModel>>> call({
    required String collectionId,
    required String parentId,
    String? lastCreatedAt,
    int limit = 10,
    int offset = 0,
  }) {
    return _repository.getReplies(
      collectionId: collectionId,
      parentId: parentId,
      lastCreatedAt: lastCreatedAt,
      limit: limit,
      offset: offset,
    );
  }
}
