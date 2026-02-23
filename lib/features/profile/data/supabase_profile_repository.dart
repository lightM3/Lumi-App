// lib/features/profile/data/supabase_profile_repository.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/profile_repository.dart';
import '../../feed/domain/models/feed_collection_model.dart';
import '../domain/models/profile_user_model.dart';
import '../../notifications/data/supabase_notification_repository.dart';

class SupabaseProfileRepository implements ProfileRepository {
  const SupabaseProfileRepository(this._supabase);

  final SupabaseClient _supabase;

  @override
  Future<void> toggleFollow(
    String currentUserId,
    String targetUserId,
    bool isFollowing,
  ) async {
    try {
      final notifRepo = SupabaseNotificationRepository(_supabase);

      if (isFollowing) {
        // Zaten takip ediyorsa, takipten çık (Unfollow)
        await _supabase
            .from('follows')
            .delete()
            .eq('follower_id', currentUserId)
            .eq('following_id', targetUserId);

        // Remove follow notification
        unawaited(
          notifRepo.deleteNotification(
            type: 'follow',
            receiverId: targetUserId,
          ),
        );
      } else {
        // Etmiyorsa, takip et (Follow)
        await _supabase.from('follows').insert({
          'follower_id': currentUserId,
          'following_id': targetUserId,
        });

        // Notify the followed user
        unawaited(
          notifRepo.insertNotification(
            type: 'follow',
            receiverId: targetUserId,
          ),
        );
      }
    } catch (e) {
      debugPrint('[SupabaseProfileRepository] Toggle follow error: $e');
      throw Exception('Failed to toggle follow status');
    }
  }

  @override
  Future<bool> checkIsFollowing(
    String currentUserId,
    String targetUserId,
  ) async {
    try {
      final res = await _supabase
          .from('follows')
          .select('follower_id')
          .eq('follower_id', currentUserId)
          .eq('following_id', targetUserId)
          .limit(1)
          .maybeSingle();
      return res != null;
    } catch (e) {
      debugPrint('[SupabaseProfileRepository] Check following error: $e');
      return false;
    }
  }

  @override
  Future<int> getFollowersCount(String userId) async {
    try {
      final res = await _supabase
          .from('follows')
          .select('following_id')
          .eq('following_id', userId)
          .count(CountOption.exact);
      return res.count;
    } catch (e) {
      debugPrint('[SupabaseProfileRepository] Get followers count error: $e');
      return 0;
    }
  }

  @override
  Future<int> getFollowingCount(String userId) async {
    try {
      final res = await _supabase
          .from('follows')
          .select('follower_id')
          .eq('follower_id', userId)
          .count(CountOption.exact);
      return res.count;
    } catch (e) {
      debugPrint('[SupabaseProfileRepository] Get following count error: $e');
      return 0;
    }
  }

  @override
  Future<List<FeedCollectionModel>> getUserLikedCollections(
    String userId,
  ) async {
    try {
      final response = await _supabase
          .from('likes')
          .select(
            'collections(*, photos(*), users!collections_user_id_fkey(*), likes(user_id), bookmarks(user_id))',
          )
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final List<dynamic> data = response;
      final collections = <FeedCollectionModel>[];

      for (final item in data) {
        try {
          final collectionData = item['collections'];
          if (collectionData != null) {
            // Sort photos by sort_order
            if (collectionData['photos'] != null &&
                collectionData['photos'] is List) {
              final photosList = collectionData['photos'] as List;
              photosList.sort((a, b) {
                final orderA = (a['sort_order'] as num?)?.toInt() ?? 0;
                final orderB = (b['sort_order'] as num?)?.toInt() ?? 0;
                return orderA.compareTo(orderB);
              });
            }
            collections.add(
              FeedCollectionModel.fromMap(
                collectionData as Map<String, dynamic>,
                currentUserId: _supabase.auth.currentUser?.id,
              ),
            );
          }
        } catch (e) {
          debugPrint(
            '[SupabaseProfileRepository] Parse error on liked collection: $e',
          );
        }
      }
      return collections;
    } catch (e) {
      debugPrint(
        '[SupabaseProfileRepository] Error fetching liked collections: $e',
      );
      return [];
    }
  }

  @override
  Future<List<FeedCollectionModel>> getUserBookmarkedCollections(
    String userId,
  ) async {
    try {
      final response = await _supabase
          .from('bookmarks')
          .select(
            'collections(*, photos(*), users!collections_user_id_fkey(*), likes(user_id), bookmarks(user_id))',
          )
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final List<dynamic> data = response;
      final collections = <FeedCollectionModel>[];

      for (final item in data) {
        try {
          final collectionData = item['collections'];
          if (collectionData != null) {
            // Sort photos by sort_order
            if (collectionData['photos'] != null &&
                collectionData['photos'] is List) {
              final photosList = collectionData['photos'] as List;
              photosList.sort((a, b) {
                final orderA = (a['sort_order'] as num?)?.toInt() ?? 0;
                final orderB = (b['sort_order'] as num?)?.toInt() ?? 0;
                return orderA.compareTo(orderB);
              });
            }
            collections.add(
              FeedCollectionModel.fromMap(
                collectionData as Map<String, dynamic>,
                currentUserId: _supabase.auth.currentUser?.id,
              ),
            );
          }
        } catch (e) {
          debugPrint(
            '[SupabaseProfileRepository] Parse error on bookmarked collection: $e',
          );
        }
      }
      return collections;
    } catch (e) {
      debugPrint(
        '[SupabaseProfileRepository] Error fetching bookmarked collections: $e',
      );
      return [];
    }
  }

  @override
  Future<List<ProfileUserModel>> getFollowersList(String userId) async {
    try {
      // follows tablosundan 'following_id'si kullanici olan metinleri al.
      // İçindeki follower_id ile users tablosunu birleştir (join).
      final response = await _supabase
          .from('follows')
          .select('users!follows_follower_id_fkey(*)')
          .eq('following_id', userId);

      final List<ProfileUserModel> result = [];
      for (final row in response) {
        final userData = row['users'];
        if (userData != null) {
          result.add(ProfileUserModel.fromMap(userData));
        }
      }
      return result;
    } catch (e) {
      debugPrint('[SupabaseProfileRepository] Error fetching followers: $e');
      return [];
    }
  }

  @override
  Future<List<ProfileUserModel>> getFollowingList(String userId) async {
    try {
      // follows tablosundan 'follower_id'si kullanici olan metinleri al.
      // İçindeki following_id ile users tablosunu birleştir (join).
      final response = await _supabase
          .from('follows')
          .select('users!follows_following_id_fkey(*)')
          .eq('follower_id', userId);

      final List<ProfileUserModel> result = [];
      for (final row in response) {
        final userData = row['users'];
        if (userData != null) {
          result.add(ProfileUserModel.fromMap(userData));
        }
      }
      return result;
    } catch (e) {
      debugPrint('[SupabaseProfileRepository] Error fetching following: $e');
      return [];
    }
  }
}
