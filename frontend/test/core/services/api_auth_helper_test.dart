import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:disciplefy_bible_study/core/services/api_auth_helper.dart';

// Mock classes
class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockSession extends Mock implements Session {}

class MockUser extends Mock implements User {}

void main() {
  group('ApiAuthHelper Token Validation', () {
    late MockSupabaseClient mockSupabaseClient;
    late MockGoTrueClient mockGoTrueClient;
    late MockSession mockSession;
    late MockUser mockUser;

    setUp(() {
      mockSupabaseClient = MockSupabaseClient();
      mockGoTrueClient = MockGoTrueClient();
      mockSession = MockSession();
      mockUser = MockUser();

      // Set up basic mocks
      when(mockSupabaseClient.auth).thenReturn(mockGoTrueClient);
      when(mockSession.user).thenReturn(mockUser);
      when(mockUser.id).thenReturn('test-user-id');
    });

    group('validateCurrentToken', () {
      test('returns false when no session exists', () {
        // Arrange
        when(mockGoTrueClient.currentSession).thenReturn(null);

        // Act & Assert
        expect(ApiAuthHelper.validateCurrentToken(), false);
      });

      test('returns false when access token is empty', () {
        // Arrange
        when(mockGoTrueClient.currentSession).thenReturn(mockSession);
        when(mockSession.accessToken).thenReturn('');

        // Act & Assert
        expect(ApiAuthHelper.validateCurrentToken(), false);
      });

      test('returns false when token is expired', () {
        // Arrange
        final expiredTime = DateTime.now().subtract(Duration(hours: 1));
        final expiredTimestamp = expiredTime.millisecondsSinceEpoch ~/ 1000;

        when(mockGoTrueClient.currentSession).thenReturn(mockSession);
        when(mockSession.accessToken).thenReturn('valid-token');
        when(mockSession.expiresAt).thenReturn(expiredTimestamp);

        // Act & Assert
        expect(ApiAuthHelper.validateCurrentToken(), false);
      });

      test('returns true when token is valid and not expired', () {
        // Arrange
        final futureTime = DateTime.now().add(Duration(hours: 1));
        final futureTimestamp = futureTime.millisecondsSinceEpoch ~/ 1000;

        when(mockGoTrueClient.currentSession).thenReturn(mockSession);
        when(mockSession.accessToken).thenReturn('valid-token');
        when(mockSession.expiresAt).thenReturn(futureTimestamp);

        // Act & Assert
        expect(ApiAuthHelper.validateCurrentToken(), true);
      });
    });

    group('requiresTokenValidation', () {
      test('returns false for anonymous users (no session)', () {
        // Arrange
        when(mockGoTrueClient.currentSession).thenReturn(null);

        // Act & Assert
        expect(ApiAuthHelper.requiresTokenValidation(), false);
      });

      test('returns true when session exists', () {
        // Arrange
        when(mockGoTrueClient.currentSession).thenReturn(mockSession);

        // Act & Assert
        expect(ApiAuthHelper.requiresTokenValidation(), true);
      });
    });

    group('validateTokenForRequest', () {
      test('succeeds for anonymous users without validation', () async {
        // Arrange
        when(mockGoTrueClient.currentSession).thenReturn(null);

        // Act & Assert - should not throw
        await expectLater(
          ApiAuthHelper.validateTokenForRequest(),
          completes,
        );
      });

      test('throws TokenValidationException when token is invalid', () async {
        // Arrange
        when(mockGoTrueClient.currentSession).thenReturn(mockSession);
        when(mockSession.accessToken).thenReturn(''); // Invalid token

        // Act & Assert
        await expectLater(
          ApiAuthHelper.validateTokenForRequest(),
          throwsA(isA<TokenValidationException>()),
        );
      });

      test('succeeds when token is valid', () async {
        // Arrange
        final futureTime = DateTime.now().add(Duration(hours: 1));
        final futureTimestamp = futureTime.millisecondsSinceEpoch ~/ 1000;

        when(mockGoTrueClient.currentSession).thenReturn(mockSession);
        when(mockSession.accessToken).thenReturn('valid-token');
        when(mockSession.expiresAt).thenReturn(futureTimestamp);

        // Act & Assert - should not throw
        await expectLater(
          ApiAuthHelper.validateTokenForRequest(),
          completes,
        );
      });
    });
  });
}
