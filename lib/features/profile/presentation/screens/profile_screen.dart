import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../feed/domain/models/feed_collection_model.dart';
import '../../../auth/presentation/widgets/guest_guard.dart';
import '../../../feed/presentation/widgets/feed_photo_card.dart';
import '../../../feed/presentation/widgets/glass_bottom_nav.dart';
import '../../domain/models/profile_user_model.dart';
import '../../domain/models/board_model.dart';
import '../controllers/profile_controller.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key, this.userId});

  final String? userId;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  int _selectedTabIndex = 0; // 0: Created, 1: Boards, 2: Liked

  @override
  void initState() {
    super.initState();
    // Refresh safe call on init
    Future.microtask(
      () => ref
          .read(profileControllerProvider(widget.userId).notifier)
          .refreshProfile(),
    );
  }

  void _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.inkSurface,
        title: const Text('Logout', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to log out?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Logout',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref
          .read(profileControllerProvider(widget.userId).notifier)
          .signOut();
      if (mounted) context.go('/auth');
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileControllerProvider(widget.userId));
    final isCurrentUser =
        widget.userId == null ||
        widget.userId == Supabase.instance.client.auth.currentUser?.id;

    return Scaffold(
      backgroundColor: AppColors.inkBlack,
      extendBody: true, // For bottom nav
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: isCurrentUser
            ? null
            : IconButton(
                icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
                onPressed: () => context.pop(),
              ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: isCurrentUser
            ? [
                IconButton(
                  icon: const Icon(LucideIcons.share2, color: Colors.white),
                  onPressed: () {},
                ),
                IconButton(
                  icon: const Icon(
                    LucideIcons.moreVertical,
                    color: Colors.white,
                  ),
                  onPressed: _handleLogout,
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(LucideIcons.share2, color: Colors.white),
                  onPressed: () {},
                ),
              ],
      ),
      body: profileAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accentCream),
        ),
        error: (err, stack) => Center(
          child: Text(
            'Error loading profile',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error),
          ),
        ),
        data: (state) {
          final user = state.user;
          final collections = state.collections;

          return RefreshIndicator(
            color: AppColors.accentCream,
            backgroundColor: AppColors.inkSurface,
            onRefresh: () => ref
                .read(profileControllerProvider(widget.userId).notifier)
                .refreshProfile(),
            child: ListView(
              padding: const EdgeInsets.only(
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                bottom: 120, // space for bottom nav
              ),
              children: [
                // ── Profile Header ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Avatar
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(
                            0xFF6C4FCA,
                          ), // Purple border as in design
                          width: 2,
                        ),
                        image: user?.avatarUrl != null
                            ? DecorationImage(
                                image: CachedNetworkImageProvider(
                                  user!.avatarUrl!,
                                ),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: user?.avatarUrl == null
                          ? const Icon(
                              LucideIcons.user,
                              size: 40,
                              color: AppColors.inkMuted,
                            )
                          : null,
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    // Stats
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildStatColumn(
                            '${state.followersCount}',
                            'FOLLOWERS',
                            onTap: user != null
                                ? () async {
                                    final isAuth =
                                        await GuestGuard.checkAuthAndShowModal(
                                          context,
                                          ref,
                                        );
                                    if (isAuth && context.mounted) {
                                      _showFollowListModal(
                                        context,
                                        'Followers',
                                        user.id,
                                      );
                                    }
                                  }
                                : null,
                          ),
                          _buildStatColumn(
                            '${state.followingCount}',
                            'FOLLOWING',
                            onTap: user != null
                                ? () async {
                                    final isAuth =
                                        await GuestGuard.checkAuthAndShowModal(
                                          context,
                                          ref,
                                        );
                                    if (isAuth && context.mounted) {
                                      _showFollowListModal(
                                        context,
                                        'Following',
                                        user.id,
                                      );
                                    }
                                  }
                                : null,
                          ),
                          _buildStatColumn(
                            collections.length.toString(),
                            'SHOTS',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // ── Username & Bio ──
                Text(
                  user?.username != null ? user!.username : '@username',
                  style: AppTextStyles.displayMedium.copyWith(
                    color: Colors.white,
                    fontStyle: FontStyle.italic, // to match design
                    fontWeight: FontWeight.w300,
                  ),
                ),
                if (user?.bio != null && user!.bio!.isNotEmpty) ...[
                  Text(
                    user.bio!,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.inkMuted,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],

                const SizedBox(height: AppSpacing.sm),

                // ── Action Buttons ──
                Row(
                  children: [
                    Expanded(
                      child: isCurrentUser
                          ? ElevatedButton(
                              onPressed: () {
                                _showEditProfileModal(context, user);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.inkSurface,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  side: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.1),
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                              child: Text(
                                'Edit Profile',
                                style: AppTextStyles.labelLarge.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          : ElevatedButton(
                              onPressed: () async {
                                final isAuth =
                                    await GuestGuard.checkAuthAndShowModal(
                                      context,
                                      ref,
                                    );
                                if (!isAuth) return;

                                HapticFeedback.lightImpact();
                                if (context.mounted) {
                                  ref
                                      .read(
                                        profileControllerProvider(
                                          widget.userId,
                                        ).notifier,
                                      )
                                      .toggleFollow();
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: state.isFollowing
                                    ? AppColors.inkSurface
                                    : const Color(0xFF6C4FCA),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  side: state.isFollowing
                                      ? BorderSide(
                                          color: Colors.white.withValues(
                                            alpha: 0.1,
                                          ),
                                        )
                                      : BorderSide.none,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                              child: Text(
                                state.isFollowing ? 'Following' : 'Follow',
                                style: AppTextStyles.labelLarge.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),

                // ── Tab Icons ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildTabIcon(icon: LucideIcons.layoutGrid, index: 0),
                    _buildTabIcon(icon: LucideIcons.folder, index: 1),
                    _buildTabIcon(icon: LucideIcons.heart, index: 2),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── Masonry Grid ──
                Builder(
                  builder: (context) {
                    List<FeedCollectionModel> currentList;
                    String emptyMessage;

                    if (_selectedTabIndex == 0) {
                      currentList = state.collections;
                      emptyMessage = 'No shots yet.';
                    } else if (_selectedTabIndex == 1) {
                      // BOARDS TAB
                      return _BoardsTab(
                        boards: state.boards,
                        isCurrentUser: isCurrentUser,
                        onAddBoard: () => _showCreateBoardModal(context),
                      );
                    } else if (_selectedTabIndex == 2) {
                      currentList = state.likedCollections;
                      emptyMessage = 'No liked shots yet.';
                    } else {
                      currentList = const [];
                      emptyMessage = '';
                    }

                    if (currentList.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: Center(
                          child: Text(
                            emptyMessage,
                            style: AppTextStyles.bodyLarge.copyWith(
                              color: AppColors.inkMuted,
                            ),
                          ),
                        ),
                      );
                    }

                    return MasonryGridView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverSimpleGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                          ),
                      mainAxisSpacing: AppSpacing.md,
                      crossAxisSpacing: AppSpacing.md,
                      itemCount: currentList.length,
                      itemBuilder: (context, index) {
                        final collection = currentList[index];
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
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: isCurrentUser ? const GlassBottomNav() : null,
    );
  }

  void _showEditProfileModal(BuildContext context, ProfileUserModel? user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) =>
          _EditProfileSheet(initialUser: user, userId: widget.userId),
    );
  }

  void _showCreateBoardModal(BuildContext context) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    bool isPrivate = false;
    File? selectedCoverImage;

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
                          'Create New Board',
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
                      autofocus: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'e.g. Minimalist Home Office',
                        hintStyle: TextStyle(
                          color: AppColors.inkMuted.withValues(alpha: 0.5),
                        ),
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
                    // COVER IMAGE PICKER
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
                            selectedCoverImage = File(xfile.path);
                          });
                        }
                      },
                      child: Container(
                        height: 120,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.inkSurface,
                          borderRadius: BorderRadius.circular(12),
                          image: selectedCoverImage != null
                              ? DecorationImage(
                                  image: FileImage(selectedCoverImage!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: selectedCoverImage == null
                            ? const Center(
                                child: Icon(
                                  LucideIcons.imagePlus,
                                  color: AppColors.inkMuted,
                                  size: 32,
                                ),
                              )
                            : null,
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
                          await ref
                              .read(
                                profileControllerProvider(
                                  widget.userId,
                                ).notifier,
                              )
                              .createBoard(
                                title: titleController.text.trim(),
                                description: descController.text.trim(),
                                isPrivate: isPrivate,
                                coverImage: selectedCoverImage,
                              );
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
                          'Create Board',
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

  Widget _buildStatColumn(String value, String label, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Text(
            value,
            style: AppTextStyles.titleLarge.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.inkMuted,
              fontSize: 10,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  void _showFollowListModal(BuildContext context, String title, String userId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: AppColors.inkBlack,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.md),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.inkMuted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                title,
                style: AppTextStyles.titleLarge.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: FutureBuilder<List<ProfileUserModel>>(
                  future: title == 'Followers'
                      ? ref
                            .read(profileControllerProvider(userId).notifier)
                            .getFollowersList(userId)
                      : ref
                            .read(profileControllerProvider(userId).notifier)
                            .getFollowingList(userId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF6C4FCA),
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      return const Center(child: Text('An error occurred.'));
                    }
                    final users = snapshot.data ?? [];
                    if (users.isEmpty) {
                      return Center(
                        child: Text(
                          'No ${title.toLowerCase()} yet.',
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: AppColors.inkMuted,
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: users.length,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) {
                        final user = users[index];
                        return GestureDetector(
                          onTap: () {
                            Navigator.pop(ctx);
                            context.push('/profile/${user.id}');
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.md,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.inkSurface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.05),
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundImage: user.avatarUrl != null
                                      ? CachedNetworkImageProvider(
                                          user.avatarUrl!,
                                        )
                                      : null,
                                  backgroundColor: AppColors.inkMuted
                                      .withValues(alpha: 0.2),
                                  child: user.avatarUrl == null
                                      ? const Icon(
                                          LucideIcons.user,
                                          size: 20,
                                          color: Colors.white70,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Text(
                                    user.username,
                                    style: AppTextStyles.bodyLarge.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  LucideIcons.chevronRight,
                                  color: AppColors.inkMuted,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabIcon({required IconData icon, required int index}) {
    final isSelected = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _selectedTabIndex = index;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? Colors.white : AppColors.inkMuted),
            const SizedBox(height: 4),
            if (isSelected)
              Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: Color(0xFF6C4FCA), // Purple dot indicator
                  shape: BoxShape.circle,
                ),
              )
            else
              const SizedBox(height: 4), // Placeholder to prevent jump
          ],
        ),
      ),
    );
  }
}

class _BoardsTab extends StatelessWidget {
  const _BoardsTab({
    required this.boards,
    required this.isCurrentUser,
    required this.onAddBoard,
  });

  final List<BoardModel> boards;
  final bool isCurrentUser;
  final VoidCallback onAddBoard;

  @override
  Widget build(BuildContext context) {
    if (boards.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Center(
          child: Column(
            children: [
              Text(
                'No boards yet.',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.inkMuted,
                ),
              ),
              if (isCurrentUser) ...[
                const SizedBox(height: AppSpacing.md),
                ElevatedButton.icon(
                  onPressed: onAddBoard,
                  icon: const Icon(LucideIcons.plus, size: 16),
                  label: const Text('Create New Board'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.inkSurface,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        if (isCurrentUser)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'YOUR BOARDS',
                  style: AppTextStyles.labelSmall.copyWith(
                    letterSpacing: 2,
                    color: AppColors.inkMuted,
                  ),
                ),
                IconButton(
                  onPressed: onAddBoard,
                  icon: const Icon(
                    LucideIcons.plusCircle,
                    size: 20,
                    color: AppColors.accentCream,
                  ),
                ),
              ],
            ),
          ),
        MasonryGridView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverSimpleGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
          ),
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          itemCount: boards.length,
          itemBuilder: (context, index) {
            return _BoardCard(board: boards[index]);
          },
        ),
      ],
    );
  }
}

class _BoardCard extends StatelessWidget {
  const _BoardCard({required this.board});
  final BoardModel board;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        context.push('/board/${board.id}/${board.title}');
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (board.coverImageUrl != null)
                    CachedNetworkImage(
                      imageUrl: board.coverImageUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => const Icon(
                        LucideIcons.alertCircle,
                        color: AppColors.inkMuted,
                        size: 20,
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF6C4FCA).withValues(alpha: 0.3),
                            AppColors.inkSurface,
                          ],
                        ),
                      ),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            LucideIcons.folder,
                            color: Colors.white70,
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                  if (board.isPrivate)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          LucideIcons.lock,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            board.title,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            'Saved items', // This could be dynamically fetched later
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.inkMuted),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// Edit Profile Sheet — fully reactive ConsumerStatefulWidget
// Solves the stale avatar problem: uses local File? state for
// immediate preview and ref.watch for Riverpod sync.
// ─────────────────────────────────────────────────────
class _EditProfileSheet extends ConsumerStatefulWidget {
  const _EditProfileSheet({required this.initialUser, this.userId});

  final ProfileUserModel? initialUser;
  final String? userId;

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  late final TextEditingController _usernameController;
  late final TextEditingController _bioController;

  /// Holds the locally selected image file for instant preview.
  File? _pendingAvatar;
  bool _isUploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(
      text: widget.initialUser?.username,
    );
    _bioController = TextEditingController(text: widget.initialUser?.bio);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null || !mounted) return;

    // 1. Instant local preview
    setState(() {
      _pendingAvatar = File(pickedFile.path);
      _isUploadingAvatar = true;
    });

    try {
      await ref
          .read(profileControllerProvider(widget.userId).notifier)
          .uploadAvatar(File(pickedFile.path));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString(),
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: AppColors.error,
          ),
        );
        // Revert pending avatar on error
        setState(() => _pendingAvatar = null);
      }
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch Riverpod state so avatar syncs after upload completes
    final profileAsync = ref.watch(profileControllerProvider(widget.userId));
    final remoteAvatarUrl = profileAsync.value?.user?.avatarUrl;

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
          border: Border(top: BorderSide(color: Color(0xFF2A2A2D), width: 1)),
        ),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Edit Profile',
                  style: AppTextStyles.headlineMedium.copyWith(
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.x, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Avatar Edit
            Center(
              child: GestureDetector(
                onTap: _isUploadingAvatar ? null : _pickAndUploadAvatar,
                child: Stack(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.inkSurface,
                        border: Border.all(
                          color: const Color(0xFF6C4FCA),
                          width: 2,
                        ),
                        // Priority: pending local file → remote URL
                        image: _pendingAvatar != null
                            ? DecorationImage(
                                image: FileImage(_pendingAvatar!),
                                fit: BoxFit.cover,
                              )
                            : remoteAvatarUrl != null
                            ? DecorationImage(
                                image: CachedNetworkImageProvider(
                                  remoteAvatarUrl,
                                ),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _isUploadingAvatar
                          ? const Padding(
                              padding: EdgeInsets.all(20),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : (_pendingAvatar == null && remoteAvatarUrl == null)
                          ? const Icon(
                              LucideIcons.user,
                              size: 40,
                              color: AppColors.inkMuted,
                            )
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Color(0xFF6C4FCA),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          LucideIcons.camera,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Username
            Text(
              'USERNAME',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.inkMuted,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextField(
              controller: _usernameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.inkSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Bio
            Text(
              'BIO',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.inkMuted,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextField(
              controller: _bioController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.inkSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.md,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final nav = Navigator.of(context);
                  await ref
                      .read(profileControllerProvider(widget.userId).notifier)
                      .updateProfile(
                        username: _usernameController.text.trim(),
                        bio: _bioController.text.trim(),
                      );
                  if (mounted) nav.pop();
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
            const SizedBox(height: 30), // 30px bottom breathing room
          ],
        ),
      ),
    );
  }
}
