import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

import 'package:album/features/auth/data/supabase_auth_repository.dart';
import 'package:album/core/error/custom_exceptions.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockSession extends Mock implements Session {}

class MockUser extends Mock implements User {}

void main() {
  late SupabaseAuthRepository repository;
  late MockSupabaseClient mockSupabaseClient;
  late MockGoTrueClient mockGoTrueClient;

  setUp(() {
    mockSupabaseClient = MockSupabaseClient();
    mockGoTrueClient = MockGoTrueClient();

    // Link the GoTrue auth client to the mocked Supabase client
    when(() => mockSupabaseClient.auth).thenReturn(mockGoTrueClient);

    repository = SupabaseAuthRepository(mockSupabaseClient);
  });

  group('SupabaseAuthRepository Unit Tests', () {
    test('currentUser returns null when session is null', () {
      when(() => mockGoTrueClient.currentSession).thenReturn(null);

      final user = repository.currentUser;
      expect(user, isNull);
    });

    test('currentUser returns LumiUser when session is valid', () {
      final mockSession = MockSession();
      final mockUser = MockUser();

      when(() => mockUser.id).thenReturn('user-123');
      when(() => mockUser.userMetadata).thenReturn({'name': 'Test User'});
      when(
        () => mockUser.createdAt,
      ).thenReturn(DateTime(2023).toIso8601String());
      when(() => mockSession.user).thenReturn(mockUser);
      when(() => mockGoTrueClient.currentSession).thenReturn(mockSession);

      final user = repository.currentUser;

      expect(user, isNotNull);
      expect(user!.id, 'user-123');
      expect(user.username, 'Test User');
    });

    test('signOut successful', () async {
      when(() => mockGoTrueClient.signOut()).thenAnswer((_) async {});

      await expectLater(repository.signOut(), completes);
      verify(() => mockGoTrueClient.signOut()).called(1);
    });

    test('signOut throws AuthException on failure', () async {
      when(
        () => mockGoTrueClient.signOut(),
      ).thenThrow(const AuthException('Error signing out'));

      await expectLater(repository.signOut(), throwsA(isA<AuthException>()));
    });
  });
}
