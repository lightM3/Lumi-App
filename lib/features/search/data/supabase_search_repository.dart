// lib/features/search/data/supabase_search_repository.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/supabase_config.dart';
import '../../../core/error/custom_exceptions.dart';
import '../../feed/domain/models/feed_collection_model.dart';
import '../domain/search_repository.dart';

class SupabaseSearchRepository implements SearchRepository {
  const SupabaseSearchRepository(this._supabase);

  final SupabaseClient _supabase;

  @override
  Future<List<FeedCollectionModel>> searchCollections(
    String query, {
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      if (query.trim().isEmpty) return [];

      // ILIKE query on 'title', joining photos and users
      final response = await _supabase
          .from(SupabaseConfig.collectionsTable)
          .select(
            '*, photos(*), users!collections_user_id_fkey(*), likes(user_id), bookmarks(user_id)',
          )
          .eq('is_public', true)
          .ilike('title', '%${query.trim()}%')
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
          debugPrint('[SupabaseSearchRepository] Parse error on row: $e');
        }
      }

      return collections;
    } on PostgrestException catch (e) {
      debugPrint('[SupabaseSearchRepository] PostgrestException: ${e.message}');
      throw DatabaseException('Failed to search collections.', cause: e);
    } catch (e) {
      debugPrint('[SupabaseSearchRepository] Unexpected fallback error: $e');
      throw DatabaseException(
        'An unexpected error occurred while searching.',
        cause: e,
      );
    }
  }
}
