// lib/features/auth/data/supabase_auth_repository.dart
// Supabase implementation of AuthRepository.
// Responsibilities:
//   1. Trigger OAuth sign-in (Apple / Google) via Supabase
//   2. On first sign-in → upsert row in `users` table (PRD §4.1)
//   3. Map Supabase Session/User → LumiUser domain model
//   4. Expose auth state changes as a Stream

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

import '../../../core/constants/supabase_config.dart';
import '../../../core/error/custom_exceptions.dart';
import '../domain/auth_repository.dart';
import '../domain/models/lumi_user.dart';

final class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._supabase);

  final SupabaseClient _supabase;

  // ── currentUser ───────────────────────────────────────────────────────────

  @override
  LumiUser? get currentUser {
    final session = _supabase.auth.currentSession;
    if (session == null) return null;
    return _mapSessionToUser(session);
  }

  // ── authStateChanges ──────────────────────────────────────────────────────

  @override
  Stream<LumiUser?> get authStateChanges {
    return _supabase.auth.onAuthStateChange.map((data) {
      final session = data.session;
      if (session == null) return null;
      return _mapSessionToUser(session);
    });
  }

  // ── signInWithApple ───────────────────────────────────────────────────────

  @override
  Future<LumiUser> signInWithApple() async {
    try {
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.apple,
        // Always provide the deep link — Supabase ignores it on web automatically.
        redirectTo: 'io.lumi://login-callback',
        authScreenLaunchMode: LaunchMode.externalApplication,
      );

      // Wait for the session to be established after the OAuth redirect.
      final session = await _awaitSession();
      final user = _mapSessionToUser(session);
      await _upsertUserRecord(user, session);
      return user;
    } on LumiException {
      rethrow;
    } catch (e) {
      throw AuthException('Apple sign-in failed.', cause: e);
    }
  }

  // ── signInWithGoogle ──────────────────────────────────────────────────────

  @override
  Future<LumiUser> signInWithGoogle() async {
    try {
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        // Always provide the deep link — Supabase ignores it on web automatically.
        redirectTo: 'io.lumi://login-callback',
        authScreenLaunchMode: LaunchMode.externalApplication,
      );

      final session = await _awaitSession();
      final user = _mapSessionToUser(session);
      await _upsertUserRecord(user, session);
      return user;
    } on LumiException {
      rethrow;
    } catch (e) {
      throw AuthException('Google sign-in failed.', cause: e);
    }
  }

  // ── signOut ───────────────────────────────────────────────────────────────

  @override
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      throw AuthException('Sign-out failed.', cause: e);
    }
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  /// Waits for a valid Supabase session after the OAuth redirect completes.
  /// Times out after 90 seconds with a meaningful error.
  Future<Session> _awaitSession() async {
    const timeout = Duration(seconds: 90);

    try {
      final event = await _supabase.auth.onAuthStateChange
          .where(
            (data) =>
                data.event == AuthChangeEvent.signedIn && data.session != null,
          )
          .map((data) => data.session!)
          .first
          .timeout(timeout);
      return event;
    } catch (e) {
      throw const AuthException(
        'Sign-in timed out or was cancelled. Please try again.',
      );
    }
  }

  /// Maps a Supabase [Session] to our domain [LumiUser].
  LumiUser _mapSessionToUser(Session session) {
    final meta = session.user.userMetadata ?? {};
    final rawUsername =
        meta['full_name'] as String? ??
        meta['name'] as String? ??
        session.user.email?.split('@').first ??
        'lumi_user_${session.user.id.substring(0, 6)}';

    return LumiUser(
      id: session.user.id,
      username: rawUsername,
      avatarUrl: meta['avatar_url'] as String? ?? meta['picture'] as String?,
      createdAt: DateTime.tryParse(session.user.createdAt) ?? DateTime.now(),
    );
  }

  /// Upserts a row in `users` table (PRD §2 schema).
  /// Uses `ignoreDuplicates: false` + onConflict so existing users are left intact.
  Future<void> _upsertUserRecord(LumiUser user, Session session) async {
    try {
      await _supabase
          .from(SupabaseConfig.usersTable)
          .upsert(
            user.toInsertMap(),
            onConflict: 'id',
            ignoreDuplicates: true, // existing user → keep their data
          );
    } catch (e) {
      // Non-fatal: if upsert fails, the user is still authenticated.
      // Log and continue — we never crash a successful login on a DB write.
      debugPrint('[SupabaseAuthRepository] upsert failed (non-fatal): $e');
    }
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

/// Provides a [SupabaseAuthRepository] backed by the global Supabase client.
/// Used by [authRepositoryProvider] in the controller layer.
SupabaseAuthRepository createSupabaseAuthRepository() {
  return SupabaseAuthRepository(Supabase.instance.client);
}
