// lib/features/auth/presentation/controllers/auth_controller.dart
// Riverpod AsyncNotifier — single source of truth for auth state.
// UI never imports Supabase directly; all logic lives here.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/supabase_auth_repository.dart';
import '../../domain/auth_repository.dart';
import '../../domain/models/lumi_user.dart';

// ── Repository Provider ───────────────────────────────────────────────────────

/// Provides the [AuthRepository] implementation.
/// Override in tests with a mock: ProviderScope(overrides: [...]).
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => createSupabaseAuthRepository(),
);

// ── Auth State Provider ───────────────────────────────────────────────────────

/// Tracks the current user across the app.
/// null → not signed in | LumiUser → signed in
final authStateProvider = StreamProvider<LumiUser?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

// ── Auth Controller ───────────────────────────────────────────────────────────

/// Exposes [signInWithApple], [signInWithGoogle], [signOut].
/// State: `AsyncValue<LumiUser?>` — loading / error / data handled by UI.
class AuthController extends AsyncNotifier<LumiUser?> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  Future<LumiUser?> build() async {
    // Return current user synchronously on startup.
    return _repo.currentUser;
  }

  // ── Apple Sign-In ─────────────────────────────────────────────────────────

  Future<void> signInWithApple() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.signInWithApple());
  }

  // ── Google Sign-In ────────────────────────────────────────────────────────

  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.signInWithGoogle());
  }

  // ── Sign Out ──────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repo.signOut();
      return null;
    });
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, LumiUser?>(
  AuthController.new,
);
