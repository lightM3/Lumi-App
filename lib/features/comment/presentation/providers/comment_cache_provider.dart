import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/comment_model.dart';

class CommentCacheNotifier extends Notifier<Map<String, CommentModel>> {
  @override
  Map<String, CommentModel> build() => {};

  void addOrUpdateComments(List<CommentModel> comments) {
    if (comments.isEmpty) return;
    final newState = Map<String, CommentModel>.from(state);
    for (final c in comments) {
      newState[c.id] = c;
    }
    state = newState;
  }

  void addOrUpdateComment(CommentModel comment) {
    state = {...state, comment.id: comment};
  }

  void removeComment(String id, {String? parentId}) {
    final newState = Map<String, CommentModel>.from(state);
    newState.remove(id);

    // If it was a reply, remove from the parent's nested list
    if (parentId != null && newState.containsKey(parentId)) {
      final parent = newState[parentId]!;
      final updatedReplies = parent.replies.where((r) => r.id != id).toList();
      newState[parentId] = parent.copyWith(replies: updatedReplies);
    }
    state = newState;
  }

  void removeCommentCascade(String id) {
    final newState = Map<String, CommentModel>.from(state);

    // Recursive removal
    void removeDescendants(String currentId) {
      final comment = newState[currentId];
      if (comment != null) {
        for (final reply in comment.replies) {
          removeDescendants(reply.id);
        }
      }
      newState.remove(currentId);
    }

    // Before removing, if it's a child, remove it from parent's list
    final target = newState[id];
    if (target != null && target.parentId != null) {
      final parentId = target.parentId!;
      if (newState.containsKey(parentId)) {
        final parent = newState[parentId]!;
        final updatedReplies = parent.replies.where((r) => r.id != id).toList();
        final newReplyCount = parent.replyCount > 0 ? parent.replyCount - 1 : 0;
        newState[parentId] = parent.copyWith(
          replies: updatedReplies,
          replyCount: newReplyCount,
        );
      }
    }

    removeDescendants(id);
    state = newState;
  }

  void appendReply(String parentId, CommentModel reply) {
    // 1. Add reply to main cache map
    addOrUpdateComment(reply);

    // 2. Update parent's replies list
    final s = state;
    if (s.containsKey(parentId)) {
      final parent = s[parentId]!;
      final existingIndex = parent.replies.indexWhere((r) => r.id == reply.id);
      final newReplies = List<CommentModel>.from(parent.replies);

      if (existingIndex >= 0) {
        newReplies[existingIndex] = reply;
      } else {
        newReplies.add(reply);
      }

      state = {...state, parentId: parent.copyWith(replies: newReplies)};
    }
  }

  void replaceReplyId(
    String parentId,
    String oldTempId,
    CommentModel realReply,
  ) {
    final newState = Map<String, CommentModel>.from(state);
    // Swap in the global map
    newState.remove(oldTempId);
    newState[realReply.id] = realReply;

    // Swap inside the parent's nested list
    if (newState.containsKey(parentId)) {
      final parent = newState[parentId]!;
      final updatedReplies = parent.replies
          .map((r) => r.id == oldTempId ? realReply : r)
          .toList();
      newState[parentId] = parent.copyWith(replies: updatedReplies);
    }

    state = newState;
  }

  void replaceCommentId(String oldTempId, CommentModel realComment) {
    final newState = Map<String, CommentModel>.from(state);
    // Swap in the global map
    newState.remove(oldTempId);
    newState[realComment.id] = realComment;
    state = newState;
  }
}

// Singleton Cache Provider
final commentCacheProvider =
    NotifierProvider<CommentCacheNotifier, Map<String, CommentModel>>(
      CommentCacheNotifier.new,
    );

// Family Provider for individual comment cards
final commentProvider = Provider.family<CommentModel?, String>((ref, id) {
  return ref.watch(commentCacheProvider)[id];
});
