// lib/features/comment/domain/usecases/get_comments_usecase.dart

import '../../../../core/utils/either.dart';
import '../failures/comment_failure.dart';
import '../models/comment_model.dart';
import '../repositories/comment_repository.dart';

class GetCommentsUseCase {
  final CommentRepository _repository;

  const GetCommentsUseCase(this._repository);

  Future<Either<CommentFailure, List<CommentModel>>> call(String collectionId) {
    return _repository.getComments(collectionId: collectionId);
  }
}
