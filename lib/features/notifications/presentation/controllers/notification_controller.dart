// lib/features/notifications/presentation/controllers/notification_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/supabase_notification_repository.dart';
import '../../domain/models/notification_model.dart';
import '../../domain/notification_repository.dart';

// ── Repository Provider ────────────────────────────────────────────────────────

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return SupabaseNotificationRepository(Supabase.instance.client);
});

// ── Unread Count Provider (for badge) ─────────────────────────────────────────

final unreadNotificationCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(notificationRepositoryProvider);
  return repo.getUnreadCount();
});

// ── Notifications List Controller ─────────────────────────────────────────────

class NotificationController extends AsyncNotifier<List<NotificationModel>> {
  @override
  Future<List<NotificationModel>> build() async {
    return _fetch();
  }

  Future<List<NotificationModel>> _fetch() async {
    final repo = ref.read(notificationRepositoryProvider);
    return repo.getNotifications();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  /// Marks all as read and refreshes unread count badge.
  Future<void> markAllAsRead() async {
    final repo = ref.read(notificationRepositoryProvider);
    await repo.markAllAsRead();
    // Invalidate the badge provider so it refetches
    ref.invalidateSelf();
    ref.invalidate(unreadNotificationCountProvider);
  }
}

final notificationControllerProvider =
    AsyncNotifierProvider<NotificationController, List<NotificationModel>>(
      NotificationController.new,
    );
