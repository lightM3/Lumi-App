import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/comment_repository_provider.dart';
import '../../domain/usecases/get_comments_usecase.dart';
import '../providers/comment_cache_provider.dart';

class CommentListState {
  final List<String> commentIds;
  final bool isLoadingMore;
  final bool hasReachedMax;

  const CommentListState({
    this.commentIds = const [],
    this.isLoadingMore = false,
    this.hasReachedMax = false,
  });

  CommentListState copyWith({
    List<String>? commentIds,
    bool? isLoadingMore,
    bool? hasReachedMax,
  }) {
    return CommentListState(
      commentIds: commentIds ?? this.commentIds,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
    );
  }
}

class CommentListController
    extends FamilyAsyncNotifier<CommentListState, String> {
  GetCommentsUseCase get _getComments =>
      GetCommentsUseCase(ref.read(commentRepositoryProvider));

  @override
  Future<CommentListState> build(String arg) async {
    // arg is collectionId
    return _fetchComments(arg);
  }

  Future<CommentListState> _fetchComments(String collectionId) async {
    final result = await _getComments.call(collectionId);

    return result.fold(
      (failure) {
        throw Exception(failure.message);
      },
      (comments) {
        // Feed into shared cache
        ref.read(commentCacheProvider.notifier).addOrUpdateComments(comments);

        return CommentListState(
          commentIds: comments.map((c) => c.id).toList(),
          hasReachedMax:
              true, // Set to true for now since initial fetch brings all or a big limit
        );
      },
    );
  }

  void addTempCommentId(String tempId) {
    if (state.value == null) return;
    // Insert at top (newest first in the UI usually)
    final newIds = [tempId, ...state.value!.commentIds];
    state = AsyncData(state.value!.copyWith(commentIds: newIds));
  }

  void replaceTempCommentId(String oldId, String newId) {
    if (state.value == null) return;
    final ids = state.value!.commentIds
        .map((id) => id == oldId ? newId : id)
        .toList();
    state = AsyncData(state.value!.copyWith(commentIds: ids));
  }

  void removeCommentId(String id) {
    if (state.value == null) return;
    final ids = state.value!.commentIds.where((i) => i != id).toList();
    state = AsyncData(state.value!.copyWith(commentIds: ids));
  }
}

final commentListControllerProvider =
    AsyncNotifierProvider.family<
      CommentListController,
      CommentListState,
      String
    >(CommentListController.new);
