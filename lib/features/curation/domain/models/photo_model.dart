// lib/features/curation/domain/models/photo_model.dart
// Pure Dart model for individual photos within a collection.

class PhotoModel {
  const PhotoModel({
    required this.id,
    required this.collectionId,
    required this.userId,
    required this.imageUrl,
    required this.storagePath,
    required this.aspectRatio,
    required this.sortOrder,
    required this.createdAt,
  });

  final String id;
  final String collectionId;
  final String userId;
  final String imageUrl;
  final String storagePath;
  final double aspectRatio;
  final int sortOrder;
  final DateTime createdAt;

  factory PhotoModel.fromMap(Map<String, dynamic> map) {
    return PhotoModel(
      id: map['id'] as String,
      collectionId: map['collection_id'] as String,
      userId: map['user_id'] as String,
      imageUrl: map['image_url'] as String,
      storagePath: map['storage_path'] as String,
      aspectRatio: (map['aspect_ratio'] as num?)?.toDouble() ?? 1.0,
      sortOrder: map['sort_order'] as int? ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toInsertMap() => {
    'collection_id': collectionId,
    // Note: user_id omitted in user's prompt but usually good to keep,
    // omitting for exact schema match based on user's instruction:
    // "collections_id, storage_path, image_url, aspect_ratio, sort_order"
    'storage_path': storagePath,
    'image_url': imageUrl,
    'aspect_ratio': aspectRatio,
    'sort_order': sortOrder,
  };
}
