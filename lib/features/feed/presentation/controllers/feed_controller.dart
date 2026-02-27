import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/feed_collection_model.dart';
import '../../data/supabase_feed_repository.dart';
import '../../../profile/presentation/controllers/profile_controller.dart';
import '../../../profile/presentation/controllers/board_detail_controller.dart';

/// Provides the instance of the SupabaseFeedRepository.
final feedRepositoryProvider = Provider<SupabaseFeedRepository>((ref) {
  return SupabaseFeedRepository(Supabase.instance.client);
});

/// Riverpod AsyncNotifier that manages the Discover feed state.
class FeedController extends AsyncNotifier<List<FeedCollectionModel>> {
  bool isLoadingMore = false;
  bool hasReachedMax = false;
  int _offset = 0;
  final int _limit = 20;

  @override
  Future<List<FeedCollectionModel>> build() async {
    return _fetchFeed(isRefresh: true);
  }

  Future<List<FeedCollectionModel>> _fetchFeed({bool isRefresh = false}) async {
    if (isRefresh) {
      _offset = 0;
      hasReachedMax = false;
      isLoadingMore = false;
    }

    final repository = ref.read(feedRepositoryProvider);
    final newCollections = await repository.getPublicFeed(
      limit: _limit,
      offset: _offset,
    );

    if (newCollections.length < _limit) {
      hasReachedMax = true;
    }

    _offset += newCollections.length;

    // V1.1: Shuffle the list on refresh for a dynamic discover experience
    if (isRefresh) {
      newCollections.shuffle();
    }

    return newCollections;
  }

  /// Manually triggers a reload (e.g., from a RefreshIndicator).
  Future<void> refreshFeed() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetchFeed(isRefresh: true));
  }

  /// Fetches the next batch of collections and appends them to the current list
  Future<void> fetchMore() async {
    if (isLoadingMore || hasReachedMax || state.value == null) return;

    isLoadingMore = true;
    // Trigger UI rebuild to show loading indicator if needed
    state = AsyncData(state.value!);

    try {
      final newCollections = await _fetchFeed();
      final currentList = state.value!;

      isLoadingMore = false;
      state = AsyncData([...currentList, ...newCollections]);
    } catch (e) {
      isLoadingMore = false;
      state = AsyncData(state.value!);
      debugPrint('[FeedController] Error fetching more feed: $e');
    }
  }

  /// Toggles like status with Optimistic UI updates.
  Future<void> toggleLike(String collectionId) async {
    final previousState = state;
    if (previousState.value == null) return;

    final collections = previousState.value!;
    final index = collections.indexWhere((c) => c.collectionId == collectionId);
    if (index == -1) return;

    final collection = collections[index];
    final newIsLiked = !collection.isLiked;
    // ensure likeCount doesn't go below 0 accidentally
    final newLikeCount = (collection.likeCount + (newIsLiked ? 1 : -1)).clamp(
      0,
      999999,
    );

    // 1. Optimistic Update (Immediate UI response)
    final updatedCollection = collection.copyWith(
      isLiked: newIsLiked,
      likeCount: newLikeCount,
    );
    final updatedList = List<FeedCollectionModel>.from(collections)
      ..[index] = updatedCollection;

    state = AsyncData(updatedList);

    // 2. Perform Backend Request
    try {
      final repository = ref.read(feedRepositoryProvider);
      await repository.toggleLike(collectionId, newIsLiked);
    } catch (e) {
      // 3. Revert State on Failure
      debugPrint('[FeedController] Optimistic like failed, reverted state: $e');
      state = previousState;
    }
  }

  /// Toggles bookmark status with Optimistic UI updates.
  Future<void> toggleBookmark(String collectionId) async {
    final previousState = state;
    if (previousState.value == null) return;

    final collections = previousState.value!;
    final index = collections.indexWhere((c) => c.collectionId == collectionId);
    if (index == -1) return;

    final collection = collections[index];
    final newIsBookmarked = !collection.isBookmarked;

    // 1. Optimistic Update (Immediate UI response)
    final updatedCollection = collection.copyWith(
      isBookmarked: newIsBookmarked,
    );
    final updatedList = List<FeedCollectionModel>.from(collections)
      ..[index] = updatedCollection;

    state = AsyncData(updatedList);

    // 2. Perform Backend Request
    try {
      final repository = ref.read(feedRepositoryProvider);
      await repository.toggleBookmark(collectionId, newIsBookmarked);
    } catch (e) {
      // 3. Revert State on Failure
      debugPrint(
        '[FeedController] Optimistic bookmark failed, reverted state: $e',
      );
      state = previousState;
    }
  }

  /// Deletes a collection from the feed. Optimistic UI is applied.
  Future<void> deleteCollection(String collectionId) async {
    final previousState = state;
    if (previousState.value == null) return;

    final collections = previousState.value!;
    final updatedList = collections
        .where((c) => c.collectionId != collectionId)
        .toList();

    // 1. Optimistic UI update
    state = AsyncData(updatedList);

    // 2. Perform Backend Request
    try {
      final repository = ref.read(feedRepositoryProvider);
      await repository.deleteCollection(collectionId);
    } catch (e) {
      // 3. Revert State on Failure
      debugPrint(
        '[FeedController] Collection delete failed, reverted state: $e',
      );
      state = previousState;
      rethrow;
    }
  }

  /// Deletes a specific photo from a collection. Optimistic UI is applied.
  Future<void> deletePhoto(
    String collectionId,
    String photoId,
    String photoUrl,
  ) async {
    final previousState = state;
    if (previousState.value == null) return;

    final collections = previousState.value!;
    final index = collections.indexWhere((c) => c.collectionId == collectionId);
    if (index == -1) return;

    final collection = collections[index];

    // 1. Optimistic UI update
    final newPhotos = collection.photos.where((p) => p.id != photoId).toList();
    final updatedCollection = collection.copyWith(photos: newPhotos);
    final updatedList = List<FeedCollectionModel>.from(collections)
      ..[index] = updatedCollection;

    state = AsyncData(updatedList);

    // 2. Perform Backend Request
    try {
      final repository = ref.read(feedRepositoryProvider);
      await repository.deletePhotoFromCollection(
        collectionId: collectionId,
        photoId: photoId,
        photoUrl: photoUrl,
      );
    } catch (e) {
      // 3. Revert State on Failure
      debugPrint('[FeedController] Photo delete failed, reverted state: $e');
      state = previousState;
      rethrow;
    }
  }

  /// Updates the title and privacy of a collection.
  ///
  /// Backend call is ALWAYS made regardless of whether the collection
  /// currently lives in the local feed list (it may be absent if it is
  /// already private or was never loaded into the discover feed).
  Future<void> updateCollection({
    required String collectionId,
    String? title,
    bool? isPrivate,
  }) async {
    // ── 1. Optimistic UI (only when collection is in feed list) ────────────
    final currentList = state.value;
    List<FeedCollectionModel>? previousList;

    if (currentList != null) {
      final index = currentList.indexWhere(
        (c) => c.collectionId == collectionId,
      );

      if (index != -1) {
        previousList = currentList; // save for rollback
        final updated = currentList[index].copyWith(
          title: title ?? currentList[index].title,
          isPrivate: isPrivate ?? currentList[index].isPrivate,
        );

        final newList = List<FeedCollectionModel>.from(currentList);
        if (isPrivate == true) {
          // Made private → vanish from public discover feed immediately
          newList.removeAt(index);
        } else {
          newList[index] = updated;
        }
        state = AsyncData(newList);
      }
    }

    // ── 2. Backend — always executed ───────────────────────────────────────
    try {
      final repository = ref.read(feedRepositoryProvider);
      await repository.updateCollection(
        collectionId: collectionId,
        title: title,
        isPrivate: isPrivate,
      );

      // ── 3. Sync — invalidate profile so tabs re-fetch from DB ──────────
      ref.invalidate(profileControllerProvider);
    } catch (e) {
      debugPrint('[FeedController] updateCollection failed: $e');
      // Rollback optimistic UI if we had changed it
      if (previousList != null) {
        state = AsyncData(previousList);
      }
      rethrow;
    }
  }

  /// Toggles a collection in a specific board.
  /// Board and bookmark operations are fully isolated — no cross-table side effects.
  /// Returns a human-readable message to be shown in Snackbar.
  Future<String> toggleBoardStatus(String collectionId, String boardId) async {
    final boardRepository = ref.read(boardRepositoryProvider);

    try {
      // 1. Check if already in board
      final existingBoardIds = await boardRepository.getBoardIdsForCollection(
        collectionId,
      );
      final isInBoard = existingBoardIds.contains(boardId);

      if (isInBoard) {
        // Remove from board (board_collections only)
        await boardRepository.removeCollectionFromBoard(boardId, collectionId);

        // Optimistic UI 1: remove from BoardDetailScreen list immediately
        ref
            .read(boardDetailControllerProvider(boardId).notifier)
            .removeCollection(collectionId);

        // Optimistic UI 2: update isBookmarked in FeedController state
        final current = state;
        if (current.value != null) {
          final collections = current.value!;
          final index = collections.indexWhere(
            (c) => c.collectionId == collectionId,
          );
          if (index != -1) {
            final updated = collections[index].copyWith(isBookmarked: false);
            state = AsyncData(
              List<FeedCollectionModel>.from(collections)..[index] = updated,
            );
          }
        }
        return 'Removed from board';
      } else {
        // Add to board (board_collections only)
        await boardRepository.addCollectionToBoard(boardId, collectionId);

        // Invalidate board detail so next visit fetches fresh data (with join).
        // Manual list mutation is unsafe here as photos/users join data may be incomplete.
        ref.invalidate(boardDetailControllerProvider(boardId));

        // Optimistic UI: reflect addition in FeedController state
        final current = state;
        if (current.value != null) {
          final collections = current.value!;
          final index = collections.indexWhere(
            (c) => c.collectionId == collectionId,
          );
          if (index != -1) {
            final updated = collections[index].copyWith(isBookmarked: true);
            state = AsyncData(
              List<FeedCollectionModel>.from(collections)..[index] = updated,
            );
          }
        }
        return 'Added to board';
      }
    } catch (e) {
      debugPrint('[FeedController] Toggle board status failed: $e');
      rethrow;
    }
  }
}

final feedControllerProvider =
    AsyncNotifierProvider<FeedController, List<FeedCollectionModel>>(
      FeedController.new,
    );
