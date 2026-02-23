// lib/features/feed/data/supabase_feed_repository.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

import '../../../core/constants/supabase_config.dart';
import '../../../core/error/custom_exceptions.dart';
import '../domain/feed_repository.dart';
import '../domain/models/feed_collection_model.dart';
import '../../notifications/data/supabase_notification_repository.dart';

class SupabaseFeedRepository implements FeedRepository {
  const SupabaseFeedRepository(this._supabase);

  final SupabaseClient _supabase;

  @override
  Future<List<FeedCollectionModel>> getPublicFeed({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      // Perform a JOIN query:
      // We want collections where is_public = true.
      // We join the 'photos' table to get the cover image and aspect ratio.
      // We join the 'users' table to get the author's username and avatar.
      final response = await _supabase
          .from(SupabaseConfig.collectionsTable)
          .select(
            '*, photos(*), users!collections_user_id_fkey(*), likes(user_id), bookmarks(user_id)',
          )
          .eq('is_public', true)
          .eq('is_private', false) // Double-lock: DB-level privacy guard
          // Order by latest created collections
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final List<dynamic> data = response;

      final collections = <FeedCollectionModel>[];
      for (final item in data) {
        try {
          // Supabase returns list of photos, we want to ensure they are sorted if not already
          if (item['photos'] != null && item['photos'] is List) {
            final photosList = item['photos'] as List;
            photosList.sort((a, b) {
              final orderA = (a['sort_order'] as num?)?.toInt() ?? 0;
              final orderB = (b['sort_order'] as num?)?.toInt() ?? 0;
              return orderA.compareTo(orderB);
            });
          }
          collections.add(
            FeedCollectionModel.fromMap(
              item as Map<String, dynamic>,
              currentUserId: _supabase.auth.currentUser?.id,
            ),
          );
        } catch (e) {
          // If a single row fails to parse, log it and continue
          debugPrint('[SupabaseFeedRepository] Parse error on row: $e');
        }
      }

      return collections;
    } on PostgrestException catch (e) {
      debugPrint('[SupabaseFeedRepository] PostgrestException: ${e.message}');
      throw DatabaseException('Failed to fetch feed from database.', cause: e);
    } catch (e) {
      debugPrint('[SupabaseFeedRepository] Unexpected fallback error: $e');
      throw DatabaseException(
        'An unexpected error occurred while fetching the feed.',
        cause: e,
      );
    }
  }

  @override
  Future<List<FeedCollectionModel>> getUserFeed(
    String userId, {
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      final isOwner = currentUserId == userId;

      // Build query: show all collections only if the owner is viewing,
      // otherwise hide private collections from public profile views.
      // IMPORTANT: .eq() filters must come before .order()/.range() in Supabase dart.
      var query = _supabase
          .from(SupabaseConfig.collectionsTable)
          .select(
            '*, photos(*), users!collections_user_id_fkey(*), likes(user_id), bookmarks(user_id)',
          )
          .eq('user_id', userId);

      if (!isOwner) {
        // Non-owners must not see private collections
        query = query.eq('is_private', false);
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final List<dynamic> data = response;

      final collections = <FeedCollectionModel>[];
      for (final item in data) {
        try {
          if (item['photos'] != null && item['photos'] is List) {
            final photosList = item['photos'] as List;
            photosList.sort((a, b) {
              final orderA = (a['sort_order'] as num?)?.toInt() ?? 0;
              final orderB = (b['sort_order'] as num?)?.toInt() ?? 0;
              return orderA.compareTo(orderB);
            });
          }
          collections.add(
            FeedCollectionModel.fromMap(
              item as Map<String, dynamic>,
              currentUserId: _supabase.auth.currentUser?.id,
            ),
          );
        } catch (e) {
          debugPrint(
            '[SupabaseFeedRepository] Parse error on user collection row: $e',
          );
        }
      }

      return collections;
    } on PostgrestException catch (e) {
      debugPrint(
        '[SupabaseFeedRepository] getUserFeed PostgrestException: ${e.message}',
      );
      throw DatabaseException('Failed to fetch user feed.', cause: e);
    } catch (e) {
      debugPrint('[SupabaseFeedRepository] getUserFeed fallback error: $e');
      throw DatabaseException(
        'An unexpected error occurred while fetching user feed.',
        cause: e,
      );
    }
  }

  @override
  Future<void> toggleLike(String collectionId, bool isLiked) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('User must be logged in to like a collection.');
    }

    try {
      if (isLiked) {
        // Add like
        await _supabase.from('likes').insert({
          'user_id': userId,
          'collection_id': collectionId,
        });

        // Notify collection owner (fire-and-forget, silently fails if needed)
        _notifyLike(collectionId: collectionId, senderId: userId);
      } else {
        // Remove like
        await _supabase.from('likes').delete().match({
          'user_id': userId,
          'collection_id': collectionId,
        });

        // Remove the like notification
        _removeLikeNotification(collectionId: collectionId, senderId: userId);
      }
    } on PostgrestException catch (e) {
      debugPrint('[SupabaseFeedRepository] Toggle like failed: ${e.message}');
      throw DatabaseException('Failed to toggle like.', cause: e);
    } catch (e) {
      debugPrint('[SupabaseFeedRepository] Unexpected fallback error: $e');
      throw DatabaseException(
        'An unexpected error occurred while toggling like.',
        cause: e,
      );
    }
  }

  /// Fire-and-forget: fetch owner then insert notification.
  Future<void> _notifyLike({
    required String collectionId,
    required String senderId,
  }) async {
    try {
      final res = await _supabase
          .from(SupabaseConfig.collectionsTable)
          .select('user_id')
          .eq('id', collectionId)
          .single();
      final ownerId = res['user_id'] as String?;
      if (ownerId == null || ownerId == senderId) return;

      final notifRepo = SupabaseNotificationRepository(_supabase);
      await notifRepo.insertNotification(
        type: 'like',
        receiverId: ownerId,
        collectionId: collectionId,
      );
    } catch (e) {
      debugPrint('[SupabaseFeedRepository] _notifyLike error: $e');
    }
  }

  /// Fire-and-forget: fetch owner then delete like notification.
  Future<void> _removeLikeNotification({
    required String collectionId,
    required String senderId,
  }) async {
    try {
      final res = await _supabase
          .from(SupabaseConfig.collectionsTable)
          .select('user_id')
          .eq('id', collectionId)
          .single();
      final ownerId = res['user_id'] as String?;
      if (ownerId == null || ownerId == senderId) return;

      final notifRepo = SupabaseNotificationRepository(_supabase);
      await notifRepo.deleteNotification(type: 'like', receiverId: ownerId);
    } catch (e) {
      debugPrint('[SupabaseFeedRepository] _removeLikeNotification error: $e');
    }
  }

  @override
  Future<void> deleteCollection(String collectionId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException(
        'User must be logged in to delete a collection.',
      );
    }

    try {
      // Delete the collection only if it belongs to the current user
      await _supabase.from(SupabaseConfig.collectionsTable).delete().match({
        'id': collectionId,
        'user_id': userId,
      });
    } on PostgrestException catch (e) {
      debugPrint(
        '[SupabaseFeedRepository] Collection delete failed: ${e.message}',
      );
      throw DatabaseException('Failed to delete collection.', cause: e);
    } catch (e) {
      debugPrint('[SupabaseFeedRepository] Unexpected delete error: $e');
      throw DatabaseException(
        'An unexpected error occurred while deleting collection.',
        cause: e,
      );
    }
  }

  @override
  Future<void> updateCollection({
    required String collectionId,
    String? title,
    bool? isPrivate,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException(
        'User must be logged in to update a collection.',
      );
    }

    final updates = <String, dynamic>{};
    if (title != null) updates['title'] = title;
    if (isPrivate != null) updates['is_private'] = isPrivate;

    if (updates.isEmpty) return;

    try {
      final response = await _supabase
          .from(SupabaseConfig.collectionsTable)
          .update(updates)
          .match({'id': collectionId, 'user_id': userId})
          .select()
          .single();

      // Database Confirmation Check
      if (isPrivate != null) {
        final dbIsPrivate = response['is_private'] as bool?;
        if (dbIsPrivate != isPrivate) {
          throw DatabaseException(
            'Gizlilik ayarı güncellenemedi. Lütfen tekrar deneyin.',
          );
        }
      }
    } on PostgrestException catch (e) {
      debugPrint(
        '[SupabaseFeedRepository] Update collection failed: ${e.message}',
      );
      throw DatabaseException('Failed to update collection.', cause: e);
    } catch (e) {
      debugPrint('[SupabaseFeedRepository] Unexpected update error: $e');
      throw DatabaseException(
        'An unexpected error occurred while updating collection.',
        cause: e,
      );
    }
  }

  @override
  Future<void> toggleBookmark(String collectionId, bool isBookmarked) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('User must be logged in to toggle bookmark.');
    }

    try {
      if (isBookmarked) {
        // Upsert: silently ignore if record already exists (prevents duplicate key errors)
        await _supabase.from('bookmarks').upsert({
          'user_id': userId,
          'collection_id': collectionId,
        }, onConflict: 'user_id, collection_id');
      } else {
        // Remove bookmark
        await _supabase.from('bookmarks').delete().match({
          'user_id': userId,
          'collection_id': collectionId,
        });
      }
    } on PostgrestException catch (e) {
      debugPrint(
        '[SupabaseFeedRepository] Toggle bookmark failed: ${e.message}',
      );
      throw DatabaseException('Failed to toggle bookmark.', cause: e);
    } catch (e) {
      debugPrint('[SupabaseFeedRepository] Unexpected fallback error: $e');
      throw DatabaseException(
        'An unexpected error occurred while toggling bookmark.',
        cause: e,
      );
    }
  }

  @override
  Future<void> deletePhotoFromCollection({
    required String collectionId,
    required String photoId,
    required String photoUrl,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('User must be logged in to delete a photo.');
    }

    try {
      // 1. Delete from Supabase Storage
      // Expected URL format: https://[project_ref].supabase.co/storage/v1/object/public/photos/[filePath]
      final uri = Uri.parse(photoUrl);
      final pathSegments = uri.pathSegments;
      // Find the index of 'photos' in the path
      final bucketIndex = pathSegments.indexOf('photos');
      if (bucketIndex != -1 && bucketIndex < pathSegments.length - 1) {
        // The file path is everything after the bucket name
        final filePath = pathSegments.sublist(bucketIndex + 1).join('/');
        await _supabase.storage.from('photos').remove([filePath]);
      }

      // 2. Delete from Supabase Database
      // The database policies should probably ensure the user owns the collection,
      // but we specify it in the match or trust the RLS policies.
      await _supabase.from('photos').delete().match({'id': photoId});
    } on PostgrestException catch (e) {
      debugPrint(
        '[SupabaseFeedRepository] Photo DB delete failed: ${e.message}',
      );
      throw DatabaseException(
        'Failed to delete photo from database.',
        cause: e,
      );
    } catch (e) {
      debugPrint('[SupabaseFeedRepository] Unexpected photo delete error: $e');
      throw DatabaseException(
        'An unexpected error occurred while deleting the photo.',
        cause: e,
      );
    }
  }
}
