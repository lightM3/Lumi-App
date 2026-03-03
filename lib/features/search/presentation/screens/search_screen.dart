// lib/features/search/presentation/screens/search_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../feed/presentation/widgets/feed_photo_card.dart';
import '../controllers/search_controller.dart' as lumi_search;

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
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
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(lumi_search.searchControllerProvider.notifier).fetchMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(lumi_search.searchControllerProvider);
    final searchNotifier = ref.read(
      lumi_search.searchControllerProvider.notifier,
    );

    return Scaffold(
      backgroundColor: AppColors.inkBlack,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: Colors.black.withValues(alpha: 0.6),
              padding: EdgeInsets.only(
                top: MediaQuery.paddingOf(context).top + AppSpacing.sm,
                left: AppSpacing.md,
                right: AppSpacing.md,
                bottom: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      LucideIcons.arrowLeft,
                      color: Colors.white,
                    ),
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.inkSurface,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusXl,
                        ),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        controller: _searchController,
                        autofocus: true,
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: Colors.white,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search collections...',
                          hintStyle: AppTextStyles.bodyLarge.copyWith(
                            color: AppColors.inkMuted,
                          ),
                          prefixIcon: const Icon(
                            LucideIcons.search,
                            color: AppColors.inkMuted,
                            size: 20,
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    LucideIcons.xCircle,
                                    color: AppColors.inkMuted,
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    ref
                                        .read(
                                          lumi_search
                                              .searchControllerProvider
                                              .notifier,
                                        )
                                        .onSearchQueryChanged('');
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: 11,
                          ),
                        ),
                        onChanged: (value) {
                          ref
                              .read(
                                lumi_search.searchControllerProvider.notifier,
                              )
                              .onSearchQueryChanged(value);
                          // Trigger UI update to switch the suffix icon visibility.
                          setState(() {});
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: searchState.when(
        data: (collections) {
          if (collections.isEmpty &&
              _searchController.text.isNotEmpty &&
              !searchNotifier.isLoadingMore) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    LucideIcons.searchX,
                    size: 48,
                    color: AppColors.inkMuted,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'No collections found for "${_searchController.text}"',
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.inkMuted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          } else if (collections.isEmpty && !searchNotifier.isLoadingMore) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    LucideIcons.search,
                    size: 48,
                    color: AppColors.inkMuted,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Type a title to explore...',
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.inkMuted,
                    ),
                  ),
                ],
              ),
            );
          }

          return CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverPadding(
                padding: EdgeInsets.only(
                  top: MediaQuery.paddingOf(context).top + 80 + AppSpacing.md,
                  left: AppSpacing.md,
                  right: AppSpacing.md,
                  bottom: AppSpacing.md,
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
                        // dismiss keyboard
                        FocusScope.of(context).unfocus();
                        context.push(
                          '/collection/${collection.collectionId}',
                          extra: collection,
                        );
                      },
                    );
                  },
                ),
              ),
              if (searchNotifier.isLoadingMore)
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
              if (searchNotifier.hasReachedMax && collections.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.only(
                    bottom: AppSpacing.xl,
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
                  padding: EdgeInsets.only(bottom: AppSpacing.xl),
                ),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accentCream),
        ),
        error: (error, stack) => Center(
          child: Text(
            'Failed to search: $error',
            style: AppTextStyles.bodyLarge.copyWith(color: AppColors.error),
          ),
        ),
      ),
    );
  }
}
