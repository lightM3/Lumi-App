// lib/features/feed/presentation/widgets/feed_photo_card.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../auth/presentation/widgets/guest_guard.dart';
import '../../domain/models/feed_collection_model.dart';
import '../controllers/feed_controller.dart';
import 'package:lucide_icons/lucide_icons.dart';

class FeedPhotoCard extends ConsumerStatefulWidget {
  const FeedPhotoCard({super.key, required this.collection, this.onTap});

  final FeedCollectionModel collection;
  final VoidCallback? onTap;

  @override
  ConsumerState<FeedPhotoCard> createState() => _FeedPhotoCardState();
}

class _FeedPhotoCardState extends ConsumerState<FeedPhotoCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _heartAnimationController;
  late Animation<double> _heartScaleAnimation;
  bool _showHeart = false;

  @override
  void initState() {
    super.initState();

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
  }

  @override
  void dispose() {
    _heartAnimationController.dispose();
    super.dispose();
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

  Future<void> _handleDoubleTap() async {
    final isAuthenticated = await GuestGuard.checkAuthAndShowModal(
      context,
      ref,
    );
    if (!isAuthenticated) return;

    if (!widget.collection.isLiked) {
      ref
          .read(feedControllerProvider.notifier)
          .toggleLike(widget.collection.collectionId);
    }

    HapticFeedback.heavyImpact();

    setState(() => _showHeart = true);
    _heartAnimationController.forward(from: 0.0).then((_) {
      setState(() => _showHeart = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final placeholderColor = _parseHexColor(widget.collection.dominantColor);

    return GestureDetector(
      onTap: widget.onTap,
      onDoubleTap: _handleDoubleTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: AspectRatio(
          aspectRatio: widget.collection.aspectRatio,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Main Image
              if (widget.collection.coverImageUrl.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: widget.collection.coverImageUrl,
                  fit: BoxFit.cover,
                  memCacheWidth: 600,
                  placeholder: (context, url) =>
                      Container(color: placeholderColor),
                  errorWidget: (context, url, error) =>
                      Container(color: placeholderColor),
                )
              else
                Container(color: placeholderColor),

              // Gradient overlay
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 80,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Double Tap Heart Animation
              if (_showHeart)
                Center(
                  child: ScaleTransition(
                    scale: _heartScaleAnimation,
                    child: Icon(
                      Icons.favorite,
                      color: AppColors.accentRose,
                      size: 60,
                      shadows: [Shadow(color: Colors.black45, blurRadius: 15)],
                    ),
                  ),
                ),

              // Author Info
              Positioned(
                left: AppSpacing.sm,
                bottom: AppSpacing.sm,
                child: GestureDetector(
                  onTap: () async {
                    final isAuth = await GuestGuard.checkAuthAndShowModal(
                      context,
                      ref,
                    );
                    if (isAuth && context.mounted) {
                      context.push('/profile/${widget.collection.userId}');
                    }
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: AppColors.inkSurface,
                        backgroundImage:
                            widget.collection.authorAvatarUrl != null
                            ? CachedNetworkImageProvider(
                                widget.collection.authorAvatarUrl!,
                              )
                            : null,
                        child: widget.collection.authorAvatarUrl == null
                            ? const Icon(
                                LucideIcons.user,
                                size: 14,
                                color: AppColors.inkMuted,
                              )
                            : null,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        '@${widget.collection.authorUsername}',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Like Counter & Button
              Positioned(
                right: AppSpacing.xs,
                bottom: AppSpacing.xs,
                child: GestureDetector(
                  onTap: () async {
                    HapticFeedback.mediumImpact();
                    final isAuth = await GuestGuard.checkAuthAndShowModal(
                      context,
                      ref,
                    );
                    if (!isAuth) return;

                    if (context.mounted) {
                      ref
                          .read(feedControllerProvider.notifier)
                          .toggleLike(widget.collection.collectionId);
                    }
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${widget.collection.likeCount}',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            shadows: [
                              const Shadow(
                                color: Colors.black54,
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (child, animation) =>
                              ScaleTransition(scale: animation, child: child),
                          child: Icon(
                            widget.collection.isLiked
                                ? Icons.favorite
                                : Icons.favorite_border,
                            key: ValueKey(widget.collection.isLiked),
                            size: 16,
                            color: widget.collection.isLiked
                                ? AppColors.accentRose
                                : Colors.white.withValues(alpha: 0.8),
                            shadows: const [
                              Shadow(color: Colors.black26, blurRadius: 4),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
