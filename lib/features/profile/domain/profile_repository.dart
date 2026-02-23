// lib/features/profile/domain/profile_repository.dart
import '../../feed/domain/models/feed_collection_model.dart';
import 'models/profile_user_model.dart';

abstract class ProfileRepository {
  /// Toggle follow status for a target user
  Future<void> toggleFollow(
    String currentUserId,
    String targetUserId,
    bool isFollowing,
  );

  /// Check if current user is following the target user
  Future<bool> checkIsFollowing(String currentUserId, String targetUserId);

  /// Get the number of followers for a given user
  Future<int> getFollowersCount(String userId);

  /// Get the number of users the given user is following
  Future<int> getFollowingCount(String userId);

  /// Retrieves collections that a specific user has liked
  Future<List<FeedCollectionModel>> getUserLikedCollections(String userId);

  /// Retrieves collections that a specific user has bookmarked
  Future<List<FeedCollectionModel>> getUserBookmarkedCollections(String userId);

  /// Get the list of users that follow the given user
  Future<List<ProfileUserModel>> getFollowersList(String userId);

  /// Get the list of users that the given user is following
  Future<List<ProfileUserModel>> getFollowingList(String userId);
}
