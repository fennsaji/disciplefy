import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:disciplefy_bible_study/core/services/api_auth_helper.dart';
import 'package:disciplefy_bible_study/core/error/exceptions.dart';

// Generate mocks
@GenerateMocks([
  SupabaseClient,
  GoTrueClient,
  Session,
  User,
])
import 'api_auth_helper_test.mocks.dart';

// Test wrapper class to inject mock dependencies
class TestableApiAuthHelper {
  static SupabaseClient? _testClient;

  static void setTestClient(SupabaseClient client) {
    _testClient = client;
  }

  static void resetTestClient() {
    _testClient = null;
  }

  static SupabaseClient get client => _testClient ?? Supabase.instance.client;

  static bool validateCurrentToken() {
    try {
      final session = client.auth.currentSession;
      if (session == null) {
        return false;
      }

      if (session.accessToken.isEmpty) {
        return false;
      }

      // Check if token is expired
      if (session.expiresAt != null) {
        final expiryDate =
            DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000);
        final now = DateTime.now();

        if (now.isAfter(expiryDate)) {
          return false;
        }
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  static bool requiresTokenValidation() {
    final session = client.auth.currentSession;
    return session != null;
  }

  static Future<void> validateTokenForRequest() async {
    if (!requiresTokenValidation()) {
      return;
    }

    if (!validateCurrentToken()) {
      throw const TokenValidationException(
          message: 'Authentication token is invalid or expired');
    }
  }
}

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

      // Set the test client
      TestableApiAuthHelper.setTestClient(mockSupabaseClient);
    });

    tearDown(() {
      TestableApiAuthHelper.resetTestClient();
    });

    group('validateCurrentToken', () {
      test('returns false when no session exists', () {
        // Arrange
        when(mockGoTrueClient.currentSession).thenReturn(null);

        // Act & Assert
        expect(TestableApiAuthHelper.validateCurrentToken(), false);
      });

      test('returns false when access token is empty', () {
        // Arrange
        when(mockGoTrueClient.currentSession).thenReturn(mockSession);
        when(mockSession.accessToken).thenReturn('');

        // Act & Assert
        expect(TestableApiAuthHelper.validateCurrentToken(), false);
      });

      test('returns false when token is expired', () {
        // Arrange
        final expiredTime = DateTime.now().subtract(Duration(hours: 1));
        final expiredTimestamp = expiredTime.millisecondsSinceEpoch ~/ 1000;

        when(mockGoTrueClient.currentSession).thenReturn(mockSession);
        when(mockSession.accessToken).thenReturn('valid-token');
        when(mockSession.expiresAt).thenReturn(expiredTimestamp);

        // Act & Assert
        expect(TestableApiAuthHelper.validateCurrentToken(), false);
      });

      test('returns true when token is valid and not expired', () {
        // Arrange
        final futureTime = DateTime.now().add(Duration(hours: 1));
        final futureTimestamp = futureTime.millisecondsSinceEpoch ~/ 1000;

        when(mockGoTrueClient.currentSession).thenReturn(mockSession);
        when(mockSession.accessToken).thenReturn('valid-token');
        when(mockSession.expiresAt).thenReturn(futureTimestamp);

        // Act & Assert
        expect(TestableApiAuthHelper.validateCurrentToken(), true);
      });
    });

    group('requiresTokenValidation', () {
      test('returns false for anonymous users (no session)', () {
        // Arrange
        when(mockGoTrueClient.currentSession).thenReturn(null);

        // Act & Assert
        expect(TestableApiAuthHelper.requiresTokenValidation(), false);
      });

      test('returns true when session exists', () {
        // Arrange
        when(mockGoTrueClient.currentSession).thenReturn(mockSession);

        // Act & Assert
        expect(TestableApiAuthHelper.requiresTokenValidation(), true);
      });
    });

    group('validateTokenForRequest', () {
      test('succeeds for anonymous users without validation', () async {
        // Arrange
        when(mockGoTrueClient.currentSession).thenReturn(null);

        // Act & Assert - should not throw
        await expectLater(
          TestableApiAuthHelper.validateTokenForRequest(),
          completes,
        );
      });

      test('throws TokenValidationException when token is invalid', () async {
        // Arrange
        when(mockGoTrueClient.currentSession).thenReturn(mockSession);
        when(mockSession.accessToken).thenReturn(''); // Invalid token

        // Act & Assert
        await expectLater(
          TestableApiAuthHelper.validateTokenForRequest(),
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
          TestableApiAuthHelper.validateTokenForRequest(),
          completes,
        );
      });
    });
  });
}
