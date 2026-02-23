// lib/features/feed/domain/feed_repository.dart
import 'models/feed_collection_model.dart';

abstract class FeedRepository {
  /// Retrieves a list of public collections to be displayed on the Discover feed.
  /// Typically joins with the `photos` and `users` tables.
  Future<List<FeedCollectionModel>> getPublicFeed({
    int limit = 20,
    int offset = 0,
  });

  /// Retrieves a list of collections created by a specific user.
  Future<List<FeedCollectionModel>> getUserFeed(
    String userId, {
    int limit = 20,
    int offset = 0,
  });

  /// Toggles the like status of a specific collection for the current user.
  Future<void> toggleLike(String collectionId, bool isLiked);

  /// Toggles the bookmark status of a specific collection for the current user.
  Future<void> toggleBookmark(String collectionId, bool isBookmarked);

  /// Deletes a specific collection if the user is the owner.
  Future<void> deleteCollection(String collectionId);

  /// Updates the title and/or privacy of a specific collection if the user is the owner.
  Future<void> updateCollection({
    required String collectionId,
    String? title,
    bool? isPrivate,
  });

  /// Deletes a specific photo from a collection, including storage cleanup.
  Future<void> deletePhotoFromCollection({
    required String collectionId,
    required String photoId,
    required String photoUrl,
  });
}
