// lib/features/shared/screens/home_screen.dart
// Temporary placeholder — replaced with real Feed screen in Phase 3.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/routing/app_router.dart';
import '../../auth/presentation/controllers/auth_controller.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.inkBlack,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Placeholder sparkle
              const Icon(
                Icons.auto_awesome_rounded,
                color: Color(0xFF8B6FE8),
                size: 48,
              ),
              const SizedBox(height: 24),
              Text('Welcome to Lumi ✦', style: AppTextStyles.headlineLarge),
              const SizedBox(height: 8),
              authAsync.when(
                data: (user) =>
                    Text(user?.username ?? '', style: AppTextStyles.bodyMedium),
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 48),
              // ── New Collection shortcut ───────────────────────────────
              GestureDetector(
                onTap: () => context.push(AppRoutes.curation),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B6FE8).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF8B6FE8).withValues(alpha: 0.3),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.add_rounded,
                        color: Color(0xFF8B6FE8),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'New Collection',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: const Color(0xFF8B6FE8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Sign-out (debug helper) ───────────────────────────────
              GestureDetector(
                onTap: () async {
                  await ref.read(authControllerProvider.notifier).signOut();
                  if (context.mounted) context.go(AppRoutes.auth);
                },
                child: Text(
                  'Sign out',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.inkMuted,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.inkMuted,
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
