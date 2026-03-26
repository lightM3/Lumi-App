// lib/features/comment/domain/repositories/comment_repository.dart

import '../../../../core/utils/either.dart';
import '../failures/comment_failure.dart';
import '../models/comment_model.dart';

abstract class CommentRepository {
  /// Fetches top-level comments (parentId == null) for a given collection.
  Future<Either<CommentFailure, List<CommentModel>>> getComments({
    required String collectionId,
    // Add pagination or cursor if needed in the future
  });

  /// Fetches replies for a specific parent comment.
  /// [lastCommentId] can be used for cursor-based pagination.
  Future<Either<CommentFailure, List<CommentModel>>> getReplies({
    required String collectionId,
    required String parentId,
    String? lastCreatedAt,
    int limit = 10,
    int offset = 0,
  });

  /// Posts a new comment or reply.
  Future<Either<CommentFailure, CommentModel>> postComment({
    required String collectionId,
    required String userId,
    required String content,
    String? parentId,
  });

  /// Deletes a comment by ID.
  Future<Either<CommentFailure, bool>> deleteComment({
    required String commentId,
  });

  /// Toggles the like status of a comment for the current user.
  Future<Either<CommentFailure, bool>> toggleLikeComment({
    required String commentId,
    required bool isLiked,
  });
}
