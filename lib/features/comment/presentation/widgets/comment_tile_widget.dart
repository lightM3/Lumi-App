import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../auth/presentation/widgets/guest_guard.dart';
import '../providers/comment_cache_provider.dart';
import '../providers/active_reply_provider.dart';
import '../controllers/comment_action_controller.dart';
import '../../domain/models/comment_model.dart';

class CommentTileWidget extends ConsumerStatefulWidget {
  final String collectionId;
  final String commentId;
  final bool isReplyTile; // True when rendered as a reply under a parent

  const CommentTileWidget({
    super.key,
    required this.collectionId,
    required this.commentId,
    this.isReplyTile = false,
  });

  @override
  ConsumerState<CommentTileWidget> createState() => _CommentTileWidgetState();
}

class _CommentTileWidgetState extends ConsumerState<CommentTileWidget> {
  bool _isLoadingFirstReply = false;
  bool _isLoadingMoreReplies = false;
  bool _isLiking = false;

  @override
  void initState() {
    super.initState();
    // Auto-fetch the first reply only for top-level comment tiles.
    // This is viewport-safe because ListView.builder is lazy — initState
    // fires only when the item enters the viewport.
    if (!widget.isReplyTile) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _autoFetchFirstReply();
      });
    }
  }

  Future<void> _autoFetchFirstReply() async {
    // Guard: skip temp comments (their IDs start with 'temp_') and
    // skip if no replies expected or replies already fetched.
    if (widget.commentId.startsWith('temp_')) return;
    final comment = ref.read(commentProvider(widget.commentId));

    // TEMP DEBUG
    debugPrint(
      '[CommentTile] id=${widget.commentId} replyCount=${comment?.replyCount} hasReplies=${comment?.replies.isNotEmpty}',
    );

    if (comment == null ||
        comment.replyCount == 0 ||
        comment.replies.isNotEmpty)
      return;

    if (mounted) setState(() => _isLoadingFirstReply = true);
    try {
      final result = await ref
          .read(commentActionControllerProvider)
          .loadReplies(
            widget.collectionId,
            widget.commentId,
            limit: 1,
            offset: 0,
          );
      debugPrint(
        '[CommentTile] loadReplies result for ${widget.commentId}: $result',
      );
    } catch (e) {
      debugPrint('[CommentTile] _autoFetchFirstReply error: $e');
    } finally {
      if (mounted) setState(() => _isLoadingFirstReply = false);
    }
  }

  Future<void> _loadMoreReplies(int alreadyLoaded) async {
    if (_isLoadingMoreReplies) return;
    setState(() => _isLoadingMoreReplies = true);
    await ref
        .read(commentActionControllerProvider)
        .loadReplies(
          widget.collectionId,
          widget.commentId,
          limit: 20,
          offset: alreadyLoaded,
        );
    if (mounted) setState(() => _isLoadingMoreReplies = false);
  }

  @override
  Widget build(BuildContext context) {
    final comment = ref.watch(commentProvider(widget.commentId));
    if (comment == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isReply = comment.parentId != null;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isOwner = comment.userId == currentUserId;

    final double leftPad = isReply ? 56.0 : 16.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Comment Tile ──────────────────────────────────────────────────
        Padding(
          padding: EdgeInsets.only(
            left: leftPad,
            right: 0.0,
            top: isReply ? 8.0 : 12.0,
            bottom: 2.0,
          ),
          child: isOwner
              ? Dismissible(
                  key: ValueKey(comment.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20.0),
                    child: const Icon(
                      Icons.delete_outline,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  confirmDismiss: (_) async {
                    HapticFeedback.lightImpact();
                    final bool? result = await showDialog<bool>(
                      context: context,
                      builder: (dialogCtx) => AlertDialog(
                        title: const Text('Yorumu Sil'),
                        content: const Text(
                          'Bu yorumu silmek istediğinize emin misiniz? Bu işlem geri alınamaz.',
                        ),
                        surfaceTintColor: Colors.transparent,
                        actions: [
                          TextButton(
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              Navigator.of(dialogCtx).pop(false);
                            },
                            child: Text(
                              'İptal',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              Navigator.of(dialogCtx).pop(true);
                            },
                            child: const Text(
                              'Sil',
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                    return result ?? false;
                  },
                  onDismissed: (_) => ref
                      .read(commentActionControllerProvider)
                      .deleteComment(widget.collectionId, comment),
                  child: _buildTileContent(comment, theme, isReply),
                )
              : _buildTileContent(comment, theme, isReply),
        ),

        // ── Reply Preview: loading indicator ─────────────────────────────
        if (!isReply && _isLoadingFirstReply)
          Padding(
            padding: const EdgeInsets.only(left: 68.0, top: 6),
            child: SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: theme.colorScheme.primary.withValues(alpha: 0.6),
              ),
            ),
          ),

        // ── Inline Reply Previews ─────────────────────────────────────────
        if (!isReply && comment.replies.isNotEmpty)
          ...comment.replies.map(
            (reply) => CommentTileWidget(
              key: ValueKey(reply.id),
              collectionId: widget.collectionId,
              commentId: reply.id,
              isReplyTile: true,
            ),
          ),

        // ── "View N more replies" button ──────────────────────────────────
        if (!isReply &&
            comment.replyCount > comment.replies.length &&
            !_isLoadingFirstReply)
          Padding(
            padding: const EdgeInsets.only(left: 56.0, top: 6.0, bottom: 2.0),
            child: GestureDetector(
              onTap: () => _loadMoreReplies(comment.replies.length),
              behavior: HitTestBehavior.opaque,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 20,
                    height: 1,
                    color: Colors.grey.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 8),
                  if (_isLoadingMoreReplies)
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: theme.colorScheme.primary,
                      ),
                    )
                  else
                    Text(
                      comment.replies.isEmpty
                          ? '${comment.replyCount} yanıtı gör'
                          : 'Diğer ${comment.replyCount - comment.replies.length} yanıtı görüntüle',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTileContent(
    CommentModel comment,
    ThemeData theme,
    bool isReply,
  ) {
    // Replies use slightly smaller UI for visual hierarchy
    final double avatarRadius = isReply ? 12.0 : 16.0;
    final double iconSize = isReply ? 12.0 : 14.0;
    final double fontSize = isReply ? 12.0 : 14.0;

    return Padding(
      padding: const EdgeInsets.only(right: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: avatarRadius,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            backgroundImage: comment.authorAvatarUrl != null
                ? NetworkImage(comment.authorAvatarUrl!)
                : null,
            child: comment.authorAvatarUrl == null
                ? Icon(Icons.person, size: avatarRadius, color: Colors.grey)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Author + timestamp
                Row(
                  children: [
                    Text(
                      '@${comment.authorUsername}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: fontSize,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${comment.createdAt.hour.toString().padLeft(2, '0')}:${comment.createdAt.minute.toString().padLeft(2, '0')}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                        fontSize: fontSize - 2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                // Content
                Text(
                  comment.content,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: fontSize,
                  ),
                ),
                const SizedBox(height: 4),
                // Action row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Reply button — only for top-level comments
                    if (!isReply)
                      GestureDetector(
                        onTap: () {
                          if (Supabase.instance.client.auth.currentSession == null) {
                            GuestGuard.checkAuthAndShowModal(context, ref);
                            return;
                          }
                          ref.read(activeReplyProvider.notifier).state = comment;
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.only(
                            right: 16.0,
                            top: 4,
                            bottom: 4,
                          ),
                          child: Text(
                            'Yanıtla',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      )
                    else
                      const SizedBox.shrink(),

                    // Like button
                    GestureDetector(
                      onTap: _isLiking ? null : () async {
                        if (Supabase.instance.client.auth.currentSession == null) {
                          GuestGuard.checkAuthAndShowModal(context, ref);
                          return;
                        }
                        setState(() => _isLiking = true);
                        HapticFeedback.selectionClick();
                        ref
                            .read(commentActionControllerProvider)
                            .toggleLike(comment);
                        
                        // Spam blocking delay
                        await Future.delayed(const Duration(milliseconds: 500));
                        if(mounted) setState(() => _isLiking = false);
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 4.0,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              transitionBuilder: (child, animation) =>
                                  ScaleTransition(
                                    scale: animation,
                                    child: child,
                                  ),
                              child: Icon(
                                comment.isLiked
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                key: ValueKey<bool>(comment.isLiked),
                                size: iconSize,
                                color: comment.isLiked
                                    ? Colors.redAccent
                                    : Colors.grey,
                              ),
                            ),
                            if (comment.likeCount > 0) ...[
                              const SizedBox(width: 3),
                              Text(
                                comment.likeCount.toString(),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: comment.isLiked
                                      ? Colors.redAccent
                                      : Colors.grey,
                                  fontSize: iconSize - 2,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
