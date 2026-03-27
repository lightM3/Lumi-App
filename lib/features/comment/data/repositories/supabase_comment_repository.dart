// lib/features/comment/data/repositories/supabase_comment_repository.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/utils/either.dart';
import '../../domain/failures/comment_failure.dart';
import '../../domain/models/comment_model.dart';
import '../../domain/repositories/comment_repository.dart';

class SupabaseCommentRepository implements CommentRepository {
  final SupabaseClient _client;

  const SupabaseCommentRepository(this._client);

  @override
  Future<Either<CommentFailure, List<CommentModel>>> getComments({
    required String collectionId,
  }) async {
    try {
      final response = await _client
          .from('comments')
          .select('*, users(username, avatar_url), comment_likes(user_id)')
          .eq('collection_id', collectionId)
          .isFilter('parent_id', null)
          .order('created_at', ascending: false);

      final currentUserId = _client.auth.currentUser?.id;

      final comments = (response as List<dynamic>)
          .map((e) => CommentModel.fromMap(e as Map<String, dynamic>, currentUserId: currentUserId))
          .toList();

      return Right(comments);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return const Left(ServerFailure());
    }
  }

  @override
  Future<Either<CommentFailure, List<CommentModel>>> getReplies({
    required String collectionId,
    required String parentId,
    String? lastCreatedAt,
    int limit = 10,
    int offset = 0,
  }) async {
    try {
      var query = _client
          .from('comments')
          .select('*, users(username, avatar_url), comment_likes(user_id)')
          .eq('collection_id', collectionId)
          .eq('parent_id', parentId);

      if (lastCreatedAt != null) {
        query = query.gt('created_at', lastCreatedAt);
      }

      final response = await query
          .order('created_at', ascending: true)
          .range(offset, offset + limit - 1);

      final currentUserId = _client.auth.currentUser?.id;

      final replies = (response as List<dynamic>)
          .map((e) => CommentModel.fromMap(e as Map<String, dynamic>, currentUserId: currentUserId))
          .toList();

      return Right(replies);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return const Left(ServerFailure());
    }
  }

  @override
  Future<Either<CommentFailure, CommentModel>> postComment({
    required String collectionId,
    required String userId,
    required String content,
    String? parentId,
  }) async {
    try {
      final response = await _client.from('comments').insert({
        'collection_id': collectionId,
        'user_id': userId,
        'content': content,
        // ignore: prefer_null_aware_elements
        if (parentId != null) 'parent_id': parentId,
      }).select('*, users(username, avatar_url), comment_likes(user_id)').single();

      final model = CommentModel.fromMap(response, currentUserId: _client.auth.currentUser?.id);

      // If it's a reply, increment parent's reply_count 
      // Note: Ideally handled by a DB trigger, but we can do it client-side 
      // if no trigger is set. Or assume trigger exists. 
      // To be safe without a trigger we can try an RPC or update.
      // Easiest is assuming user will add DB trigger or we do it here:
      /*
      if (parentId != null) {
        await _client.rpc('increment_reply_count', params: {'comment_id': parentId});
      }
      */

      return Right(model);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return const Left(ServerFailure());
    }
  }

  @override
  Future<Either<CommentFailure, bool>> deleteComment({
    required String commentId,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return const Left(AuthenticationFailure());

      await _client.from('comments').delete().match({
        'id': commentId,
        'user_id': userId,
      });

      return const Right(true);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return const Left(ServerFailure());
    }
  }

  @override
  Future<Either<CommentFailure, bool>> toggleLikeComment({
    required String commentId,
    required bool isLiked,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return const Left(AuthenticationFailure());

      if (isLiked) {
        await _client.from('comment_likes').insert({
          'user_id': userId,
          'comment_id': commentId,
        });
      } else {
        await _client
            .from('comment_likes')
            .delete()
            .eq('comment_id', commentId)
            .eq('user_id', userId);
      }

      return const Right(true);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return const Left(ServerFailure());
    }
  }
}
