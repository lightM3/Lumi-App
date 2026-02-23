// lib/features/notifications/domain/models/notification_model.dart

class NotificationModel {
  const NotificationModel({
    required this.id,
    required this.type,
    required this.senderId,
    required this.senderUsername,
    required this.senderAvatarUrl,
    this.collectionId,
    this.collectionCoverUrl,
    required this.isRead,
    required this.createdAt,
  });

  final String id;

  /// 'like' or 'follow'
  final String type;
  final String senderId;
  final String senderUsername;
  final String? senderAvatarUrl;
  final String? collectionId;
  final String? collectionCoverUrl;
  final bool isRead;
  final DateTime createdAt;

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    final sender = map['sender'] as Map<String, dynamic>? ?? {};
    final collection = map['collection'] as Map<String, dynamic>?;
    final firstPhoto = (collection?['photos'] as List?)?.isNotEmpty == true
        ? (collection!['photos'] as List).first as Map<String, dynamic>
        : null;

    return NotificationModel(
      id: map['id'] as String,
      type: map['type'] as String,
      senderId: map['sender_id'] as String,
      senderUsername: sender['username'] as String? ?? 'Unknown',
      senderAvatarUrl: sender['avatar_url'] as String?,
      collectionId: map['collection_id'] as String?,
      collectionCoverUrl: firstPhoto?['image_url'] as String?,
      isRead: map['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
