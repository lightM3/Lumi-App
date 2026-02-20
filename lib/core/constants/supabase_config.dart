// lib/core/constants/supabase_config.dart
// Supabase connection configuration — values loaded from .env at runtime.
//
// ⚠️  NEVER hard-code real credentials here.
//    Set them in the root `.env` file and they will be loaded via flutter_dotenv.

import 'package:flutter_dotenv/flutter_dotenv.dart';

abstract final class SupabaseConfig {
  /// Supabase project URL.
  /// Source: .env → SUPABASE_URL
  static String get url {
    final value = dotenv.env['SUPABASE_URL'];
    assert(
      value != null && value.isNotEmpty,
      '[SupabaseConfig] SUPABASE_URL is missing from .env file. '
      'Add it before running the app.',
    );
    return value!;
  }

  /// Supabase anonymous / public API key.
  /// Source: .env → SUPABASE_ANON_KEY
  static String get anonKey {
    final value = dotenv.env['SUPABASE_ANON_KEY'];
    assert(
      value != null && value.isNotEmpty,
      '[SupabaseConfig] SUPABASE_ANON_KEY is missing from .env file. '
      'Add it before running the app.',
    );
    return value!;
  }

  // ── Storage bucket names (must match Supabase dashboard) ───────────────
  static const String curationsStorageBucket = 'curation_images';
  static const String avatarsStorageBucket = 'avatars';

  // ── Table names ──────────────────────────────────────────────────────────
  static const String usersTable = 'users';
  static const String collectionsTable = 'collections';
  static const String photosTable = 'photos';
  static const String likesTable = 'likes';
}
