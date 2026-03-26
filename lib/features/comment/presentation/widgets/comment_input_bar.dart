import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../auth/presentation/widgets/guest_guard.dart';
import '../providers/active_reply_provider.dart';
import '../controllers/comment_action_controller.dart';

class CommentInputBar extends ConsumerStatefulWidget {
  final String collectionId;
  final ScrollController scrollController;

  const CommentInputBar({
    super.key,
    required this.collectionId,
    required this.scrollController,
  });

  @override
  ConsumerState<CommentInputBar> createState() => _CommentInputBarState();
}

class _CommentInputBarState extends ConsumerState<CommentInputBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    if (Supabase.instance.client.auth.currentSession == null) {
      GuestGuard.checkAuthAndShowModal(context, ref);
      return;
    }

    final activeReply = ref.read(activeReplyProvider);

    // Call optimistic update method using action controller
    ref
        .read(commentActionControllerProvider)
        .addComment(
          collectionId: widget.collectionId,
          content: text,
          parentId: activeReply?.id,
        );

    _controller.clear();
    ref.read(activeReplyProvider.notifier).state = null;

    // Smooth scroll to top/new comment if top-level comment added
    if (activeReply == null && widget.scrollController.hasClients) {
      widget.scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeReply = ref.watch(activeReplyProvider);
    final theme = Theme.of(context);
    final isGuest = Supabase.instance.client.auth.currentSession == null;

    // Auto-focus logic when someone taps "Yanıtla"
    ref.listen(activeReplyProvider, (previous, next) {
      if (next != null && !_focusNode.hasFocus) {
        _focusNode.requestFocus();
      }
    });

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.paddingOf(context).bottom + 12,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            offset: const Offset(0, -4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOutBack,
            alignment: Alignment.bottomLeft,
            child: activeReply != null
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '@${activeReply.authorUsername} adlı kişiye yanıt veriliyor',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: () {
                            ref.read(activeReplyProvider.notifier).state = null;
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Icon(
                              Icons.close,
                              size: 20,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  readOnly: isGuest,
                  onTap: () {
                    if (isGuest) {
                      FocusManager.instance.primaryFocus?.unfocus();
                      GuestGuard.checkAuthAndShowModal(context, ref);
                    }
                  },
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    hintText: 'Bir yorum ekle...',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey.withValues(alpha: 0.1),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: isGuest
                      ? () {
                          FocusManager.instance.primaryFocus?.unfocus();
                          GuestGuard.checkAuthAndShowModal(context, ref);
                        }
                      : _submit,
                  icon: const Icon(Icons.send_rounded),
                  color: theme.colorScheme.primary,
                  iconSize: 20,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
