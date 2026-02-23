// lib/features/curation/domain/models/collection_model.dart
// Pure Dart — no Supabase dependency.

class CollectionModel {
  const CollectionModel({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    this.dominantColor,
    this.isPrivate = false,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String title;
  final String? description;
  final String? dominantColor; // hex e.g. "#6C4FCA"
  final bool isPrivate;
  final DateTime createdAt;

  factory CollectionModel.fromMap(Map<String, dynamic> map) {
    return CollectionModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      dominantColor: map['dominant_color'] as String?,
      isPrivate: map['is_private'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toInsertMap() => {
    'user_id': userId,
    'title': title,
    if (description != null && description!.isNotEmpty)
      'description': description,
    if (dominantColor != null) 'dominant_color': dominantColor,
    'is_private': isPrivate,
  };
}
