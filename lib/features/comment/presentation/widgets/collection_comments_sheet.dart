import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/comment_cache_provider.dart';
import '../controllers/comment_list_controller.dart';
import 'comment_tile_widget.dart';
import 'comment_input_bar.dart';

class CollectionCommentsSheet extends ConsumerStatefulWidget {
  final String collectionId;

  const CollectionCommentsSheet({super.key, required this.collectionId});

  static void show(BuildContext context, String collectionId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor:
          Colors.transparent, // transparent for rounded corners container
      builder: (_) => CollectionCommentsSheet(collectionId: collectionId),
    );
  }

  @override
  ConsumerState<CollectionCommentsSheet> createState() =>
      _CollectionCommentsSheetState();
}

class _CollectionCommentsSheetState
    extends ConsumerState<CollectionCommentsSheet> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keep the cache alive as long as this sheet is open.
    ref.watch(commentCacheProvider);

    final listStateAsync = ref.watch(
      commentListControllerProvider(widget.collectionId),
    );

    return Padding(
      // Ensure bottom sheet sits above the keyboard
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: GestureDetector(
        onTap: () {
          // Unfocus when tapping anywhere outside the input
          FocusScope.of(context).unfocus();
        },
        child: Container(
          height: MediaQuery.sizeOf(context).height * 0.85,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Grabber handle
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(
                      'Yorumlar',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
              const Divider(),

              // Infinite List
              Expanded(
                child: listStateAsync.when(
                  data: (state) {
                    if (state.commentIds.isEmpty) {
                      return const Center(
                        child: Text(
                          'İlk yorumu sen yap!',
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.only(bottom: 24, top: 4),
                      itemCount: state.commentIds.length,
                      itemBuilder: (context, index) {
                        return CommentTileWidget(
                          collectionId: widget.collectionId,
                          commentId: state.commentIds[index],
                        );
                      },
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, st) =>
                      Center(child: Text('Yorumlar yüklenemedi: $e')),
                ),
              ),

              // Fixed Input Bar Above Keyboard
              CommentInputBar(
                collectionId: widget.collectionId,
                scrollController: _scrollController,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
