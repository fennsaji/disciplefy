import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:disciplefy_bible_study/features/auth/data/services/auth_service.dart';
import 'package:disciplefy_bible_study/features/auth/data/services/authentication_service.dart';
import 'package:disciplefy_bible_study/features/auth/data/services/auth_storage_service.dart';
import 'package:disciplefy_bible_study/features/auth/domain/entities/auth_params.dart';

import 'auth_service_test.mocks.dart';

@GenerateMocks([
  User,
  AuthenticationService,
  AuthStorageService,
])
void main() {
  late AuthService authService;
  late MockAuthenticationService mockAuthService;
  late MockAuthStorageService mockStorageService;
  late MockUser mockUser;

  setUp(() {
    mockAuthService = MockAuthenticationService();
    mockStorageService = MockAuthStorageService();
    mockUser = MockUser();

    // Mock authStateChanges stream for profile sync monitoring
    when(mockAuthService.authStateChanges).thenAnswer((_) => Stream.empty());

    // Mock currentUser for profile sync check
    when(mockAuthService.currentUser).thenReturn(null);

    // Initialize auth service with mocked dependencies
    authService = AuthService(
      authenticationService: mockAuthService,
      storageService: mockStorageService,
    );
  });

  group('AuthService Facade Tests', () {
    test('should delegate currentUser to AuthenticationService', () {
      // Arrange
      when(mockAuthService.currentUser).thenReturn(mockUser);

      // Act
      final result = authService.currentUser;

      // Assert
      expect(result, mockUser);
      verify(mockAuthService.currentUser).called(1);
    });

    test('should delegate isAuthenticated to AuthenticationService', () {
      // Arrange
      when(mockAuthService.isAuthenticated).thenReturn(true);

      // Act
      final result = authService.isAuthenticated;

      // Assert
      expect(result, true);
      verify(mockAuthService.isAuthenticated).called(1);
    });

    test('should delegate isAuthenticatedAsync to AuthenticationService',
        () async {
      // Arrange
      when(mockAuthService.isAuthenticatedAsync())
          .thenAnswer((_) async => true);

      // Act
      final result = await authService.isAuthenticatedAsync();

      // Assert
      expect(result, true);
      verify(mockAuthService.isAuthenticatedAsync()).called(1);
    });

    test('should delegate signInWithGoogle to AuthenticationService', () async {
      // Arrange
      when(mockAuthService.signInWithGoogle()).thenAnswer((_) async => true);

      // Act
      final result = await authService.signInWithGoogle();

      // Assert
      expect(result, true);
      verify(mockAuthService.signInWithGoogle()).called(1);
    });

    test('should delegate processGoogleOAuthCallback to AuthenticationService',
        () async {
      // Arrange
      const params = GoogleOAuthCallbackParams(code: 'test_code');
      when(mockAuthService.processGoogleOAuthCallback(params))
          .thenAnswer((_) async => true);

      // Act
      final result = await authService.processGoogleOAuthCallback(params);

      // Assert
      expect(result, true);
      verify(mockAuthService.processGoogleOAuthCallback(params)).called(1);
    });

    test('should delegate signInWithApple to AuthenticationService', () async {
      // Arrange
      when(mockAuthService.signInWithApple()).thenAnswer((_) async => true);

      // Act
      final result = await authService.signInWithApple();

      // Assert
      expect(result, true);
      verify(mockAuthService.signInWithApple()).called(1);
    });

    test('should delegate signInAnonymously to AuthenticationService',
        () async {
      // Arrange
      when(mockAuthService.signInAnonymously()).thenAnswer((_) async => true);

      // Act
      final result = await authService.signInAnonymously();

      // Assert
      expect(result, true);
      verify(mockAuthService.signInAnonymously()).called(1);
    });

    test('should delegate signOut to AuthenticationService', () async {
      // Arrange
      when(mockAuthService.signOut()).thenAnswer((_) async {});

      // Act
      await authService.signOut();

      // Assert
      verify(mockAuthService.signOut()).called(1);
    });

    test('should delegate deleteAccount to AuthenticationService', () async {
      // Arrange
      when(mockAuthService.deleteAccount()).thenAnswer((_) async {});

      // Act
      await authService.deleteAccount();

      // Assert
      verify(mockAuthService.deleteAccount()).called(1);
    });

    test('should delegate createAnonymousUser to AuthenticationService', () {
      // Arrange
      when(mockAuthService.createAnonymousUser()).thenReturn(mockUser);

      // Act
      final result = authService.createAnonymousUser();

      // Assert
      expect(result, mockUser);
      verify(mockAuthService.createAnonymousUser()).called(1);
    });
  });

  group('Storage Facade Tests', () {
    test('should delegate getUserType to AuthStorageService', () async {
      // Arrange
      when(mockStorageService.getUserType()).thenAnswer((_) async => 'google');

      // Act
      final result = await authService.getUserType();

      // Assert
      expect(result, 'google');
      verify(mockStorageService.getUserType()).called(1);
    });

    test('should delegate getUserId to AuthStorageService', () async {
      // Arrange
      when(mockStorageService.getUserId()).thenAnswer((_) async => 'user123');

      // Act
      final result = await authService.getUserId();

      // Assert
      expect(result, 'user123');
      verify(mockStorageService.getUserId()).called(1);
    });

    test('should delegate isOnboardingCompleted to AuthStorageService',
        () async {
      // Arrange
      when(mockStorageService.isOnboardingCompleted())
          .thenAnswer((_) async => true);

      // Act
      final result = await authService.isOnboardingCompleted();

      // Assert
      expect(result, true);
      verify(mockStorageService.isOnboardingCompleted()).called(1);
    });

    test('should delegate storeAuthData to AuthStorageService', () async {
      // Arrange
      const params = AuthDataStorageParams(
        accessToken: 'token123',
        userType: 'google',
        userId: 'user123',
      );
      when(mockStorageService.storeAuthData(params)).thenAnswer((_) async {});

      // Act
      await authService.storeAuthData(params);

      // Assert
      verify(mockStorageService.storeAuthData(params)).called(1);
    });

    test('should delegate clearAllData to AuthStorageService', () async {
      // Arrange
      when(mockStorageService.clearAllData()).thenAnswer((_) async {});

      // Act
      await authService.clearAllData();

      // Assert
      verify(mockStorageService.clearAllData()).called(1);
    });
  });

  group('Disposal Tests', () {
    test('should delegate dispose to AuthenticationService', () {
      // Act
      authService.dispose();

      // Assert
      verify(mockAuthService.dispose()).called(1);
    });
  });
}
