// lib/features/auth/presentation/screens/login_screen.dart
// LUMI — Auth entry screen.
// Wired to AuthController (Riverpod AsyncNotifier).
// Loading state: button text fades to 'Connecting…' with a tiny CupertinoIndicator.
// Error state: themed SnackBar at the bottom.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../controllers/auth_controller.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  // ── Error feedback ────────────────────────────────────────────────────────
  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(AppSpacing.lg),
        backgroundColor: AppColors.inkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          side: const BorderSide(color: AppColors.error, width: 0.5),
        ),
        content: Row(
          children: [
            const Icon(
              LucideIcons.alertCircle,
              color: AppColors.error,
              size: 16,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.inkForeground,
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ── Auth callbacks ────────────────────────────────────────────────────────
  Future<void> _handleApple(BuildContext context, WidgetRef ref) async {
    HapticFeedback.lightImpact();
    await ref.read(authControllerProvider.notifier).signInWithApple();

    if (!context.mounted) return;
    final state = ref.read(authControllerProvider);
    state.whenOrNull(
      data: (user) {
        if (user != null) context.go(AppRoutes.feed);
      },
      error: (e, _) => _showError(context, e.toString()),
    );
  }

  Future<void> _handleGoogle(BuildContext context, WidgetRef ref) async {
    HapticFeedback.lightImpact();
    await ref.read(authControllerProvider.notifier).signInWithGoogle();

    if (!context.mounted) return;
    final state = ref.read(authControllerProvider);
    state.whenOrNull(
      data: (user) {
        if (user != null) context.go(AppRoutes.feed);
      },
      error: (e, _) => _showError(context, e.toString()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authControllerProvider);
    final isLoading = authAsync.isLoading;
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: AppColors.inkBlack,
      body: Stack(
        children: [
          // ── Radial ambient glow ───────────────────────────────────────────
          _AmbientGlow(size: size),

          // ── Main content ──────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Spacer(flex: 2),

                  // ── Auth Card ───────────────────────────────────────────
                  GlassContainer(
                    blur: 20,
                    opacity: 0.06,
                    borderRadius: AppSpacing.radiusXl,
                    borderOpacity: 0.15,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                      vertical: AppSpacing.xxl,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const _AppIconBadge(),
                        const SizedBox(height: AppSpacing.lg),

                        Text(
                          'Lumi',
                          style: AppTextStyles.displayMedium.copyWith(
                            fontSize: 36,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),

                        Text(
                          'PREMIUM PHOTO CURATION',
                          style: AppTextStyles.labelSmall.copyWith(
                            letterSpacing: 2.5,
                            color: AppColors.inkMuted,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxl),

                        // ── Apple button ───────────────────────────────
                        _AppleLoginButton(
                          isLoading: isLoading,
                          onTap: () => _handleApple(context, ref),
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // ── Google button ──────────────────────────────
                        _GoogleLoginButton(
                          isLoading: isLoading,
                          onTap: () => _handleGoogle(context, ref),
                        ),
                        const SizedBox(height: AppSpacing.xl),

                        _SignUpRow(onTap: () {}),
                      ],
                    ),
                  ),

                  const Spacer(flex: 2),

                  _FooterLinks(onPrivacy: () {}, onTerms: () {}),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Ambient Glow ──────────────────────────────────────────────────────────────

class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow({required this.size});
  final Size size;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: CustomPaint(painter: _GlowPainter(size: size)),
    );
  }
}

class _GlowPainter extends CustomPainter {
  const _GlowPainter({required this.size});
  final Size size;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final paint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              const Color(0xFF6C4FCA).withValues(alpha: 0.18),
              Colors.transparent,
            ],
            stops: const [0.0, 1.0],
          ).createShader(
            Rect.fromCircle(
              center: Offset(canvasSize.width / 2, canvasSize.height * 0.25),
              radius: canvasSize.width * 0.8,
            ),
          );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── App Icon Badge ─────────────────────────────────────────────────────────────

class _AppIconBadge extends StatelessWidget {
  const _AppIconBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8B6FE8), Color(0xFF5B3FC8)],
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C4FCA).withValues(alpha: 0.45),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Icon(LucideIcons.sparkles, color: Colors.white, size: 28),
    );
  }
}

// ── Apple Login Button ─────────────────────────────────────────────────────────

class _AppleLoginButton extends StatelessWidget {
  const _AppleLoginButton({required this.onTap, required this.isLoading});

  final VoidCallback onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return _AuthButton(
      onTap: onTap,
      isLoading: isLoading,
      backgroundColor: Colors.white,
      foregroundColor: AppColors.inkBlack,
      borderColor: Colors.transparent,
      icon: const Icon(Icons.apple, color: AppColors.inkBlack, size: 22),
      label: 'Continue with Apple',
      loadingColor: AppColors.inkBlack,
    );
  }
}

// ── Google Login Button ────────────────────────────────────────────────────────

class _GoogleLoginButton extends StatelessWidget {
  const _GoogleLoginButton({required this.onTap, required this.isLoading});

  final VoidCallback onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return _AuthButton(
      onTap: onTap,
      isLoading: isLoading,
      backgroundColor: Colors.transparent,
      foregroundColor: AppColors.inkForeground,
      borderColor: AppColors.inkBorder,
      icon: _GoogleLetterIcon(),
      label: 'Continue with Google',
      loadingColor: AppColors.inkMuted,
    );
  }
}

// ── Reusable Auth Button — with graceful loading state animation ───────────────

class _AuthButton extends StatefulWidget {
  const _AuthButton({
    required this.onTap,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.borderColor,
    required this.icon,
    required this.label,
    required this.isLoading,
    required this.loadingColor,
  });

  final VoidCallback onTap;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color borderColor;
  final Widget icon;
  final String label;
  final bool isLoading;
  final Color loadingColor;

  @override
  State<_AuthButton> createState() => _AuthButtonState();
}

class _AuthButtonState extends State<_AuthButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 80),
    lowerBound: 0.0,
    upperBound: 0.03,
  );

  late final Animation<double> _scale = Tween<double>(
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
              widget.onTap();
            },
      onTapCancel: widget.isLoading ? null : () => _press.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          height: 56, // 56dp — comfortable touch target
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: widget.borderColor, width: 0.8),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: widget.isLoading
                // ── Loading state: small spinner + 'Connecting…' ──────────
                ? _LoadingContent(color: widget.loadingColor)
                // ── Default state: icon + label ───────────────────────────
                : _ButtonContent(
                    icon: widget.icon,
                    label: widget.label,
                    foregroundColor: widget.foregroundColor,
                  ),
          ),
        ),
      ),
    );
  }
}

// ── Button content sub-widgets ────────────────────────────────────────────────

class _ButtonContent extends StatelessWidget {
  const _ButtonContent({
    required this.icon,
    required this.label,
    required this.foregroundColor,
  });

  final Widget icon;
  final String label;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        icon,
        const SizedBox(width: AppSpacing.md),
        Text(
          label,
          style: AppTextStyles.titleMedium.copyWith(
            color: foregroundColor,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}

class _LoadingContent extends StatelessWidget {
  const _LoadingContent({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 1.8,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Text(
          'Connecting…',
          style: AppTextStyles.titleMedium.copyWith(
            color: color,
            fontWeight: FontWeight.w500,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}

// ── Google Icon ───────────────────────────────────────────────────────────────

class _GoogleLetterIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.inkMuted, width: 1.5),
      ),
      child: const Center(
        child: Text(
          'G',
          style: TextStyle(
            color: AppColors.inkForeground,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            height: 1,
          ),
        ),
      ),
    );
  }
}

// ── Sign Up Row ───────────────────────────────────────────────────────────────

class _SignUpRow extends StatelessWidget {
  const _SignUpRow({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Don't have an account? ",
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.inkMuted),
        ),
        GestureDetector(
          onTap: onTap,
          child: Text(
            'Sign up',
            style: AppTextStyles.bodySmall.copyWith(
              color: const Color(0xFF8B6FE8),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Footer Links ──────────────────────────────────────────────────────────────

class _FooterLinks extends StatelessWidget {
  const _FooterLinks({required this.onPrivacy, required this.onTerms});

  final VoidCallback onPrivacy;
  final VoidCallback onTerms;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: onPrivacy,
          child: Text(
            'Privacy Policy',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.inkMuted.withValues(alpha: 0.7),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Text(
            '·',
            style: TextStyle(color: AppColors.inkMuted, fontSize: 10),
          ),
        ),
        GestureDetector(
          onTap: onTerms,
          child: Text(
            'Terms of Service',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.inkMuted.withValues(alpha: 0.7),
            ),
          ),
        ),
      ],
    );
  }
}
