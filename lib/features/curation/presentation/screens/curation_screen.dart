// lib/features/curation/presentation/screens/curation_screen.dart
// LUMI — New Collection Screen (Multi-photo + Apple Music ambient blur)
// Layout: Variant 1 skeleton (borderless, thin typography, glassmorphism button)
// Glow:   Apple Music style — blurred, scaled copy of active photo as background

import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import '../../../../core/error/custom_exceptions.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../feed/presentation/controllers/feed_controller.dart';
import '../controllers/curation_controller.dart';

class CurationScreen extends ConsumerStatefulWidget {
  const CurationScreen({super.key});

  @override
  ConsumerState<CurationScreen> createState() => _CurationScreenState();
}

class _CurationScreenState extends ConsumerState<CurationScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _pageController = PageController(viewportFraction: 0.88);
  int _currentPage = 0;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // ── Publish ───────────────────────────────────────────────────────────────
  Future<void> _publish() async {
    HapticFeedback.mediumImpact();
    debugPrint('Publish butonu tıklandı, publish işlemi başlıyor...');

    try {
      await ref.read(curationControllerProvider.notifier).publishCollection();
      if (mounted) {
        // Trigger a refresh on the Discover Feed so the new content appears immediately
        // Need to import feedControllerProvider from feature/feed
        ref.invalidate(feedControllerProvider);

        _showSnack('Collection published ✦', isError: false);

        // Return to the previous screen (Discover feed)
        context.pop();
      }
    } on ValidationException catch (e) {
      debugPrint('[CurationScreen] Gerçek Hata: $e');
      if (mounted) _showSnack(e.message, isError: true);
    } on LumiException catch (e) {
      debugPrint('[CurationScreen] Gerçek Hata: $e');
      if (mounted) _showSnack(e.userMessage, isError: true);
    } catch (e, st) {
      debugPrint('[CurationScreen] Gerçek Hata: $e');
      debugPrint('[CurationScreen] Stacktrace: $st');
      if (mounted) {
        _showSnack(
          'An unexpected error occurred. Please try again.',
          isError: true,
        );
      }
    }
  }

  void _showSnack(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(AppSpacing.lg),
        backgroundColor: AppColors.inkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          side: BorderSide(
            color: isError ? AppColors.error : AppColors.success,
            width: 0.5,
          ),
        ),
        content: Row(
          children: [
            Icon(
              isError ? LucideIcons.alertCircle : LucideIcons.checkCircle,
              color: isError ? AppColors.error : AppColors.success,
              size: 16,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(msg, style: AppTextStyles.bodySmall)),
          ],
        ),
      ),
    );
  }

  void _showImageSourceActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: const BoxDecoration(
          color: AppColors.inkBlack,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.inkMuted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.inkSurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(LucideIcons.image, color: Colors.white),
                ),
                title: Text(
                  'Choose from Gallery',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  ref.read(curationControllerProvider.notifier).pickImages();
                },
              ),
              const SizedBox(height: AppSpacing.md),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.inkSurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(LucideIcons.camera, color: Colors.white),
                ),
                title: Text(
                  'Take a Photo',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  ref.read(curationControllerProvider.notifier).pickImageFromCamera();
                },
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(curationControllerProvider);
    final cs = asyncState.value ?? const CurationState();
    final isLoading = asyncState.isLoading;

    return Scaffold(
      backgroundColor: AppColors.inkBlack,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            _CurationAppBar(onClose: () => context.pop(), isLoading: isLoading),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.md),

                    // ── Photo area with localized glow ────────────────────
                    SizedBox(
                      height: MediaQuery.sizeOf(context).height * 0.40,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Glow behind cards (photo area only)
                          if (cs.hasPhotos)
                            _LocalizedGlow(
                              activeFile: _currentPage < cs.selectedFiles.length
                                  ? cs.selectedFiles[_currentPage]
                                  : null,
                            ),

                          // Cards on top
                          cs.hasPhotos
                              ? _PhotoPageView(
                                  files: cs.selectedFiles,
                                  pageController: _pageController,
                                  isLoading: isLoading,
                                  currentPage: _currentPage,
                                  onPageChanged: (i) {
                                    setState(() => _currentPage = i);
                                    if (i < cs.selectedFiles.length) {
                                      ref
                                          .read(
                                            curationControllerProvider.notifier,
                                          )
                                          .setActiveIndex(i);
                                    }
                                  },
                                  onAddMore: () => _showImageSourceActionSheet(context),
                                  onRemove: (i) => ref
                                      .read(curationControllerProvider.notifier)
                                      .removePhoto(i),
                                )
                              : _EmptyPickerArea(
                                  onTap: isLoading
                                      ? () {}
                                      : () => _showImageSourceActionSheet(context),
                                ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xxl),

                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xl,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _TitleField(
                            controller: _titleController,
                            enabled: !isLoading,
                            onChanged: ref
                                .read(curationControllerProvider.notifier)
                                .updateTitle,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _DescriptionField(
                            controller: _descController,
                            enabled: !isLoading,
                            onChanged: ref
                                .read(curationControllerProvider.notifier)
                                .updateDescription,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _PrivacyToggle(
                            value: cs.isPrivate,
                            onChanged: ref
                                .read(curationControllerProvider.notifier)
                                .updatePrivacy,
                          ),
                          const SizedBox(height: AppSpacing.xxl),
                          if (cs.hasPhotos) ...[
                            _PhotoReorderGrid(
                              files: cs.selectedFiles,
                              onReorder: ref
                                  .read(curationControllerProvider.notifier)
                                  .reorderPhotos,
                              onRemove: ref
                                  .read(curationControllerProvider.notifier)
                                  .removePhoto,
                            ),
                            const SizedBox(height: AppSpacing.xxl),
                          ],
                          _PublishButton(
                            isLoading: isLoading,
                            onTap: isLoading ? null : _publish,
                          ),
                          const SizedBox(height: AppSpacing.xxl),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Localized Glow ────────────────────────────────────────────────────────────
// Sits directly behind the photo cards INSIDE the photo SizedBox.
// ImageFiltered applies blur to its OWN child — not the backdrop.
// So the glow stays contained to the card region; the dark background
// below/above remains pure inkBlack.

class _LocalizedGlow extends StatelessWidget {
  const _LocalizedGlow({this.activeFile});
  final File? activeFile;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 1800),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: activeFile == null
          ? const SizedBox.expand(key: ValueKey('empty_glow'))
          : SizedBox.expand(
              key: ValueKey(activeFile!.path),
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 35, sigmaY: 35),
                child: Transform.scale(
                  scale: 1.3,
                  child: Image.file(activeFile!, fit: BoxFit.cover),
                ),
              ),
            ),
    );
  }
}

// ── Photo PageView ────────────────────────────────────────────────────────────

class _PhotoPageView extends StatelessWidget {
  const _PhotoPageView({
    required this.files,
    required this.pageController,
    required this.isLoading,
    required this.currentPage,
    required this.onPageChanged,
    required this.onAddMore,
    required this.onRemove,
  });

  final List<File> files;
  final PageController pageController;
  final bool isLoading;
  final int currentPage;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onAddMore;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // PageView
        Expanded(
          child: PageView.builder(
            controller: pageController,
            onPageChanged: onPageChanged,
            physics: const BouncingScrollPhysics(),
            itemCount: files.length + 1, // +1 for "Add more" tile
            itemBuilder: (ctx, i) {
              if (i == files.length) {
                // "Add more" tile at the end
                return _AddMoreTile(onTap: isLoading ? () {} : onAddMore);
              }
              return _PhotoTile(
                file: files[i],
                index: i,
                onRemove: isLoading ? null : () => onRemove(i),
              );
            },
          ),
        ),

        const SizedBox(height: 12),

        // Page indicator dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            files.length + 1, // +1 for add-more
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == currentPage ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: i == currentPage
                    ? AppColors.inkForeground
                    : AppColors.inkBorder,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.file,
    required this.index,
    required this.onRemove,
  });

  final File file;
  final int index;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(file, fit: BoxFit.cover),
            // Remove button
            Positioned(
              top: 12,
              right: 12,
              child: GestureDetector(
                onTap: onRemove,
                child: GlassContainer(
                  blur: 12,
                  opacity: 0.18,
                  borderRadius: 20,
                  borderOpacity: 0.2,
                  padding: const EdgeInsets.all(6),
                  child: const Icon(
                    LucideIcons.x,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            // Index badge
            Positioned(
              bottom: 12,
              left: 12,
              child: GlassContainer(
                blur: 8,
                opacity: 0.15,
                borderRadius: 12,
                borderOpacity: 0.15,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                child: Text(
                  '${index + 1}',
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddMoreTile extends StatelessWidget {
  const _AddMoreTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
            color: AppColors.inkSurface,
            border: Border.all(color: AppColors.inkBorder, width: 0.8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: AppColors.inkBorder,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.imagePlus,
                  color: AppColors.inkMuted,
                  size: 20,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Add more photos',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Empty Picker ──────────────────────────────────────────────────────────────

class _EmptyPickerArea extends StatelessWidget {
  const _EmptyPickerArea({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
            color: AppColors.inkSurface,
            border: Border.all(color: AppColors.inkBorder, width: 0.8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: AppColors.inkBorder,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.imagePlus,
                  color: AppColors.inkMuted,
                  size: 22,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Tap to add cover photo',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.inkMuted,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'You can select multiple photos',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.inkMuted.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── App Bar ───────────────────────────────────────────────────────────────────

class _CurationAppBar extends StatelessWidget {
  const _CurationAppBar({required this.onClose, required this.isLoading});
  final VoidCallback onClose;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: isLoading ? null : onClose,
            behavior: HitTestBehavior.opaque,
            child: const SizedBox(
              width: 36,
              height: 36,
              child: Icon(
                LucideIcons.x,
                color: AppColors.inkForeground,
                size: 20,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                'NEW COLLECTION',
                style: AppTextStyles.labelSmall.copyWith(
                  letterSpacing: 3,
                  color: AppColors.inkMuted,
                ),
              ),
            ),
          ),
          const SizedBox(width: 36), // symmetry
        ],
      ),
    );
  }
}

// ── Title Field ───────────────────────────────────────────────────────────────

class _TitleField extends StatelessWidget {
  const _TitleField({
    required this.controller,
    required this.enabled,
    required this.onChanged,
  });

  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      onChanged: onChanged,
      style: AppTextStyles.displayMedium.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w300,
        color: AppColors.inkForeground,
        height: 1.2,
      ),
      decoration: InputDecoration(
        hintText: 'Collection Title',
        hintStyle: AppTextStyles.displayMedium.copyWith(
          fontSize: 28,
          fontWeight: FontWeight.w300,
          color: AppColors.inkMuted.withValues(alpha: 0.5),
          height: 1.4,
        ),
        border: InputBorder.none,
        isDense: true,
        contentPadding: const EdgeInsets.only(left: 4),
      ),
      maxLines: 2,
      minLines: 1,
      textCapitalization: TextCapitalization.words,
    );
  }
}

// ── Description Field ─────────────────────────────────────────────────────────

class _DescriptionField extends StatelessWidget {
  const _DescriptionField({
    required this.controller,
    required this.enabled,
    required this.onChanged,
  });

  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      onChanged: onChanged,
      style: AppTextStyles.bodyMedium.copyWith(
        color: AppColors.inkForeground,
        height: 1.6,
      ),
      decoration: InputDecoration(
        hintText: 'Add aesthetic notes, vibes, or a description...',
        hintStyle: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.inkMuted.withValues(alpha: 0.5),
          height: 1.6,
        ),
        border: InputBorder.none,
        isDense: true,
        contentPadding: const EdgeInsets.fromLTRB(4, 4, 0, 0),
      ),
      maxLines: 5,
      minLines: 2,
      keyboardType: TextInputType.multiline,
    );
  }
}

// ── Publish Button ─────────────────────────────────────────────────────────────

class _PublishButton extends StatefulWidget {
  const _PublishButton({required this.isLoading, required this.onTap});
  final bool isLoading;
  final VoidCallback? onTap;

  @override
  State<_PublishButton> createState() => _PublishButtonState();
}

class _PublishButtonState extends State<_PublishButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 90),
  );
  late final Animation<double> _scale = Tween(
    begin: 1.0,
    end: 0.97,
  ).animate(_press);

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.isLoading ? null : (_) => _press.forward(),
      onTapUp: widget.isLoading
          ? null
          : (_) {
              _press.reverse();
              widget.onTap?.call();
            },
      onTapCancel: () => _press.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: GlassContainer(
          blur: 16,
          opacity: 0.08,
          borderRadius: AppSpacing.radiusXl,
          borderOpacity: 0.18,
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: widget.isLoading ? _LoadingRow() : _PublishRow(),
          ),
        ),
      ),
    );
  }
}

class _PublishRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Publish Collection',
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.w500,
            color: AppColors.inkForeground,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        const Icon(
          LucideIcons.arrowRight,
          size: 18,
          color: AppColors.inkForeground,
        ),
      ],
    );
  }
}

class _LoadingRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 15,
          height: 15,
          child: CircularProgressIndicator(
            strokeWidth: 1.6,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.inkMuted),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Text(
          'Publishing…',
          style: AppTextStyles.titleMedium.copyWith(
            color: AppColors.inkMuted,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _PrivacyToggle extends StatelessWidget {
  const _PrivacyToggle({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.inkSurface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.inkBorder, width: 0.5),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.lock, size: 18, color: AppColors.inkMuted),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Private Collection',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Only you can see this collection',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: const Color(0xFF6C4FCA),
          ),
        ],
      ),
    );
  }
}

class _PhotoReorderGrid extends StatelessWidget {
  const _PhotoReorderGrid({
    required this.files,
    required this.onReorder,
    required this.onRemove,
  });

  final List<File> files;
  final ReorderCallback onReorder;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Text(
            'REORDER PHOTOS',
            style: AppTextStyles.labelSmall.copyWith(
              letterSpacing: 2,
              color: AppColors.inkMuted.withValues(alpha: 0.7),
            ),
          ),
        ),
        ReorderableGridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: AppSpacing.sm,
            mainAxisSpacing: AppSpacing.sm,
            childAspectRatio: 1,
          ),
          itemCount: files.length,
          onReorder: onReorder,
          itemBuilder: (context, index) {
            return _PhotoGridItem(
              key: ValueKey('reorder_\${files[index].path}_\$index'),
              file: files[index],
              onRemove: () => onRemove(index),
            );
          },
        ),
      ],
    );
  }
}

class _PhotoGridItem extends StatelessWidget {
  const _PhotoGridItem({super.key, required this.file, required this.onRemove});

  final File file;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              child: Image.file(file, fit: BoxFit.cover),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.x, size: 10, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
