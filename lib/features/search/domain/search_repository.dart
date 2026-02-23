// lib/features/search/domain/search_repository.dart
import '../../feed/domain/models/feed_collection_model.dart';

abstract class SearchRepository {
  /// Searches for public collections whose title matches the query.
  /// Uses ILIKE for case-insensitive partial matching.
  Future<List<FeedCollectionModel>> searchCollections(
    String query, {
    int limit = 20,
    int offset = 0,
  });
}
