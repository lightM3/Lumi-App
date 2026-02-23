// lib/features/notifications/data/supabase_notification_repository.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models/notification_model.dart';
import '../domain/notification_repository.dart';

class SupabaseNotificationRepository implements NotificationRepository {
  const SupabaseNotificationRepository(this._supabase);

  final SupabaseClient _supabase;

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  @override
  Future<List<NotificationModel>> getNotifications() async {
    final userId = _currentUserId;
    if (userId == null) return [];

    try {
      final response = await _supabase
          .from('notifications')
          .select(
            'id, type, sender_id, collection_id, is_read, created_at, '
            'sender:users!notifications_sender_id_fkey(username, avatar_url), '
            'collection:collections(photos(image_url))',
          )
          .eq('receiver_id', userId)
          .order('created_at', ascending: false)
          .limit(50);

      final List<dynamic> data = response;
      return data
          .map(
            (item) => NotificationModel.fromMap(item as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      debugPrint('[NotificationRepo] getNotifications error: $e');
      return [];
    }
  }

  @override
  Future<int> getUnreadCount() async {
    final userId = _currentUserId;
    if (userId == null) return 0;

    try {
      final response = await _supabase
          .from('notifications')
          .select('id')
          .eq('receiver_id', userId)
          .eq('is_read', false)
          .count(CountOption.exact);
      return response.count;
    } catch (e) {
      debugPrint('[NotificationRepo] getUnreadCount error: $e');
      return 0;
    }
  }

  @override
  Future<void> markAllAsRead() async {
    final userId = _currentUserId;
    if (userId == null) return;

    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('receiver_id', userId)
          .eq('is_read', false);
    } catch (e) {
      debugPrint('[NotificationRepo] markAllAsRead error: $e');
    }
  }

  @override
  Future<void> insertNotification({
    required String type,
    required String receiverId,
    String? collectionId,
  }) async {
    final senderId = _currentUserId;
    if (senderId == null || senderId == receiverId) return;

    try {
      await _supabase.from('notifications').insert({
        'type': type,
        'sender_id': senderId,
        'receiver_id': receiverId,
        'collection_id': collectionId,
        'is_read': false,
      });
    } catch (e) {
      // Silently fail — notification failures should not break core UX
      debugPrint('[NotificationRepo] insertNotification error: $e');
    }
  }

  @override
  Future<void> deleteNotification({
    required String type,
    required String receiverId,
  }) async {
    final senderId = _currentUserId;
    if (senderId == null) return;

    try {
      await _supabase
          .from('notifications')
          .delete()
          .eq('type', type)
          .eq('sender_id', senderId)
          .eq('receiver_id', receiverId);
    } catch (e) {
      debugPrint('[NotificationRepo] deleteNotification error: $e');
    }
  }
}
