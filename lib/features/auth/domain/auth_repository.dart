// lib/features/auth/domain/auth_repository.dart
// Abstract interface — presentation and domain layers never import Supabase directly.
// Data layer implements this; Riverpod provides it via a provider override.

import 'models/lumi_user.dart';

abstract interface class AuthRepository {
  /// Returns the currently signed-in user, or null if unauthenticated.
  LumiUser? get currentUser;

  /// Stream of auth state changes.
  /// Emits [LumiUser] on sign-in, null on sign-out.
  Stream<LumiUser?> get authStateChanges;

  /// Signs in with Apple OAuth.
  /// On first login, creates a record in the `users` table.
  /// Throws [AuthException] on failure.
  Future<LumiUser> signInWithApple();

  /// Signs in with Google OAuth.
  /// On first login, creates a record in the `users` table.
  /// Throws [AuthException] on failure.
  Future<LumiUser> signInWithGoogle();

  /// Signs out the current user.
  Future<void> signOut();
}
