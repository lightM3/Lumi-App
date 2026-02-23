// lib/features/profile/domain/models/board_model.dart

class BoardModel {
  const BoardModel({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    this.coverImageUrl,
    this.isPrivate = false,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String title;
  final String? description;
  final String? coverImageUrl;
  final bool isPrivate;
  final DateTime createdAt;

  factory BoardModel.fromMap(Map<String, dynamic> map) {
    return BoardModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      coverImageUrl: map['cover_image_url'] as String?,
      isPrivate: map['is_private'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'title': title,
      'description': description,
      'cover_image_url': coverImageUrl,
      'is_private': isPrivate,
    };
  }
}
