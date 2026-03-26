// lib/features/comment/domain/models/comment_model.dart

class CommentModel {
  const CommentModel({
    required this.id,
    required this.collectionId,
    required this.userId,
    this.parentId,
    required this.content,
    required this.replyCount,
    required this.likeCount,
    required this.isLiked,
    required this.createdAt,
    required this.authorUsername,
    this.authorAvatarUrl,
    this.replies = const [],
  });

  final String id;
  final String collectionId;
  final String userId;
  final String? parentId;
  final String content;
  final int replyCount;
  final int likeCount;
  final bool isLiked;
  final DateTime createdAt;
  
  // Joined from "users" table
  final String authorUsername;
  final String? authorAvatarUrl;

  // Local state only, for nesting replies visually without reloading everything
  final List<CommentModel> replies;

  CommentModel copyWith({
    String? id,
    String? collectionId,
    String? userId,
    String? parentId,
    String? content,
    int? replyCount,
    int? likeCount,
    bool? isLiked,
    DateTime? createdAt,
    String? authorUsername,
    String? authorAvatarUrl,
    List<CommentModel>? replies,
  }) {
    return CommentModel(
      id: id ?? this.id,
      collectionId: collectionId ?? this.collectionId,
      userId: userId ?? this.userId,
      parentId: parentId ?? this.parentId,
      content: content ?? this.content,
      replyCount: replyCount ?? this.replyCount,
      likeCount: likeCount ?? this.likeCount,
      isLiked: isLiked ?? this.isLiked,
      createdAt: createdAt ?? this.createdAt,
      authorUsername: authorUsername ?? this.authorUsername,
      authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
      replies: replies ?? this.replies,
    );
  }

  factory CommentModel.fromMap(
    Map<String, dynamic> map, {
    String? currentUserId,
  }) {
    // Basic fields
    final id = map['id'] as String;
    final collectionId = map['collection_id'] as String;
    final userId = map['user_id'] as String;
    final parentId = map['parent_id'] as String?;
    final content = map['content'] as String;
    final replyCount = map['reply_count'] as int? ?? 0;
    final likeCount = map['like_count'] as int? ?? 0;
    
    // Check if current user liked it via joined table 'comment_likes'
    final commentLikes = map['comment_likes'] as List<dynamic>? ?? [];
    final isLiked = currentUserId != null &&
        commentLikes.any((like) => like['user_id'] == currentUserId);

    final createdAt = DateTime.parse(map['created_at'] as String);

    // User relation (Supabase inner join on "users")
    final userMap = map['users'] as Map<String, dynamic>?;
    final username = userMap?['username'] as String? ?? 'user';
    final avatarUrl = userMap?['avatar_url'] as String?;

    return CommentModel(
      id: id,
      collectionId: collectionId,
      userId: userId,
      parentId: parentId,
      content: content,
      replyCount: replyCount,
      likeCount: likeCount,
      isLiked: isLiked,
      createdAt: createdAt,
      authorUsername: username,
      authorAvatarUrl: avatarUrl,
    );
  }
}
