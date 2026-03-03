// lib/features/search/presentation/controllers/search_controller.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../feed/domain/models/feed_collection_model.dart';
import '../../data/supabase_search_repository.dart';

/// Provides the instance of the SupabaseSearchRepository.
final searchRepositoryProvider = Provider<SupabaseSearchRepository>((ref) {
  return SupabaseSearchRepository(Supabase.instance.client);
});

class SearchController extends AsyncNotifier<List<FeedCollectionModel>> {
  Timer? _debounceTimer;
  String _currentQuery = '';

  bool isLoadingMore = false;
  bool hasReachedMax = false;
  int _offset = 0;
  final int _limit = 20;

  @override
  Future<List<FeedCollectionModel>> build() async {
    // Initial state is empty on search screen
    return [];
  }

  /// Triggered whenever the user types in the search field.
  /// Cancels any ongoing timer and waits 500ms before querying the DB.
  void onSearchQueryChanged(String query) {
    if (_debounceTimer?.isActive ?? false) {
      _debounceTimer!.cancel();
    }

    if (query.trim().isEmpty) {
      _currentQuery = '';
      _offset = 0;
      hasReachedMax = false;
      isLoadingMore = false;
      state = const AsyncData([]);
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _currentQuery = query.trim();
      _offset = 0;
      hasReachedMax = false;
      isLoadingMore = false;
      _performSearch(_currentQuery, isRefresh: true);
    });
  }

  Future<void> _performSearch(String query, {bool isRefresh = false}) async {
    if (isRefresh) {
      state = const AsyncLoading();
    }

    state = await AsyncValue.guard(() async {
      final repository = ref.read(searchRepositoryProvider);
      final newCollections = await repository.searchCollections(
        query,
        limit: _limit,
        offset: _offset,
      );

      if (newCollections.length < _limit) {
        hasReachedMax = true;
      }
      _offset += newCollections.length;

      if (isRefresh) {
        return newCollections;
      } else {
        final currentList = state.value ?? [];
        return [...currentList, ...newCollections];
      }
    });
  }

  /// Fetches the next batch of search results
  Future<void> fetchMore() async {
    if (isLoadingMore ||
        hasReachedMax ||
        _currentQuery.isEmpty ||
        state.value == null) {
      return;
    }

    isLoadingMore = true;
    state = AsyncData(state.value!); // Trigger UI loading state

    try {
      final repository = ref.read(searchRepositoryProvider);
      final newCollections = await repository.searchCollections(
        _currentQuery,
        limit: _limit,
        offset: _offset,
      );

      if (newCollections.length < _limit) {
        hasReachedMax = true;
      }
      _offset += newCollections.length;

      final currentList = state.value!;
      isLoadingMore = false;
      state = AsyncData([...currentList, ...newCollections]);
    } catch (e) {
      isLoadingMore = false;
      state = AsyncData(state.value!);
      debugPrint('[SearchController] fetchMore error: $e');
    }
  }
}

final searchControllerProvider =
    AsyncNotifierProvider<SearchController, List<FeedCollectionModel>>(
      SearchController.new,
    );
