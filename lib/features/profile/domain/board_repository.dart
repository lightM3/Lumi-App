// lib/features/profile/domain/board_repository.dart
import 'models/board_model.dart';
import '../../feed/domain/models/feed_collection_model.dart';

abstract interface class BoardRepository {
  Future<List<BoardModel>> getUserBoards(String userId);
  Future<BoardModel> createBoard(BoardModel board);
  Future<void> addCollectionToBoard(String boardId, String collectionId);
  Future<void> removeCollectionFromBoard(String boardId, String collectionId);
  Future<List<String>> getBoardIdsForCollection(String collectionId);
  Future<List<FeedCollectionModel>> getBoardCollections(String boardId);
  Future<BoardModel> updateBoard(BoardModel board);
}
