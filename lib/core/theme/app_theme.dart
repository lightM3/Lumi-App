// lib/core/theme/app_theme.dart
// CURATOR — Minimal dark theme with Glassmorphism helpers.
// philosophy: Invisible UI. The photos should be the hero.

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import '../constants/app_text_styles.dart';

// ── Theme Data ────────────────────────────────────────────────────────────────

final class AppTheme {
  const AppTheme._();

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,

    // ── Color Scheme ────────────────────────────────────────────────────────
    colorScheme: const ColorScheme.dark(
      surface: AppColors.inkBlack,
      surfaceContainerHighest: AppColors.inkSurface,
      primary: AppColors.accentCream,
      secondary: AppColors.accentRose,
      tertiary: AppColors.accentSage,
      onSurface: AppColors.inkForeground,
      onPrimary: AppColors.inkBlack,
      error: AppColors.error,
      outline: AppColors.inkBorder,
    ),

    // ── Scaffold ────────────────────────────────────────────────────────────
    scaffoldBackgroundColor: AppColors.inkBlack,

    // ── AppBar — hidden by default, feature screens use custom headers ──────
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: AppColors.inkBlack,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      iconTheme: IconThemeData(color: AppColors.inkForeground, size: 22),
      titleTextStyle: AppTextStyles.titleLarge,
    ),

    // ── Bottom Navigation ────────────────────────────────────────────────────
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.inkSurface,
      selectedItemColor: AppColors.accentCream,
      unselectedItemColor: AppColors.inkMuted,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),

    // ── Typography ───────────────────────────────────────────────────────────
    textTheme: const TextTheme(
      displayLarge: AppTextStyles.displayLarge,
      displayMedium: AppTextStyles.displayMedium,
      headlineLarge: AppTextStyles.headlineLarge,
      headlineMedium: AppTextStyles.headlineMedium,
      titleLarge: AppTextStyles.titleLarge,
      titleMedium: AppTextStyles.titleMedium,
      bodyLarge: AppTextStyles.bodyLarge,
      bodyMedium: AppTextStyles.bodyMedium,
      bodySmall: AppTextStyles.bodySmall,
      labelLarge: AppTextStyles.labelLarge,
      labelSmall: AppTextStyles.labelSmall,
    ),

    // ── Cards ────────────────────────────────────────────────────────────────
    cardTheme: CardThemeData(
      color: AppColors.inkSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        side: const BorderSide(color: AppColors.inkBorder, width: 0.5),
      ),
      margin: EdgeInsets.zero,
    ),

    // ── Input / Form ─────────────────────────────────────────────────────────
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.inkSurface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        borderSide: const BorderSide(color: AppColors.inkBorder, width: 0.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        borderSide: const BorderSide(color: AppColors.inkBorder, width: 0.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        borderSide: const BorderSide(color: AppColors.accentCream, width: 1.0),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        borderSide: const BorderSide(color: AppColors.error, width: 0.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        borderSide: const BorderSide(color: AppColors.error, width: 1.0),
      ),
      hintStyle: AppTextStyles.bodyMedium,
      errorStyle: AppTextStyles.caption.copyWith(color: AppColors.error),
    ),

    // ── Divider ──────────────────────────────────────────────────────────────
    dividerTheme: const DividerThemeData(
      color: AppColors.inkBorder,
      thickness: 0.5,
      space: 0,
    ),

    // ── Icon defaults ────────────────────────────────────────────────────────
    iconTheme: const IconThemeData(color: AppColors.inkForeground, size: 22),

    // ── Page transition ──────────────────────────────────────────────────────
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}

// ── Glassmorphism Factory ─────────────────────────────────────────────────────

/// Stateless helper widget — wraps [child] in a frosted-glass container.
///
/// Usage:
/// ```dart
/// GlassContainer(
///   blur: 16,
///   child: Text('Hello'),
/// )
/// ```
final class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 12.0,
    this.opacity = 0.12,
    this.borderRadius = AppSpacing.radiusLg,
    this.borderOpacity = 0.2,
    this.padding,
    this.width,
    this.height,
  });

  final Widget child;
  final double blur;
  final double opacity;
  final double borderRadius;
  final double borderOpacity;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          width: width,
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: opacity),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: Colors.white.withValues(alpha: borderOpacity),
              width: 0.6,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ── Animated Dominant Colour Background ────────────────────────────────────────

/// Wraps a [Scaffold] body with an [AnimatedContainer] that transitions the
/// background colour from [inkBlack] to a [dominantColor] when provided.
final class DominantColorBackground extends StatelessWidget {
  const DominantColorBackground({
    super.key,
    required this.child,
    this.dominantColor,
    this.duration = const Duration(milliseconds: 600),
  });

  final Widget child;
  final Color? dominantColor;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final targetColor =
        dominantColor?.withValues(alpha: 60 / 255) ?? AppColors.inkBlack;

    return AnimatedContainer(
      duration: duration,
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [targetColor, AppColors.inkBlack],
        ),
      ),
      child: child,
    );
  }
}
