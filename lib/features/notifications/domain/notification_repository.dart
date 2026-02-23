// lib/features/notifications/domain/notification_repository.dart
import 'models/notification_model.dart';

abstract class NotificationRepository {
  /// Fetches notifications for the currently authenticated user.
  Future<List<NotificationModel>> getNotifications();

  /// Fetches the count of unread notifications.
  Future<int> getUnreadCount();

  /// Marks all unread notifications as read.
  Future<void> markAllAsRead();

  /// Inserts a notification record.
  Future<void> insertNotification({
    required String type,
    required String receiverId,
    String? collectionId,
  });

  /// Deletes a notification record (e.g. on unlike / unfollow).
  Future<void> deleteNotification({
    required String type,
    required String receiverId,
  });
}
