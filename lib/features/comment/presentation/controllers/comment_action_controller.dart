import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/utils/either.dart';
import '../../domain/failures/comment_failure.dart';
import '../../domain/models/comment_model.dart';
import '../../domain/repositories/comment_repository_provider.dart';
import '../../domain/usecases/get_replies_usecase.dart';
import '../../domain/usecases/post_comment_usecase.dart';
import '../providers/comment_cache_provider.dart';
import 'comment_list_controller.dart';
import '../../../feed/presentation/controllers/feed_controller.dart';
import '../../domain/usecases/delete_comment_usecase.dart';
import '../../domain/usecases/toggle_like_comment_usecase.dart';
import '../../../notifications/domain/notification_repository.dart';
import '../../../notifications/presentation/controllers/notification_controller.dart';
import 'dart:async';

class Unit {
  const Unit();
}

const unit = Unit();


class CommentActionController {
  final Ref _ref;
  final PostCommentUseCase _postComment;
  final GetRepliesUseCase _getReplies;
  final DeleteCommentUseCase _deleteComment;
  final ToggleLikeCommentUseCase _toggleLike;

  CommentActionController(this._ref)
    : _postComment = PostCommentUseCase(_ref.read(commentRepositoryProvider)),
      _getReplies = GetRepliesUseCase(_ref.read(commentRepositoryProvider)),
      _deleteComment = DeleteCommentUseCase(
        _ref.read(commentRepositoryProvider),
      ),
      _toggleLike = ToggleLikeCommentUseCase(
        _ref.read(commentRepositoryProvider),
      ),
      _notificationRepository = _ref.read(notificationRepositoryProvider);

  final NotificationRepository _notificationRepository;

  /// Optimistically adds a comment (or reply) and then attempts network call.
  /// Reverts and returns Either.Left on failure, or Either.Right upon success.
  Future<Either<CommentFailure, Unit>> addComment({
    required String collectionId,
    required String content,
    String? parentId,
  }) async {
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      return const Left(AuthenticationFailure());
    }

    // 1. Create a temporary CommentModel
    final tempComment = CommentModel(
      id: tempId,
      collectionId: collectionId,
      userId: user.id,
      parentId: parentId,
      content: content.trim(),
      replyCount: 0,
      likeCount: 0,
      isLiked: false,
      createdAt: DateTime.now(),
      authorUsername: user.userMetadata?['username'] as String? ?? 'user',
      authorAvatarUrl: user.userMetadata?['avatar_url'] as String?,
    );

    // 2. Optimistic Add to Cache & List
    final cacheNotifier = _ref.read(commentCacheProvider.notifier);
    if (parentId == null) {
      cacheNotifier.addOrUpdateComment(tempComment);
      _ref
          .read(commentListControllerProvider(collectionId).notifier)
          .addTempCommentId(tempId);
    } else {
      cacheNotifier.appendReply(parentId, tempComment);
      // Optimistically increment parent's replyCount
      final parent = _ref.read(commentCacheProvider)[parentId];
      if (parent != null) {
        cacheNotifier.addOrUpdateComment(
          parent.copyWith(replyCount: parent.replyCount + 1),
        );
      }
    }

    // Always increment global collection comment count (DB trigger counts all comments)
    _ref
        .read(feedControllerProvider.notifier)
        .incrementCommentCount(collectionId);

    // 3. Perform network call
    final result = await _postComment.call(
      collectionId: collectionId,
      userId: user.id,
      content: content,
      parentId: parentId,
    );

    // 4. Handle Result & Cleanup
    return result.fold(
      (failure) {
        // ROLLBACK
        if (parentId == null) {
          cacheNotifier.removeComment(tempId);
          _ref
              .read(commentListControllerProvider(collectionId).notifier)
              .removeCommentId(tempId);
        } else {
          cacheNotifier.removeComment(tempId, parentId: parentId);
          final parent = _ref.read(commentCacheProvider)[parentId];
          if (parent != null && parent.replyCount > 0) {
            cacheNotifier.addOrUpdateComment(
              parent.copyWith(replyCount: parent.replyCount - 1),
            );
          }
        }
        // Always rollback global count on any failure
        _ref
            .read(feedControllerProvider.notifier)
            .decrementCommentCount(collectionId);
        return Left(failure);
      },
      (realComment) {
        // SUCCESS: Swap temp ID with real DB ID gracefully
        if (parentId == null) {
          cacheNotifier.replaceCommentId(tempId, realComment);
          _ref
              .read(commentListControllerProvider(collectionId).notifier)
              .replaceTempCommentId(tempId, realComment.id);
        } else {
          cacheNotifier.replaceReplyId(parentId, tempId, realComment);
        }

        // Fire & Forget Notifications
        try {
          String? receiverId;
          if (parentId == null) {
            final feedState = _ref.read(feedControllerProvider).value;
            if (feedState != null) {
              for (final col in feedState) {
                if (col.collectionId == collectionId) {
                  receiverId = col.userId;
                  break;
                }
              }
            }
          } else {
            final parent = _ref.read(commentCacheProvider)[parentId];
            receiverId = parent?.userId;
          }

          if (receiverId != null && user.id != receiverId) {
            _notificationRepository.insertNotification(
              type: 'comment',
              receiverId: receiverId,
              collectionId: collectionId,
            );
          }
        } catch (_) {
          // Ignore
        }

        return const Right(unit);
      },
    );
  }

  /// Loads replies lazily for a specific parent comment and feeds the cache.
  /// [limit] controls page size. [offset] controls pagination starting point.
  /// If offset == 0, the result REPLACES the preview; if offset > 0, it APPENDS.
  Future<Either<CommentFailure, Unit>> loadReplies(
    String collectionId,
    String parentId, {
    int limit = 10,
    int offset = 0,
  }) async {
    final result = await _getReplies.call(
      collectionId: collectionId,
      parentId: parentId,
      limit: limit,
      offset: offset,
    );

    return result.fold((failure) => Left(failure), (replies) {
      final cacheNotifier = _ref.read(commentCacheProvider.notifier);

      // Feed all fetched replies into global cache
      cacheNotifier.addOrUpdateComments(replies);

      final parent = _ref.read(commentCacheProvider)[parentId];
      if (parent != null) {
        final existingReplies = parent.replies;
        final existingIds = existingReplies.map((r) => r.id).toSet();
        // De-duplicate: merge new replies that aren't already cached
        final merged = [
          ...existingReplies,
          ...replies.where((r) => !existingIds.contains(r.id)),
        ];

        cacheNotifier.addOrUpdateComment(
          parent.copyWith(
            replies: merged,
            // Synchronize replyCount against truth
            replyCount: merged.length > parent.replyCount
                ? merged.length
                : parent.replyCount,
          ),
        );
      }

      return const Right(unit);
    });
  }

  /// Toggles like status with instantaneous optimistic update and strict error rollback.
  Future<void> toggleLike(CommentModel comment) async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    final cacheNotifier = _ref.read(commentCacheProvider.notifier);
    
    // Previous (rollback) state
    final originalComment = comment;

    final newIsLiked = !comment.isLiked;
    // ensure no negative count
    final newLikeCount = (comment.likeCount + (newIsLiked ? 1 : -1)).clamp(0, 999999);

    // 1. Optimistic Update (Immediate UI reaction)
    final updatedComment = comment.copyWith(
      isLiked: newIsLiked,
      likeCount: newLikeCount,
    );
    cacheNotifier.addOrUpdateComment(updatedComment);

    // 2. Exact API Request
    final result = await _toggleLike.call(
      commentId: comment.id,
      isLiked: newIsLiked,
    );

    result.fold(
      (failure) {
        // Rollback on failure
        cacheNotifier.addOrUpdateComment(originalComment);
      },
      (_) {
        // Post-Success Side Effects (Notifications)
        try {
          if (currentUser.id != comment.userId) {
            if (newIsLiked) {
              _notificationRepository.insertNotification(
                type: 'comment_like',
                receiverId: comment.userId,
                collectionId: comment.collectionId,
              );
            } else {
              _notificationRepository.deleteNotification(
                type: 'comment_like',
                receiverId: comment.userId,
              );
            }
          }
        } catch (_) {
          // Ignore notification errors to avoid crashing main flow
        }
      },
    );
  }

  /// Deletes a comment with optimistic update and rollback.
  Future<void> deleteComment(String collectionId, CommentModel comment) async {
    // 1. Optimistic removal & Garbage Collection
    _ref.read(commentCacheProvider.notifier).removeCommentCascade(comment.id);

    if (comment.parentId == null) {
      _ref
          .read(commentListControllerProvider(collectionId).notifier)
          .removeCommentId(comment.id);
    }

    // Always decrement global collection count (DB trigger counts all comments including replies)
    _ref
        .read(feedControllerProvider.notifier)
        .decrementCommentCount(collectionId);

    // 2. Network call
    final result = await _deleteComment.call(commentId: comment.id);

    result.fold(
      (failure) {
        // 3. Rollback on failure
        _ref.read(commentCacheProvider.notifier).addOrUpdateComment(comment);
        if (comment.parentId != null) {
          _ref
              .read(commentCacheProvider.notifier)
              .appendReply(comment.parentId!, comment);
        } else {
          _ref
              .read(commentListControllerProvider(collectionId).notifier)
              .addTempCommentId(comment.id);
        }
        _ref
            .read(feedControllerProvider.notifier)
            .incrementCommentCount(collectionId);
      },
      (_) {}, // Success
    );
  }
}

// Global Provider
final commentActionControllerProvider = Provider.autoDispose<CommentActionController>((
  ref,
) {
  return CommentActionController(ref);
});
