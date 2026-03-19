// lib/features/feed/presentation/screens/discover_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../notifications/presentation/controllers/notification_controller.dart';
import '../controllers/feed_controller.dart';
import '../widgets/feed_photo_card.dart';
import '../widgets/glass_bottom_nav.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(feedControllerProvider.notifier).fetchMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(feedControllerProvider);
    final feedNotifier = ref.read(feedControllerProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.inkBlack,
      extendBody: true, // Crucial for GlassBottomNav to float over content
      appBar: AppBar(
        title: const Text('Discover', style: AppTextStyles.displayMedium),
        actions: [
          // ── Notification Bell with Unread Badge ─────────────────────────
          Consumer(
            builder: (context, ref, _) {
              final unreadAsync = ref.watch(unreadNotificationCountProvider);
              final unreadCount = unreadAsync.valueOrNull ?? 0;

              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(LucideIcons.bell),
                    onPressed: () => context.push('/notifications'),
                    tooltip: 'Bildirimler',
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF6C4FCA),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(LucideIcons.search),
            onPressed: () => context.push('/search'),
          ),
          PopupMenuButton<FeedSortType>(
            icon: const Icon(LucideIcons.listFilter),
            tooltip: 'Sıralama Seçimi',
            initialValue: feedNotifier.sortType,
            color: AppColors.inkSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            onSelected: (FeedSortType newType) {
              feedNotifier.setSortType(newType);
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem(
                value: FeedSortType.random,
                child: Row(
                  children: [
                    Icon(
                      LucideIcons.shuffle,
                      color: feedNotifier.sortType == FeedSortType.random
                          ? AppColors.accentCream
                          : AppColors.inkMuted,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Rastgele',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: feedNotifier.sortType == FeedSortType.random
                            ? AppColors.accentCream
                            : AppColors.inkForeground,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: FeedSortType.latest,
                child: Row(
                  children: [
                    Icon(
                      LucideIcons.clock,
                      color: feedNotifier.sortType == FeedSortType.latest
                          ? AppColors.accentCream
                          : AppColors.inkMuted,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'En Yeniler',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: feedNotifier.sortType == FeedSortType.latest
                            ? AppColors.accentCream
                            : AppColors.inkForeground,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: feedState.when(
        data: (collections) {
          if (collections.isEmpty && !feedNotifier.isLoadingMore) {
            return Center(
              child: Text(
                'No public collections found.',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.inkMuted,
                ),
              ),
            );
          }

          return Stack(
            children: [
              RefreshIndicator(
                onRefresh: () =>
                    ref.read(feedControllerProvider.notifier).refreshFeed(),
                color: AppColors.accentCream,
                backgroundColor: AppColors.inkSurface,
                child: CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.md,
                      ),
                      sliver: SliverMasonryGrid.count(
                        crossAxisCount: 2,
                        mainAxisSpacing: AppSpacing.md,
                        crossAxisSpacing: AppSpacing.md,
                        childCount: collections.length,
                        itemBuilder: (context, index) {
                          final collection = collections[index];
                          return FeedPhotoCard(
                            collection: collection,
                            onTap: () {
                              context.push(
                                '/collection/${collection.collectionId}',
                                extra: collection,
                              );
                            },
                          );
                        },
                      ),
                    ),
                    if (feedNotifier.isLoadingMore)
                      const SliverPadding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                        sliver: SliverToBoxAdapter(
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppColors.accentCream,
                            ),
                          ),
                        ),
                      ),
                    if (feedNotifier.hasReachedMax && collections.isNotEmpty)
                      SliverPadding(
                        padding: const EdgeInsets.only(
                          bottom: 120,
                          top: AppSpacing.md,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: Center(
                            child: Text(
                              "That's all for now.",
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.inkMuted,
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      const SliverPadding(
                        padding: EdgeInsets.only(bottom: 100),
                      ), // Space for bottom nav
                  ],
                ),
              ),
              // V1.2: Smooth Overlay Loading
              // Displays a semi-transparent loading screen over the current feed
              // while sorting is being applied (avoids full screen flash)
              if (feedState.isLoading && !feedNotifier.isLoadingMore && collections.isNotEmpty)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.5),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.accentCream,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accentCream),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                LucideIcons.alertCircle,
                color: AppColors.error,
                size: 48,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Failed to load feed',
                style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.error,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton.icon(
                onPressed: () =>
                    ref.read(feedControllerProvider.notifier).refreshFeed(),
                icon: const Icon(LucideIcons.refreshCw, size: 16),
                label: const Text('Retry'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const GlassBottomNav(),
    );
  }
}
