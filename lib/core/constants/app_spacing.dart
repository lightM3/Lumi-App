// lib/core/constants/app_spacing.dart
// Consistent 4-pt grid spacing tokens.

abstract final class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 48.0;

  // ── Border radius ────────────────────────────────────────────────────────
  static const double radiusSm = 8.0;
  static const double radiusMd = 14.0;
  static const double radiusLg = 20.0;
  static const double radiusXl = 28.0;
  static const double radiusFull = 9999.0;

  // ── Touch target minimum (Material 48dp / iOS 44pt) ──────────────────────
  static const double minTouchTarget = 48.0;

  // ── Page padding ─────────────────────────────────────────────────────────
  static const double pagePaddingH = 16.0;
  static const double pagePaddingV = 20.0;

  // ── Grid ─────────────────────────────────────────────────────────────────
  static const double gridGutter = 6.0;
  static const double gridColumns = 2;
}
