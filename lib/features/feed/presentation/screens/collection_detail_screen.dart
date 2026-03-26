// lib/features/feed/presentation/screens/collection_detail_screen.dart
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../auth/presentation/widgets/guest_guard.dart';
import '../../../profile/presentation/controllers/profile_controller.dart';
import '../../../profile/presentation/controllers/collection_board_membership_controller.dart';
import '../../domain/models/feed_collection_model.dart';
import '../controllers/feed_controller.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import '../../../comment/presentation/widgets/collection_comments_sheet.dart';

class CollectionDetailScreen extends ConsumerStatefulWidget {
  const CollectionDetailScreen({super.key, required this.collection});

  final FeedCollectionModel collection;

  @override
  ConsumerState<CollectionDetailScreen> createState() =>
      _CollectionDetailScreenState();
}

class _CollectionDetailScreenState extends ConsumerState<CollectionDetailScreen>
    with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  int _currentIndex = 0;
  bool _isUiVisible = true;

  // Animation for Double Tap Heart
  late AnimationController _heartAnimationController;
  late Animation<double> _heartScaleAnimation;
  bool _showHeart = false;
  
  bool _isDescriptionExpanded = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    _heartAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _heartScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: 1.2,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(1.2), weight: 60),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.2,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 30,
      ),
    ]).animate(_heartAnimationController);

    // Ensure this collection is tracked in FeedController so that
    // incrementCommentCount / decrementCommentCount work even when
    // the detail screen is opened from the profile / board page.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(feedControllerProvider.notifier).registerCollection(widget.collection);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _heartAnimationController.dispose();
    super.dispose();
  }

  Future<void> _handleDoubleTap(FeedCollectionModel collection) async {
    final isAuth = await GuestGuard.checkAuthAndShowModal(context, ref);
    if (!isAuth) return;

    if (!collection.isLiked) {
      ref
          .read(feedControllerProvider.notifier)
          .toggleLike(collection.collectionId);
    }
    HapticFeedback.heavyImpact();
    setState(() => _showHeart = true);
    _heartAnimationController.forward(from: 0.0).then((_) {
      if (mounted) {
        setState(() => _showHeart = false);
      }
    });
  }

  void _toggleUi() {
    setState(() {
      _isUiVisible = !_isUiVisible;
    });
    // Optional: Hide/Show system status bars if true fullscreen is desired
    if (_isUiVisible) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  Color _parseHexColor(String? hexString) {
    if (hexString == null || hexString.isEmpty) return AppColors.inkSurface;
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    try {
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return AppColors.inkSurface;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 0. Listen to Feed Controller for optimistic like updates
    final latestCollection =
        ref
            .watch(feedControllerProvider)
            .value
            ?.firstWhere(
              (c) => c.collectionId == widget.collection.collectionId,
              orElse: () => widget.collection,
            ) ??
        widget.collection;

    final bgColor = _parseHexColor(latestCollection.dominantColor);
    final photos = latestCollection.photos;

    return Scaffold(
      backgroundColor: Colors.black, // Force deep dark theme
      extendBodyBehindAppBar: true,
      extendBody: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 0. Ambient Glow Background
          Positioned.fill(
            child: Opacity(
              opacity: 0.15, // 15% opacity to make it very subtle
              child: Container(color: bgColor),
            ),
          ),
          // 0.1 Blur layer to diffuse the ambient glow seamlessly
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: const SizedBox(),
            ),
          ),

          // 1. Fullscreen Carousel (PageView) + Gestures
          GestureDetector(
            onTap: _toggleUi,
            onDoubleTap: () => _handleDoubleTap(latestCollection),
            onVerticalDragUpdate: (details) {
              // Swipe down to dismiss logic
              if (details.delta.dy > 10) {
                // Restore system UI before popping
                SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
                context.pop();
              }
            },
            child: PageView.builder(
              controller: _pageController,
              itemCount: photos.length,
              physics: const BouncingScrollPhysics(),
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
              },
              itemBuilder: (context, index) {
                final photo = photos[index];

                Widget imageWidget = CachedNetworkImage(
                  imageUrl: photo.imageUrl,
                  fit: BoxFit.contain, // Show entire image without cropping
                  placeholder: (context, url) => const SizedBox(),
                  errorWidget: (context, url, _) => const Center(
                    child: Icon(
                      LucideIcons.imageOff,
                      color: Colors.white54,
                      size: 48,
                    ),
                  ),
                );

                // Add hero animation only for the first photo which was clicked from the feed
                if (index == 0) {
                  return Hero(
                    tag: 'collection-${widget.collection.collectionId}',
                    child: imageWidget,
                  );
                }

                return imageWidget;
              },
            ),
          ),

          // 1.1 Big Heart Animation Overlay
          if (_showHeart)
            IgnorePointer(
              child: Center(
                child: ScaleTransition(
                  scale: _heartScaleAnimation,
                  child: Icon(
                    Icons.favorite,
                    color: AppColors.accentRose,
                    size: 100,
                    shadows: [Shadow(color: Colors.black45, blurRadius: 15)],
                  ),
                ),
              ),
            ),

          // 2. Animated Back Button / Top Bar
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            top: _isUiVisible ? 0 : -100,
            left: 0,
            right: 0,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: _isUiVisible ? 1.0 : 0.0,
              child: Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.paddingOf(context).top + AppSpacing.sm,
                  left: AppSpacing.md,
                  right: AppSpacing.md,
                  bottom: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.6),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(
                        LucideIcons.arrowLeft,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        // Restore system UI before popping
                        SystemChrome.setEnabledSystemUIMode(
                          SystemUiMode.edgeToEdge,
                        );
                        context.pop();
                      },
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Download Button
                        IconButton(
                          icon: const Icon(
                            LucideIcons.download,
                            color: Colors.white,
                          ),
                          onPressed: () => _downloadCurrentPhoto(
                            photos[_currentIndex].imageUrl,
                          ),
                        ),
                        IconButton(
                          icon: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            transitionBuilder: (child, animation) =>
                                ScaleTransition(scale: animation, child: child),
                            child: Icon(
                              latestCollection.isLiked
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              key: ValueKey(latestCollection.isLiked),
                              color: latestCollection.isLiked
                                  ? AppColors.accentRose
                                  : Colors.white,
                            ),
                          ),
                          onPressed: () async {
                            HapticFeedback.mediumImpact();
                            final isAuth =
                                await GuestGuard.checkAuthAndShowModal(
                                  context,
                                  ref,
                                );
                            if (!isAuth) return;

                            if (context.mounted) {
                              ref
                                  .read(feedControllerProvider.notifier)
                                  .toggleLike(latestCollection.collectionId);
                            }
                          },
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        // Bookmark Button
                        IconButton(
                          icon: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            transitionBuilder: (child, animation) =>
                                ScaleTransition(scale: animation, child: child),
                            child: Icon(
                              latestCollection.isBookmarked
                                  ? Icons.bookmark
                                  : Icons.bookmark_border,
                              key: ValueKey(latestCollection.isBookmarked),
                              color: latestCollection.isBookmarked
                                  ? Colors.white
                                  : Colors.white,
                            ),
                          ),
                          onPressed: () async {
                            HapticFeedback.mediumImpact();
                            final isAuth =
                                await GuestGuard.checkAuthAndShowModal(
                                  context,
                                  ref,
                                );
                            if (!isAuth) return;

                            if (context.mounted) {
                              _showBoardSelectionSheet(
                                context,
                                latestCollection.collectionId,
                              );
                            }
                          },
                        ),
                        if (Supabase.instance.client.auth.currentUser?.id ==
                            latestCollection.userId)
                          IconButton(
                            icon: const Icon(
                              Icons.more_vert,
                              color: Colors.white,
                            ),
                            onPressed: () => _showActionBottomSheet(
                              context,
                              latestCollection,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3. Glassmorphism Detail Card + Thumbnails
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            bottom: _isUiVisible ? 0 : -300,
            left: 0,
            right: 0,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: _isUiVisible ? 1.0 : 0.0,
              child: GestureDetector(
                child: Column(
                  mainAxisSize: MainAxisSize.min, // Hug contents at the bottom
                  children: [
                    // Detail Card
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusXl,
                        ),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                          child: Container(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusXl,
                              ),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.15),
                                width: 0.5,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.collection.title,
                                  style: AppTextStyles.titleLarge.copyWith(
                                    color: Colors.white,
                                  ),
                                ),
                                if (widget.collection.description != null &&
                                    widget.collection.description!.isNotEmpty) ...[
                                  const SizedBox(height: AppSpacing.sm),
                                  GestureDetector(
                                    onTap: () {
                                      if (widget.collection.description!.length > 50) {
                                        setState(() {
                                          _isDescriptionExpanded = !_isDescriptionExpanded;
                                        });
                                      }
                                    },
                                    child: AnimatedCrossFade(
                                      duration: const Duration(milliseconds: 300),
                                      crossFadeState: _isDescriptionExpanded
                                          ? CrossFadeState.showSecond
                                          : CrossFadeState.showFirst,
                                      firstChild: Text.rich(
                                        TextSpan(
                                          children: [
                                            TextSpan(
                                              text: widget.collection.description!.length > 50
                                                  ? '${widget.collection.description!.substring(0, 50)}...'
                                                  : widget.collection.description!,
                                              style: AppTextStyles.bodyMedium.copyWith(
                                                color: Colors.white70,
                                              ),
                                            ),
                                            if (widget.collection.description!.length > 50)
                                              TextSpan(
                                                text: ' Devamını oku',
                                                style: AppTextStyles.labelSmall.copyWith(
                                                  color: AppColors.accentCream,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      secondChild: Text(
                                        widget.collection.description!,
                                        style: AppTextStyles.bodyMedium.copyWith(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: AppSpacing.md),
                                Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () async {
                                        final isAuth =
                                            await GuestGuard.checkAuthAndShowModal(
                                              context,
                                              ref,
                                            );
                                        if (isAuth && context.mounted) {
                                          context.push(
                                            '/profile/${widget.collection.userId}',
                                          );
                                        }
                                      },
                                      behavior: HitTestBehavior.opaque,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          CircleAvatar(
                                            radius: 14,
                                            backgroundColor:
                                                AppColors.inkSurface,
                                            backgroundImage:
                                                widget
                                                        .collection
                                                        .authorAvatarUrl !=
                                                    null
                                                ? CachedNetworkImageProvider(
                                                    widget
                                                        .collection
                                                        .authorAvatarUrl!,
                                                  )
                                                : null,
                                            child:
                                                widget
                                                        .collection
                                                        .authorAvatarUrl ==
                                                    null
                                                ? const Icon(
                                                    LucideIcons.user,
                                                    size: 16,
                                                    color: AppColors.inkMuted,
                                                  )
                                                : null,
                                          ),
                                          const SizedBox(width: AppSpacing.sm),
                                          Text(
                                            '@${widget.collection.authorUsername}',
                                            style: AppTextStyles.bodyMedium
                                                .copyWith(
                                                  color: Colors.white70,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Spacer(),
                                    // Comment Indicator (Stat)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          LucideIcons.messageCircle,
                                          size: 14,
                                          color: Colors.white54,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          latestCollection.commentCount.toString(),
                                          style: AppTextStyles.labelSmall.copyWith(
                                            color: Colors.white54,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 8),
                                    // Mini Like Indicator
                                    const Icon(
                                      Icons.favorite,
                                      size: 14,
                                      color: Colors.white54,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      latestCollection.likeCount.toString(),
                                      style: AppTextStyles.labelSmall.copyWith(
                                        color: Colors.white54,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Thumbnail Gallery & New Comment Button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                      child: Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 60,
                              child: ListView.builder(
                                padding: const EdgeInsets.only(right: 12),
                                scrollDirection: Axis.horizontal,
                                itemCount: photos.length,
                                itemBuilder: (context, index) {
                                  final photo = photos[index];
                                  final isActive = index == _currentIndex;

                                  return GestureDetector(
                                    onTap: () {
                                      _pageController.animateToPage(
                                        index,
                                        duration: const Duration(milliseconds: 300),
                                        curve: Curves.easeInOut,
                                      );
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      margin: const EdgeInsets.only(
                                        right: AppSpacing.sm,
                                      ),
                                      width: 60,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(
                                          AppSpacing.radiusMd,
                                        ),
                                        border: Border.all(
                                          color: isActive
                                              ? AppColors.accentCream
                                              : Colors.transparent,
                                          width: 2,
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(
                                          AppSpacing.radiusMd - 2,
                                        ),
                                        child: CachedNetworkImage(
                                          imageUrl: photo.imageUrl,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) => Container(
                                            color: bgColor.withValues(alpha: 0.5),
                                          ),
                                          errorWidget: (context, url, _) =>
                                              Container(color: bgColor),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          // New Action: Prominent Comment Button
                          ClipRRect(
                            borderRadius: BorderRadius.circular(30),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), // Using ImageFilter.blur 
                              child: GestureDetector(
                                onTap: () async {
                                  final isAuth = await GuestGuard.checkAuthAndShowModal(context, ref);
                                  if (!isAuth) return;
                                  if (context.mounted) {
                                    HapticFeedback.selectionClick();
                                    CollectionCommentsSheet.show(context, latestCollection.collectionId);
                                  }
                                },
                                child: Container(
                                  height: 60,
                                  width: 60,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: const Icon(
                                    LucideIcons.messageCircle,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Bottom padding for SafeArea
                    SizedBox(
                      height:
                          MediaQuery.paddingOf(context).bottom + AppSpacing.md,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showActionBottomSheet(
    BuildContext context,
    FeedCollectionModel collection,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.only(bottom: AppSpacing.xl),
          decoration: const BoxDecoration(
            color: AppColors.inkBlack,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            border: Border(top: BorderSide(color: Color(0xFF2A2A2D), width: 1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: AppSpacing.sm),
              // Grab handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              ListTile(
                leading: const Icon(LucideIcons.edit2, color: Colors.white),
                title: Text(
                  'Edit Collection',
                  style: AppTextStyles.bodyLarge.copyWith(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showEditCollectionModal(context, collection);
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  void _showEditCollectionModal(
    BuildContext screenContext,
    FeedCollectionModel initialCollection,
  ) {
    final titleController = TextEditingController(
      text: initialCollection.title,
    );
    bool isPrivate = initialCollection.isPrivate;
    bool isSaving = false;
    FeedCollectionModel latestCollection = initialCollection;

    showModalBottomSheet(
      context: screenContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.inkBlack,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                ),
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Edit Collection',
                            style: AppTextStyles.headlineMedium.copyWith(
                              color: Colors.white,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              LucideIcons.x,
                              color: Colors.white,
                            ),
                            onPressed: () => Navigator.pop(modalCtx),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'TITLE',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.inkMuted,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      TextField(
                        controller: titleController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppColors.inkSurface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        children: [
                          const Icon(
                            LucideIcons.lock,
                            size: 18,
                            color: AppColors.inkMuted,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              'Keep this collection private',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: Colors.white70,
                              ),
                            ),
                          ),
                          Switch.adaptive(
                            value: isPrivate,
                            onChanged: (val) {
                              setModalState(() => isPrivate = val);
                            },
                            activeThumbColor: const Color(0xFF6C4FCA),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        'MANAGE PHOTOS',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.inkMuted,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      SizedBox(
                        height: 100,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: latestCollection.photos.length,
                          itemBuilder: (context, index) {
                            final photo = latestCollection.photos[index];
                            return Container(
                              margin: const EdgeInsets.only(
                                right: AppSpacing.sm,
                              ),
                              width: 100,
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: CachedNetworkImage(
                                      imageUrl: photo.imageUrl,
                                      fit: BoxFit.cover,
                                      width: 100,
                                      height: 100,
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap: () {
                                        if (latestCollection.photos.length ==
                                            1) {
                                          _showDeleteConfirmDialog(
                                            screenContext,
                                            latestCollection,
                                            onDeletedFromModal: () {
                                              if (screenContext.mounted) {
                                                Navigator.pop(modalCtx);
                                                screenContext.pop();
                                              }
                                            },
                                          );
                                        } else {
                                          _showPhotoDeleteConfirmDialog(
                                            screenContext,
                                            latestCollection,
                                            photo,
                                            onOptimisticDelete: () {
                                              setModalState(() {
                                                final updatedPhotos =
                                                    latestCollection.photos
                                                        .where(
                                                          (p) =>
                                                              p.id != photo.id,
                                                        )
                                                        .toList();
                                                latestCollection =
                                                    latestCollection.copyWith(
                                                      photos: updatedPhotos,
                                                    );
                                              });
                                            },
                                          );
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(
                                            alpha: 0.7,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          LucideIcons.x,
                                          color: AppColors.accentRose,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  final newTitle = titleController.text.trim();
                                  String? titleToUpdate = newTitle;

                                  if (newTitle.isEmpty) {
                                    ScaffoldMessenger.of(
                                      screenContext,
                                    ).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Koleksiyon başlığı boş olamaz. Önceki başlık korundu.',
                                        ),
                                      ),
                                    );
                                    titleToUpdate = null; // Do not update title
                                  }

                                  setModalState(() => isSaving = true);
                                  try {
                                    await ref
                                        .read(feedControllerProvider.notifier)
                                        .updateCollection(
                                          collectionId:
                                              latestCollection.collectionId,
                                          title: titleToUpdate,
                                          isPrivate: isPrivate,
                                        );

                                    ref.invalidate(profileControllerProvider);
                                    ref.invalidate(feedControllerProvider);

                                    if (screenContext.mounted) {
                                      Navigator.pop(modalCtx);
                                      ScaffoldMessenger.of(
                                        screenContext,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            isPrivate
                                                ? 'Koleksiyon gizli yapıldı.'
                                                : 'Koleksiyon güncellendi.',
                                          ),
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    debugPrint('Update collection failed: $e');
                                    if (screenContext.mounted) {
                                      ScaffoldMessenger.of(
                                        screenContext,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Güncelleme başarısız. Tekrar deneyin.',
                                          ),
                                        ),
                                      );
                                    }
                                  } finally {
                                    setModalState(() => isSaving = false);
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6C4FCA),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: const Color(
                              0xFF6C4FCA,
                            ).withValues(alpha: 0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  'Save Changes',
                                  style: AppTextStyles.labelLarge.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            _showDeleteConfirmDialog(
                              screenContext,
                              latestCollection,
                              onDeletedFromModal: () {
                                if (screenContext.mounted) {
                                  Navigator.pop(modalCtx);
                                  screenContext.pop();
                                }
                              },
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.accentRose,
                            side: const BorderSide(color: AppColors.accentRose),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Text(
                            'Delete Entire Collection',
                            style: AppTextStyles.labelLarge.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 50),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showPhotoDeleteConfirmDialog(
    BuildContext screenContext,
    FeedCollectionModel collection,
    FeedPhotoItem photo, {
    required VoidCallback onOptimisticDelete,
  }) {
    showDialog(
      context: screenContext,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: AppColors.inkSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Delete Photo',
            style: AppTextStyles.titleLarge.copyWith(
              color: AppColors.accentRose,
            ),
          ),
          content: const Text(
            'Fotoğrafı silmek istediğinize emin misiniz?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentRose,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.pop(dialogCtx); // Close dialog immediately

                // Optimistic Local Update
                onOptimisticDelete();

                try {
                  // Direct backend call
                  final repository = ref.read(feedRepositoryProvider);
                  await repository.deletePhotoFromCollection(
                    collectionId: collection.collectionId,
                    photoId: photo.id,
                    photoUrl: photo.imageUrl,
                  );
                  // Refresh global states
                  ref.invalidate(feedControllerProvider);
                  ref.invalidate(profileControllerProvider);
                } catch (e) {
                  debugPrint('Failed to delete photo: $e');
                  if (screenContext.mounted) {
                    ScaffoldMessenger.of(screenContext).showSnackBar(
                      SnackBar(content: Text('Fotoğraf silinemedi: $e')),
                    );
                  }
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmDialog(
    BuildContext screenContext,
    FeedCollectionModel collection, {
    VoidCallback? onDeletedFromModal,
  }) {
    showDialog(
      context: screenContext,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: AppColors.inkSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Delete Collection',
            style: AppTextStyles.titleLarge.copyWith(
              color: AppColors.accentRose,
            ),
          ),
          content: const Text(
            'Are you sure you want to delete this collection? This action cannot be undone.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogCtx); // Dialog'u anında kapat
                try {
                  await ref
                      .read(feedControllerProvider.notifier)
                      .deleteCollection(collection.collectionId);

                  ref.invalidate(profileControllerProvider);

                  if (screenContext.mounted) {
                    ScaffoldMessenger.of(screenContext).showSnackBar(
                      const SnackBar(
                        content: Text('Koleksiyon başarıyla silindi'),
                        duration: Duration(seconds: 2),
                      ),
                    );

                    if (onDeletedFromModal != null) {
                      onDeletedFromModal();
                    } else {
                      screenContext.pop();
                    }
                  }
                } catch (e) {
                  debugPrint('Delete collection failed: $e');
                  if (screenContext.mounted) {
                    ScaffoldMessenger.of(screenContext).showSnackBar(
                      SnackBar(
                        content: Text('Koleksiyon silinirken hata oluştu: $e'),
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentRose,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _downloadCurrentPhoto(String url) async {
    try {
      final status = await Permission.photos.request();
      if (status.isGranted) {
        final result = await GallerySaver.saveImage(url);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result == true ? 'Saved to gallery' : 'Download failed',
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor: AppColors.inkSurface,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Permission denied',
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Download error: $e');
    }
  }

  void _showBoardSelectionSheet(BuildContext context, String collectionId) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, _) {
            final profileState = ref.watch(
              profileControllerProvider(currentUserId),
            );
            final membershipState = ref.watch(
              collectionBoardMembershipProvider(collectionId),
            );

            return Container(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              decoration: const BoxDecoration(
                color: AppColors.inkBlack,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Save to Board',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  profileState.when(
                    data: (state) {
                      if (state.boards.isEmpty) {
                        return ListTile(
                          leading: const Icon(
                            LucideIcons.plus,
                            color: Colors.white,
                          ),
                          title: const Text(
                            'Create New Board in Profile',
                            style: TextStyle(color: Colors.white),
                          ),
                          onTap: () => Navigator.pop(ctx),
                        );
                      }
                      return Flexible(
                        child: membershipState.when(
                          data: (memberBoardIds) {
                            return ListView.builder(
                              shrinkWrap: true,
                              itemCount: state.boards.length,
                              itemBuilder: (c, i) {
                                final board = state.boards[i];
                                final isMember = memberBoardIds.contains(
                                  board.id,
                                );

                                return ListTile(
                                  leading: Icon(
                                    LucideIcons.folder,
                                    color: isMember
                                        ? AppColors.accentRose
                                        : Colors.white54,
                                  ),
                                  title: Text(
                                    board.title,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  trailing: isMember
                                      ? const Icon(
                                          Icons.check_circle,
                                          color: Colors.white54,
                                          size: 20,
                                        )
                                      : null,
                                  onTap: () async {
                                    try {
                                      final msg = await ref
                                          .read(feedControllerProvider.notifier)
                                          .toggleBoardStatus(
                                            collectionId,
                                            board.id,
                                          );

                                      // Update local membership view
                                      ref.invalidate(
                                        collectionBoardMembershipProvider(
                                          collectionId,
                                        ),
                                      );

                                      if (ctx.mounted) {
                                        Navigator.pop(ctx);
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              msg,
                                              style: const TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                            backgroundColor:
                                                AppColors.inkSurface,
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Database error occurred',
                                              style: TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                            backgroundColor: AppColors.error,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                );
                              },
                            );
                          },
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (_, _) => const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'Failed to load membership',
                              style: TextStyle(color: AppColors.error),
                            ),
                          ),
                        ),
                      );
                    },
                    loading: () => const CircularProgressIndicator(),
                    error: (_, _) => const Text('Error loading boards'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
