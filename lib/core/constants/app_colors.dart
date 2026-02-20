// lib/core/constants/app_colors.dart
// CURATOR — VSCO/Pinterest aesthetics, dark-first palette.

import 'package:flutter/material.dart';

abstract final class AppColors {
  // ── Brand Palette ──────────────────────────────────────────────────────────
  /// Deep ink — primary background (OLED-safe)
  static const Color inkBlack = Color(0xFF0A0A0B);

  /// Elevated surface (cards, sheets)
  static const Color inkSurface = Color(0xFF131316);

  /// Border / divider
  static const Color inkBorder = Color(0xFF222228);

  /// Neutral text on dark
  static const Color inkForeground = Color(0xFFF0EEE9);

  /// Muted / secondary text
  static const Color inkMuted = Color(0xFF888896);

  // ── Accent ─────────────────────────────────────────────────────────────────
  /// Warm cream accent — VSCO warmth
  static const Color accentCream = Color(0xFFF5F0E8);

  /// Dusty rose — subtle highlight / like indicator
  static const Color accentRose = Color(0xFFD4A5A5);

  /// Sage green — secondary action
  static const Color accentSage = Color(0xFF8FAD8C);

  // ── Glass / Blur Layer ──────────────────────────────────────────────────────
  /// Glassmorphism fill — white with very low opacity
  static const Color glassLight = Color(0x14FFFFFF);

  /// Glassmorphism fill — dark with low opacity
  static const Color glassDark = Color(0x1A000000);

  /// Glass border highlight
  static const Color glassBorder = Color(0x28FFFFFF);

  // ── Status ─────────────────────────────────────────────────────────────────
  static const Color error = Color(0xFFE07070);
  static const Color success = Color(0xFF6DAA7A);
  static const Color warning = Color(0xFFD4A85A);

  // ── Gradient presets ───────────────────────────────────────────────────────
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [inkBlack, Color(0xFF0F0F16)],
  );

  static const LinearGradient cardShimmer = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [inkSurface, Color(0xFF1C1C24), inkSurface],
  );

  // Helper: creates a dominant-colour-derived gradient for collection cards
  static LinearGradient fromDominant(Color dominant) => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Colors.transparent, dominant.withAlpha(200)],
  );
}
