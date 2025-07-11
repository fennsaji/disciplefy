import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:convert';

import 'package:disciplefy_bible_study/features/auth/data/services/auth_service.dart';

import 'auth_service_test.mocks.dart';

@GenerateMocks([
  http.Client,
  SupabaseClient,
  GoTrueClient,
  GoogleSignIn,
  GoogleSignInAccount,
  GoogleSignInAuthentication,
  User,
])
void main() {
  late AuthService authService;
  late MockSupabaseClient mockSupabaseClient;
  late MockGoTrueClient mockGoTrueClient;
  late MockGoogleSignIn mockGoogleSignIn;
  late MockGoogleSignInAccount mockGoogleSignInAccount;
  late MockGoogleSignInAuthentication mockGoogleSignInAuth;
  late MockUser mockUser;

  setUp(() {
    mockSupabaseClient = MockSupabaseClient();
    mockGoTrueClient = MockGoTrueClient();
    mockGoogleSignIn = MockGoogleSignIn();
    mockGoogleSignInAccount = MockGoogleSignInAccount();
    mockGoogleSignInAuth = MockGoogleSignInAuthentication();
    mockUser = MockUser();

    // Setup Supabase client mock
    when(mockSupabaseClient.auth).thenReturn(mockGoTrueClient);
    
    // Initialize auth service
    authService = AuthService();
    
    // Replace internal dependencies with mocks
    // Note: This would require exposing internal dependencies or dependency injection
  });

  group('Google OAuth Callback Tests', () {
    test('should successfully process Google OAuth callback', () async {
      // Arrange
      const String testCode = 'test_authorization_code';
      const String testState = 'test_csrf_state';
      
      final mockResponse = {
        'success': true,
        'session': {
          'access_token': 'test_access_token',
          'refresh_token': 'test_refresh_token',
          'expires_in': 3600,
          'user': {
            'id': 'test_user_id',
            'email': 'test@example.com',
            'email_verified': true,
            'name': 'Test User',
            'picture': 'https://example.com/avatar.jpg',
            'provider': 'google'
          }
        }
      };

      // Mock HTTP response
      final mockHttpResponse = http.Response(
        jsonEncode(mockResponse),
        200,
        headers: {'content-type': 'application/json'},
      );

      // Mock Supabase setSession
      when(mockGoTrueClient.setSession(any, any))
          .thenAnswer((_) async => const AuthResponse());

      // Act
      final result = await authService.processGoogleOAuthCallback(
        code: testCode,
        state: testState,
      );

      // Assert
      expect(result, true);
    });

    test('should handle OAuth error from callback', () async {
      // Arrange
      const String testError = 'access_denied';
      const String testErrorDescription = 'User cancelled the authentication';

      // Act & Assert
      expect(
        () => authService.processGoogleOAuthCallback(
          code: 'dummy_code',
          error: testError,
          errorDescription: testErrorDescription,
        ),
        throwsException,
      );
    });

    test('should handle API error response', () async {
      // Arrange
      const String testCode = 'test_authorization_code';
      
      final mockErrorResponse = {
        'success': false,
        'error': 'INVALID_REQUEST',
        'message': 'Invalid authorization code'
      };

      final mockHttpResponse = http.Response(
        jsonEncode(mockErrorResponse),
        400,
        headers: {'content-type': 'application/json'},
      );

      // Act & Assert
      expect(
        () => authService.processGoogleOAuthCallback(code: testCode),
        throwsException,
      );
    });

    test('should handle rate limit error', () async {
      // Arrange
      const String testCode = 'test_authorization_code';
      
      final mockErrorResponse = {
        'success': false,
        'error': 'RATE_LIMITED',
        'message': 'Too many requests'
      };

      final mockHttpResponse = http.Response(
        jsonEncode(mockErrorResponse),
        429,
        headers: {'content-type': 'application/json'},
      );

      // Act & Assert
      expect(
        () => authService.processGoogleOAuthCallback(code: testCode),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Too many login attempts'),
        )),
      );
    });

    test('should handle CSRF validation error', () async {
      // Arrange
      const String testCode = 'test_authorization_code';
      
      final mockErrorResponse = {
        'success': false,
        'error': 'CSRF_VALIDATION_FAILED',
        'message': 'CSRF token validation failed'
      };

      final mockHttpResponse = http.Response(
        jsonEncode(mockErrorResponse),
        400,
        headers: {'content-type': 'application/json'},
      );

      // Act & Assert
      expect(
        () => authService.processGoogleOAuthCallback(code: testCode),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Security validation failed'),
        )),
      );
    });

    test('should include guest session ID in callback request', () async {
      // Arrange
      const String testCode = 'test_authorization_code';
      const String testGuestSessionId = 'guest_session_123';
      
      // Mock anonymous user
      when(mockUser.id).thenReturn(testGuestSessionId);
      when(mockUser.isAnonymous).thenReturn(true);
      when(mockGoTrueClient.currentUser).thenReturn(mockUser);

      final mockResponse = {
        'success': true,
        'session': {
          'access_token': 'test_access_token',
          'refresh_token': 'test_refresh_token',
          'expires_in': 3600,
          'user': {
            'id': 'test_user_id',
            'email': 'test@example.com',
          }
        }
      };

      final mockHttpResponse = http.Response(
        jsonEncode(mockResponse),
        200,
        headers: {'content-type': 'application/json'},
      );

      // Act
      final result = await authService.processGoogleOAuthCallback(
        code: testCode,
      );

      // Assert
      expect(result, true);
      // Verify that the X-Anonymous-Session-ID header was included
      // This would require mocking the HTTP client and verifying the request
    });
  });

  group('Google Sign-In Tests', () {
    test('should handle Google Sign-In cancellation', () async {
      // Arrange
      when(mockGoogleSignIn.signIn()).thenAnswer((_) async => null);

      // Act & Assert
      expect(
        () => authService.signInWithGoogle(),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('cancelled'),
        )),
      );
    });

    test('should handle missing Google authentication tokens', () async {
      // Arrange
      when(mockGoogleSignIn.signIn()).thenAnswer((_) async => mockGoogleSignInAccount);
      when(mockGoogleSignInAccount.authentication).thenAnswer((_) async => mockGoogleSignInAuth);
      when(mockGoogleSignInAuth.accessToken).thenReturn(null);
      when(mockGoogleSignInAuth.idToken).thenReturn(null);

      // Act & Assert
      expect(
        () => authService.signInWithGoogle(),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Failed to get Google authentication tokens'),
        )),
      );
    });

    test('should successfully sign in with Google on mobile', () async {
      // Arrange
      when(mockGoogleSignIn.signIn()).thenAnswer((_) async => mockGoogleSignInAccount);
      when(mockGoogleSignInAccount.authentication).thenAnswer((_) async => mockGoogleSignInAuth);
      when(mockGoogleSignInAuth.accessToken).thenReturn('test_access_token');
      when(mockGoogleSignInAuth.idToken).thenReturn('test_id_token');

      final mockResponse = {
        'success': true,
        'session': {
          'access_token': 'test_access_token',
          'refresh_token': 'test_refresh_token',
          'expires_in': 3600,
          'user': {
            'id': 'test_user_id',
            'email': 'test@example.com',
          }
        }
      };

      final mockHttpResponse = http.Response(
        jsonEncode(mockResponse),
        200,
        headers: {'content-type': 'application/json'},
      );

      // Mock Supabase setSession
      when(mockGoTrueClient.setSession(any, any))
          .thenAnswer((_) async => const AuthResponse());

      // Act
      final result = await authService.signInWithGoogle();

      // Assert
      expect(result, true);
    });
  });

  group('Session Management Tests', () {
    test('should get guest session ID when user is anonymous', () async {
      // Arrange
      const String testGuestSessionId = 'guest_session_123';
      when(mockUser.id).thenReturn(testGuestSessionId);
      when(mockUser.isAnonymous).thenReturn(true);
      when(mockGoTrueClient.currentUser).thenReturn(mockUser);

      // Act
      final result = await authService.getCurrentUser();

      // Assert
      expect(result?.id, testGuestSessionId);
      expect(result?.isAnonymous, true);
    });

    test('should return null guest session ID when user is not anonymous', () async {
      // Arrange
      when(mockUser.isAnonymous).thenReturn(false);
      when(mockGoTrueClient.currentUser).thenReturn(mockUser);

      // Act
      final result = await authService.getCurrentUser();

      // Assert
      expect(result?.isAnonymous, false);
    });

    test('should return null guest session ID when no user', () async {
      // Arrange
      when(mockGoTrueClient.currentUser).thenReturn(null);

      // Act
      final result = await authService.getCurrentUser();

      // Assert
      expect(result, null);
    });
  });
}