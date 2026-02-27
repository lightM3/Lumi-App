// lib/features/feed/presentation/widgets/glass_bottom_nav.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../auth/presentation/widgets/guest_guard.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';

class GlassBottomNav extends ConsumerWidget {
  const GlassBottomNav({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      bottom: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.inkSurface.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 0.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Discover
                  IconButton(
                    icon: Icon(
                      LucideIcons.compass,
                      color: GoRouterState.of(context).uri.path == '/feed'
                          ? AppColors.accentCream
                          : AppColors.inkMuted,
                    ),
                    onPressed: () {
                      final currentPath = GoRouterState.of(context).uri.path;
                      if (currentPath != '/feed') {
                        context.go('/feed');
                      }
                    },
                  ),

                  // Curation (Add) Button with Glow
                  GestureDetector(
                    onTap: () async {
                      final isAuth = await GuestGuard.checkAuthAndShowModal(
                        context,
                        ref,
                      );
                      if (isAuth && context.mounted) {
                        context.push('/curation');
                      }
                    },
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.accentCream,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accentCream.withValues(alpha: 0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        LucideIcons.plus,
                        color: AppColors.inkBlack,
                        size: 24,
                      ),
                    ),
                  ),

                  // Profile
                  IconButton(
                    icon: Icon(
                      LucideIcons.userCircle,
                      color: GoRouterState.of(context).uri.path == '/profile'
                          ? AppColors.accentCream
                          : AppColors.inkMuted,
                    ),
                    onPressed: () async {
                      final currentPath = GoRouterState.of(context).uri.path;
                      if (currentPath != '/profile') {
                        final isAuth = await GuestGuard.checkAuthAndShowModal(
                          context,
                          ref,
                        );
                        if (isAuth && context.mounted) {
                          context.go('/profile');
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
