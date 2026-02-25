import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/routing/app_router.dart';

/// A central utility to check if the user is authenticated.
/// If not, it displays a beautiful bottom sheet prompting them to log in.
/// Returns [true] if authenticated, [false] otherwise.
class GuestGuard {
  static Future<bool> checkAuthAndShowModal(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      return true; // Authenticated
    }

    // Guest — Show login prompt
    if (context.mounted) {
      await showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (modalCtx) => const GuestPromptModal(),
      );
    }
    return false;
  }
}

class GuestPromptModal extends StatelessWidget {
  const GuestPromptModal({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.inkBlack,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 48,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: AppColors.inkBorder.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Icon(
                Icons.auto_awesome_rounded,
                color: AppColors.accentCream,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'Giriş Yapmalısınız',
                style: AppTextStyles.headlineMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Bu özelliği kullanabilmek, içerikleri beğenebilmek ve koleksiyon panoları oluşturabilmek için giriş yapmanız gerekmektedir.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.inkMuted,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Close modal
                    context.push(AppRoutes.auth); // Go to login
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
                    'Giriş Yap',
                    style: AppTextStyles.labelLarge.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: AppColors.inkBorder.withValues(alpha: 0.5),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    'Vazgeç',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: AppColors.inkForeground,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
