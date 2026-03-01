// lib/features/profile/presentation/controllers/board_detail_controller.dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/board_model.dart';
import '../../../feed/domain/models/feed_collection_model.dart';
import 'profile_controller.dart'; // boardRepositoryProvider is here

class BoardDetailController
    extends FamilyAsyncNotifier<List<FeedCollectionModel>, String> {
  @override
  FutureOr<List<FeedCollectionModel>> build(String arg) async {
    return _fetchBoardCollections(arg);
  }

  Future<List<FeedCollectionModel>> _fetchBoardCollections(
    String boardId,
  ) async {
    final repository = ref.read(boardRepositoryProvider);
    return repository.getBoardCollections(boardId);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetchBoardCollections(arg));
  }

  /// Optimistic removal: removes a collection from the local list immediately
  /// without making a network call. Used after a successful unsave toggle.
  void removeCollection(String collectionId) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.where((c) => c.collectionId != collectionId).toList(),
    );
  }

  /// Optimistic addition: adds a collection back to the local list (undo scenario).
  void addCollection(FeedCollectionModel collection) {
    final current = state.value;
    if (current == null) return;
    // Prevent duplicates
    if (current.any((c) => c.collectionId == collection.collectionId)) return;
    state = AsyncData([...current, collection]);
  }
}

final boardDetailControllerProvider =
    AsyncNotifierProviderFamily<
      BoardDetailController,
      List<FeedCollectionModel>,
      String
    >(BoardDetailController.new);

final singleBoardProvider = FutureProvider.family<BoardModel?, String>((
  ref,
  boardId,
) async {
  try {
    // A quick fetch directly from Supabase to get the board details
    // since we need it for ownership check and editing in BoardDetailScreen
    final response = await Supabase.instance.client
        .from('boards')
        .select()
        .eq('id', boardId)
        .maybeSingle();

    if (response == null) return null;
    return BoardModel.fromMap(response);
  } catch (e) {
    return null;
  }
});
