// lib/features/notifications/presentation/screens/notifications_screen.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../domain/models/notification_model.dart';
import '../controllers/notification_controller.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Mark all as read when user opens the screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationControllerProvider.notifier).markAllAsRead();
    });
  }

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.inkBlack,
      appBar: AppBar(
        backgroundColor: AppColors.inkBlack,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Notifications',
          style: AppTextStyles.headlineMedium.copyWith(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              LucideIcons.refreshCw,
              color: Colors.white54,
              size: 18,
            ),
            onPressed: () =>
                ref.read(notificationControllerProvider.notifier).refresh(),
          ),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accentCream),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                LucideIcons.alertCircle,
                color: AppColors.error,
                size: 40,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Bildirimler yüklenemedi.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.inkMuted,
                ),
              ),
            ],
          ),
        ),
        data: (notifications) {
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    LucideIcons.bell,
                    size: 56,
                    color: AppColors.inkMuted.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Henüz bildirim yok.',
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.inkMuted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Beğenilen veya takip edildiğinde burada görünür.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.inkMuted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.md,
              horizontal: AppSpacing.md,
            ),
            itemCount: notifications.length,
            separatorBuilder: (ctx, idx) =>
                const Divider(color: AppColors.inkBorder, height: 1),
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return _NotificationTile(notification: notification);
            },
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification});

  final NotificationModel notification;

  String get _message {
    switch (notification.type) {
      case 'like':
        return '${notification.senderUsername} koleksiyonunu beğendi 💜';
      case 'comment':
        return '${notification.senderUsername} koleksiyonuna bir yorum yaptı 💬';
      case 'comment_like':
        return '${notification.senderUsername} yorumunu beğendi ❤️';
      case 'follow':
      default:
        return '${notification.senderUsername} seni takip etmeye başladı 🔔';
    }
  }

  IconData get _icon {
    switch (notification.type) {
      case 'like':
      case 'comment_like':
        return LucideIcons.heart;
      case 'comment':
        return LucideIcons.messageCircle;
      case 'follow':
      default:
        return LucideIcons.userPlus;
    }
  }

  Color get _iconColor {
    switch (notification.type) {
      case 'like':
      case 'comment_like':
        return AppColors.accentRose;
      case 'comment':
        return Colors.blueAccent;
      case 'follow':
      default:
        return const Color(0xFF6C4FCA);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;

    return InkWell(
      onTap: () {
        if (notification.type == 'like' && notification.collectionId != null) {
          // Navigate to the collection — we don't have the full model here,
          // so we push to profile of the sender as a fallback
          context.push('/profile/${notification.senderId}');
        } else {
          context.push('/profile/${notification.senderId}');
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
          horizontal: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isUnread
              ? const Color(0xFF6C4FCA).withValues(alpha: 0.07)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Avatar ──────────────────────────────────────────────────────
            Stack(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.inkSurface,
                  backgroundImage: notification.senderAvatarUrl != null
                      ? CachedNetworkImageProvider(
                          notification.senderAvatarUrl!,
                        )
                      : null,
                  child: notification.senderAvatarUrl == null
                      ? const Icon(
                          LucideIcons.user,
                          color: AppColors.inkMuted,
                          size: 20,
                        )
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: AppColors.inkBlack,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _icon,
                      size: 10,
                      color: _iconColor,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(width: AppSpacing.md),

            // ── Text ─────────────────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _message,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.white,
                      fontWeight: isUnread
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeago.format(
                      notification.createdAt,
                      locale: 'tr',
                      allowFromNow: true,
                    ),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),

            // ── Collection Thumbnail (for likes and comments) ─────────────────────────────
            if ((notification.type == 'like' || notification.type == 'comment' || notification.type == 'comment_like') &&
                notification.collectionCoverUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: notification.collectionCoverUrl!,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorWidget: (ctx, url, err) => const SizedBox.shrink(),
                ),
              ),

            // ── Unread dot ────────────────────────────────────────────────────
            if (isUnread)
              const Padding(
                padding: EdgeInsets.only(left: AppSpacing.sm, top: 4),
                child: CircleAvatar(
                  radius: 4,
                  backgroundColor: Color(0xFF6C4FCA),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
