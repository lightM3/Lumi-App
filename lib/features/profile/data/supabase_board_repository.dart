// lib/features/profile/data/supabase_board_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/board_repository.dart';
import '../domain/models/board_model.dart';
import '../../feed/domain/models/feed_collection_model.dart';

class SupabaseBoardRepository implements BoardRepository {
  SupabaseBoardRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<List<BoardModel>> getUserBoards(String userId) async {
    final response = await _client
        .from('boards')
        .select()
        .eq('user_id', userId)
        .order('created_at');

    return (response as List).map((m) => BoardModel.fromMap(m)).toList();
  }

  @override
  Future<BoardModel> createBoard(BoardModel board) async {
    final response = await _client
        .from('boards')
        .insert(board.toMap())
        .select()
        .single();

    return BoardModel.fromMap(response);
  }

  @override
  Future<void> addCollectionToBoard(String boardId, String collectionId) async {
    await _client.from('board_collections').insert({
      'board_id': boardId,
      'collection_id': collectionId,
    });
  }

  @override
  Future<void> removeCollectionFromBoard(
    String boardId,
    String collectionId,
  ) async {
    await _client
        .from('board_collections')
        .delete()
        .eq('board_id', boardId)
        .eq('collection_id', collectionId);
  }

  @override
  Future<List<String>> getBoardIdsForCollection(String collectionId) async {
    final response = await _client
        .from('board_collections')
        .select('board_id')
        .eq('collection_id', collectionId);

    return (response as List).map((m) => m['board_id'] as String).toList();
  }

  @override
  Future<List<FeedCollectionModel>> getBoardCollections(String boardId) async {
    // This requires a complex join to get full collection data
    final response = await _client
        .from('board_collections')
        .select(
          'collections(*, photos(*), users!collections_user_id_fkey(*), likes(user_id), bookmarks(user_id))',
        )
        .eq('board_id', boardId);

    return (response as List)
        .map((m) => FeedCollectionModel.fromMap(m['collections']))
        .toList();
  }

  @override
  Future<BoardModel> updateBoard(BoardModel board) async {
    final response = await _client
        .from('boards')
        .update(board.toMap())
        .eq('id', board.id)
        .select()
        .single();

    return BoardModel.fromMap(response);
  }
}
