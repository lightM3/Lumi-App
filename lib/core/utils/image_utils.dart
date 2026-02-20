// lib/core/utils/image_utils.dart
// CURATOR — Image compression & dominant colour extraction.
//
// Critical rules (from PRD §5.1 & §4.2):
// 1. Images MUST be compressed before upload (flutter_image_compress).
// 2. Heavy computation (palette_generator) MUST NOT block the UI thread.
//    → Uses compute() to run on a background isolate.

import 'dart:io';

import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:palette_generator/palette_generator.dart';
import '../error/custom_exceptions.dart';

abstract final class ImageUtils {
  // ── Compression ────────────────────────────────────────────────────────────

  /// Compresses [file] to JPEG with the given [quality] (1–100).
  ///
  /// Returns compressed bytes. Throws [ImageCompressionException] on failure.
  /// Quality default: 82 — good balance between size and visual quality.
  static Future<Uint8List> compressImage(
    File file, {
    int quality = 82,
    int minWidth = 1080,
    int minHeight = 1080,
  }) async {
    try {
      final result = await FlutterImageCompress.compressWithFile(
        file.absolute.path,
        quality: quality,
        minWidth: minWidth,
        minHeight: minHeight,
        format: CompressFormat.jpeg,
        keepExif: false,
      );

      if (result == null) {
        // Fallback to original bytes
        debugPrint(
          '[ImageUtils] compressWithFile returned null, using original bytes.',
        );
        return file.readAsBytesSync();
      }

      return result;
    } catch (e) {
      // libjpeg error 122 (Invalid SOS parameters) or any Skia/decoder error.
      // Graceful Fallback: Return the original bytes instead of crashing.
      debugPrint(
        '[ImageUtils] Failed to compress image ($e). Falling back to original bytes.',
      );
      return file.readAsBytesSync();
    }
  }

  // ── Aspect Ratio ───────────────────────────────────────────────────────────

  /// Decodes [bytes] and returns width/height ratio.
  /// Runs asynchronously on the main thread (dart:ui cannot be used in isolates).
  ///
  /// Used to store `aspect_ratio` in the `photos` table so the Masonry grid
  /// can pre-size placeholders and prevent layout shifts.
  static Future<double> extractAspectRatio(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final width = frame.image.width;
    final height = frame.image.height;
    frame.image.dispose();

    if (height == 0) return 1.0;
    return width / height;
  }

  // ── Dominant Colour Extraction ─────────────────────────────────────────────

  /// Extracts the dominant/vibrant colour from [imageProvider].
  ///
  /// Returns [Color] from PaletteGenerator. Falls back to a neutral dark if
  /// palette extraction fails (graceful degradation — never crash).
  ///
  /// ⚠️  Call this AFTER displaying the image, not during upload, to avoid
  ///    blocking the image render pipeline.
  static Future<ui.Color> extractDominantColor(
    ImageProvider imageProvider,
  ) async {
    try {
      final PaletteGenerator generator =
          await PaletteGenerator.fromImageProvider(
            imageProvider,
            maximumColorCount: 32,
          );

      final dominant =
          generator.darkMutedColor?.color ??
          generator.dominantColor?.color ??
          const ui.Color(0xFF131316); // fallback: inkSurface

      return dominant;
    } catch (e) {
      // Graceful: colour extraction failing must never crash the app.
      debugPrint('[ImageUtils] extractDominantColor failed: $e');
      return const ui.Color(0xFF131316);
    }
  }

  // ── Hex conversion helper ──────────────────────────────────────────────────

  /// Converts [color] to a hex string such as `#FF5733`.
  /// Used when persisting `dominant_color` to Supabase.
  static String colorToHex(ui.Color color) {
    return '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
  }

  /// Parses a hex string (with or without `#`) to a [Color].
  static ui.Color hexToColor(String hex) {
    final cleaned = hex.replaceFirst('#', '');
    final value = int.parse(
      cleaned.length == 6 ? 'FF$cleaned' : cleaned,
      radix: 16,
    );
    return ui.Color(value);
  }
}
