import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../feed/presentation/widgets/feed_photo_card.dart';
import '../controllers/board_detail_controller.dart';
import '../controllers/profile_controller.dart';
import '../../domain/models/board_model.dart';

class BoardDetailScreen extends ConsumerStatefulWidget {
  const BoardDetailScreen({
    super.key,
    required this.boardId,
    required this.boardName,
  });

  final String boardId;
  final String boardName;

  @override
  ConsumerState<BoardDetailScreen> createState() => _BoardDetailScreenState();
}

class _BoardDetailScreenState extends ConsumerState<BoardDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final collectionsState = ref.watch(
      boardDetailControllerProvider(widget.boardId),
    );
    final boardFetch = ref.watch(singleBoardProvider(widget.boardId));
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    final userBoard = boardFetch.value;
    final isOwner = userBoard != null && userBoard.userId == currentUserId;
    final displayTitle = isOwner ? userBoard.title : widget.boardName;

    return Scaffold(
      backgroundColor: AppColors.inkBlack,
      appBar: AppBar(
        title: Text(displayTitle, style: AppTextStyles.titleLarge),
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (isOwner)
            IconButton(
              icon: const Icon(LucideIcons.edit),
              onPressed: () => _showEditBoardModal(context, userBoard),
            ),
        ],
      ),
      body: collectionsState.when(
        data: (collections) {
          if (collections.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    LucideIcons.folderOpen,
                    size: 48,
                    color: AppColors.inkMuted,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'This board is empty',
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.inkMuted,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref
                .read(boardDetailControllerProvider(widget.boardId).notifier)
                .refresh(),
            color: AppColors.accentCream,
            backgroundColor: AppColors.inkSurface,
            child: MasonryGridView.count(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
              crossAxisCount: 2,
              mainAxisSpacing: AppSpacing.md,
              crossAxisSpacing: AppSpacing.md,
              itemCount: collections.length,
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
                'Failed to load board content',
                style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.error,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton.icon(
                onPressed: () => ref
                    .read(
                      boardDetailControllerProvider(widget.boardId).notifier,
                    )
                    .refresh(),
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
    );
  }

  void _showEditBoardModal(BuildContext context, BoardModel board) {
    final titleController = TextEditingController(text: board.title);
    final descController = TextEditingController(text: board.description ?? '');
    bool isPrivate = board.isPrivate;
    File? newCoverImage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Edit Board',
                          style: AppTextStyles.headlineMedium.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(LucideIcons.x, color: Colors.white),
                          onPressed: () => Navigator.pop(ctx),
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
                    Text(
                      'DESCRIPTION (OPTIONAL)',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.inkMuted,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    TextField(
                      controller: descController,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 2,
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
                    Text(
                      'COVER IMAGE (OPTIONAL)',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.inkMuted,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    GestureDetector(
                      onTap: () async {
                        final picker = ImagePicker();
                        final xfile = await picker.pickImage(
                          source: ImageSource.gallery,
                        );
                        if (xfile != null) {
                          setModalState(() {
                            newCoverImage = File(xfile.path);
                          });
                        }
                      },
                      child: Container(
                        height: 120,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.inkSurface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: newCoverImage != null
                              ? Image.file(newCoverImage!, fit: BoxFit.cover)
                              : (board.coverImageUrl != null
                                    ? CachedNetworkImage(
                                        imageUrl: board.coverImageUrl!,
                                        fit: BoxFit.cover,
                                      )
                                    : const Center(
                                        child: Icon(
                                          LucideIcons.imagePlus,
                                          color: AppColors.inkMuted,
                                          size: 32,
                                        ),
                                      )),
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
                            'Keep this board private',
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
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (titleController.text.trim().isEmpty) return;

                          // We pass the current user's profileProvider
                          final currentUserId =
                              Supabase.instance.client.auth.currentUser?.id;
                          if (currentUserId != null) {
                            await ref
                                .read(
                                  profileControllerProvider(
                                    currentUserId,
                                  ).notifier,
                                )
                                .updateBoard(
                                  boardId: board.id,
                                  title: titleController.text.trim(),
                                  description: descController.text.trim(),
                                  isPrivate: isPrivate,
                                  newCoverImage: newCoverImage,
                                );

                            // Invalidate the single board fetch to reflect new title/image immediately
                            ref.invalidate(singleBoardProvider(board.id));
                          }
                          if (context.mounted) Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C4FCA),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          'Save Changes',
                          style: AppTextStyles.labelLarge.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
