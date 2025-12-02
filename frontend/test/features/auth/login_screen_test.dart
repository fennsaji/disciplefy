import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:go_router/go_router.dart';

import 'package:disciplefy_bible_study/features/auth/presentation/pages/login_screen.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/bloc/auth_event.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/bloc/auth_state.dart'
    as auth_states;
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'login_screen_test.mocks.dart';
import '../../../test/helpers/mock_translation_provider.dart';

@GenerateMocks([GoRouter, AuthBloc, User, TranslationService])
void main() {
  late MockAuthBloc mockAuthBloc;
  late MockTranslationService mockTranslationService;

  setUpAll(() {
    // Register mock translation service
    mockTranslationService = MockTranslationService();
    sl.registerLazySingleton<TranslationService>(() => mockTranslationService);
  });

  setUp(() {
    mockAuthBloc = MockAuthBloc();

    // Setup mock translation responses
    when(mockTranslationService.getTranslation(any, any)).thenAnswer(
      (invocation) {
        final key = invocation.positionalArguments[0] as String;
        // Return the key as the translation for simplicity in tests
        return _getMockTranslation(key);
      },
    );
  });

  tearDownAll(() {
    sl.reset();
  });

  Widget createTestWidget() => MockTranslationProvider(
        child: MaterialApp(
          theme: ThemeData(
            primarySwatch: Colors.blue,
            colorScheme: ColorScheme.fromSeed(seedColor: AppTheme.primaryColor),
          ),
          home: Scaffold(
            body: BlocProvider<AuthBloc>(
              create: (context) => mockAuthBloc,
              child: const LoginScreen(),
            ),
          ),
        ),
      );

  group('LoginScreen Widget Tests', () {
    testWidgets('should display welcome text and sign-in buttons',
        (tester) async {
      // Arrange
      when(mockAuthBloc.state)
          .thenReturn(const auth_states.UnauthenticatedState());
      when(mockAuthBloc.stream).thenAnswer(
          (_) => Stream.value(const auth_states.UnauthenticatedState()));

      // Act
      await tester.pumpWidget(createTestWidget());
      await tester
          .pump(); // Use pump() instead of pumpAndSettle() to avoid timeout with loading indicator

      // Assert
      expect(find.text('Welcome to Disciplefy'), findsOneWidget);
      expect(find.text('Deepen your faith through guided Bible study'),
          findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Continue as Guest'), findsOneWidget);
    });

    testWidgets('should show loading state when authentication is in progress',
        (tester) async {
      // Arrange
      when(mockAuthBloc.state).thenReturn(const auth_states.AuthLoadingState());
      when(mockAuthBloc.stream).thenAnswer(
          (_) => Stream.value(const auth_states.AuthLoadingState()));

      // Act
      await tester.pumpWidget(createTestWidget());
      await tester
          .pump(); // Use pump() instead of pumpAndSettle() to avoid timeout with loading indicator

      // Assert
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Both OutlinedButtons (Email and Guest) should be disabled during loading
      final outlinedButtons = find.byType(OutlinedButton);
      expect(outlinedButtons, findsNWidgets(2)); // Email and Guest buttons

      // Verify all OutlinedButtons are disabled during loading
      for (final element in outlinedButtons.evaluate()) {
        final button = element.widget as OutlinedButton;
        expect(button.onPressed, isNull,
            reason: 'OutlinedButton should be disabled during loading');
      }

      // Google button uses InkWell - verify it exists but doesn't show the text
      // (shows loading indicator instead)
      expect(find.text('Continue with Google'), findsNothing);
    });

    testWidgets('should trigger Google sign-in when Google button is tapped',
        (tester) async {
      // Arrange
      when(mockAuthBloc.state)
          .thenReturn(const auth_states.UnauthenticatedState());
      when(mockAuthBloc.stream).thenAnswer(
          (_) => Stream.value(const auth_states.UnauthenticatedState()));

      // Set a larger test surface to avoid tap-outside-bounds issues
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      // Act
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue with Google'));
      await tester.pump();

      // Assert
      verify(mockAuthBloc.add(const GoogleSignInRequested())).called(1);
    });

    testWidgets('should trigger anonymous sign-in when Guest button is tapped',
        (tester) async {
      // Arrange
      when(mockAuthBloc.state)
          .thenReturn(const auth_states.UnauthenticatedState());
      when(mockAuthBloc.stream).thenAnswer(
          (_) => Stream.value(const auth_states.UnauthenticatedState()));

      // Set a larger test surface to avoid tap-outside-bounds issues
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      // Act
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle(); // Wait for layout to settle
      await tester.tap(find.text('Continue as Guest'));
      await tester.pump();

      // Assert
      verify(mockAuthBloc.add(const AnonymousSignInRequested())).called(1);
    });

    testWidgets('should show error snackbar when authentication fails',
        (tester) async {
      // Arrange
      const String errorMessage = 'Authentication failed';
      when(mockAuthBloc.state)
          .thenReturn(const auth_states.UnauthenticatedState());
      when(mockAuthBloc.stream).thenAnswer((_) => Stream.fromIterable([
            const auth_states.UnauthenticatedState(),
            const auth_states.AuthErrorState(message: errorMessage),
          ]));

      // Act
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle(); // Wait for localization
      await tester.pump(); // Trigger the stream emission

      // Assert
      expect(find.text(errorMessage), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('should show neutral snackbar when authentication is canceled',
        (tester) async {
      // Arrange
      const String cancelMessage = 'Google login canceled';
      when(mockAuthBloc.state)
          .thenReturn(const auth_states.UnauthenticatedState());
      when(mockAuthBloc.stream).thenAnswer((_) => Stream.fromIterable([
            const auth_states.UnauthenticatedState(),
            const auth_states.AuthErrorState(message: cancelMessage),
          ]));

      // Act
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle(); // Wait for localization
      await tester.pump(); // Trigger the stream emission

      // Assert
      expect(find.text(cancelMessage), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('should navigate to home when authentication succeeds',
        (tester) async {
      // Arrange
      final mockUser = MockUser();
      when(mockUser.id).thenReturn('test-user-id');
      when(mockUser.email).thenReturn('test@example.com');
      when(mockUser.phone).thenReturn(null);

      when(mockAuthBloc.state)
          .thenReturn(const auth_states.UnauthenticatedState());
      when(mockAuthBloc.stream).thenAnswer((_) => Stream.fromIterable([
            const auth_states.UnauthenticatedState(),
            auth_states.AuthenticatedState(
              user: mockUser as User,
              isAnonymous: false,
            ),
          ]));

      // Create a test widget with GoRouter
      final testWidget = MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/login',
          routes: [
            GoRoute(
              path: '/login',
              builder: (context, state) => BlocProvider<AuthBloc>(
                create: (context) => mockAuthBloc,
                child: const LoginScreen(),
              ),
            ),
            GoRoute(
              path: '/',
              builder: (context, state) => const Scaffold(
                body: Text('Home Screen'),
              ),
            ),
          ],
        ),
      );

      // Act
      await tester.pumpWidget(testWidget);
      await tester.pump(); // Trigger the stream emission
      await tester.pumpAndSettle(); // Wait for navigation and animations

      // Assert
      expect(find.text('Home Screen'), findsOneWidget);
    });

    testWidgets('should display Google logo in Google sign-in button',
        (tester) async {
      // Arrange
      when(mockAuthBloc.state)
          .thenReturn(const auth_states.UnauthenticatedState());
      when(mockAuthBloc.stream).thenAnswer(
          (_) => Stream.value(const auth_states.UnauthenticatedState()));

      // Act
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(Container), findsWidgets);

      // Find the Google button - it uses InkWell with a Row inside
      final googleButtonRow = find.descendant(
        of: find.byType(InkWell),
        matching: find.byType(Row),
      );

      // There should be at least one Row inside an InkWell (the Google button)
      expect(googleButtonRow, findsWidgets);

      // Verify the Google button text exists
      expect(find.text('Continue with Google'), findsOneWidget);
    });

    testWidgets('should display privacy policy text', (tester) async {
      // Arrange
      when(mockAuthBloc.state)
          .thenReturn(const auth_states.UnauthenticatedState());
      when(mockAuthBloc.stream).thenAnswer(
          (_) => Stream.value(const auth_states.UnauthenticatedState()));

      // Act
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Assert
      expect(
        find.text(
            'By continuing, you agree to our Terms of Service and Privacy Policy'),
        findsOneWidget,
      );
    });

    testWidgets('should display app logo', (tester) async {
      // Arrange
      when(mockAuthBloc.state)
          .thenReturn(const auth_states.UnauthenticatedState());
      when(mockAuthBloc.stream).thenAnswer(
          (_) => Stream.value(const auth_states.UnauthenticatedState()));

      // Act
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Assert - Check for logo image or fallback icon
      final logoFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/images/logo_transparent.png',
      );
      final fallbackIconFinder = find.byIcon(Icons.auto_stories);

      // Expect either the logo image or the fallback icon to be present
      expect(
        logoFinder.evaluate().isNotEmpty ||
            fallbackIconFinder.evaluate().isNotEmpty,
        isTrue,
      );
    });
  });

  group('LoginScreen Error Handling Tests', () {
    testWidgets('should handle rate limit error appropriately', (tester) async {
      // Arrange
      const String rateLimitMessage =
          'Too many login attempts. Please try again later.';
      when(mockAuthBloc.state)
          .thenReturn(const auth_states.UnauthenticatedState());
      when(mockAuthBloc.stream).thenAnswer((_) => Stream.fromIterable([
            const auth_states.UnauthenticatedState(),
            const auth_states.AuthErrorState(message: rateLimitMessage),
          ]));

      // Act
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();
      await tester.pump();

      // Assert
      expect(find.text(rateLimitMessage), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('should handle CSRF validation error appropriately',
        (tester) async {
      // Arrange
      const String csrfMessage =
          'Security validation failed. Please try again.';
      when(mockAuthBloc.state)
          .thenReturn(const auth_states.UnauthenticatedState());
      when(mockAuthBloc.stream).thenAnswer((_) => Stream.fromIterable([
            const auth_states.UnauthenticatedState(),
            const auth_states.AuthErrorState(message: csrfMessage),
          ]));

      // Act
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();
      await tester.pump();

      // Assert
      expect(find.text(csrfMessage), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('should handle network error appropriately', (tester) async {
      // Arrange
      const String networkMessage =
          'Network error. Please check your connection';
      when(mockAuthBloc.state)
          .thenReturn(const auth_states.UnauthenticatedState());
      when(mockAuthBloc.stream).thenAnswer((_) => Stream.fromIterable([
            const auth_states.UnauthenticatedState(),
            const auth_states.AuthErrorState(message: networkMessage),
          ]));

      // Act
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();
      await tester.pump();

      // Assert
      expect(find.text(networkMessage), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });
}

/// Mock translation helper that returns English text for translation keys
String _getMockTranslation(String key) {
  // Map of translation keys to their English values
  const translations = {
    'login.welcome': 'Welcome to Disciplefy',
    'login.subtitle': 'Deepen your faith through guided Bible study',
    'login.continue_with_google': 'Continue with Google',
    'login.continue_as_guest': 'Continue as Guest',
    'login.privacy_policy':
        'By continuing, you agree to our Terms of Service and Privacy Policy',
    'login.features.title': 'What you\'ll get:',
    'login.features.ai_study_guides': 'AI-Powered Study Guides',
    'login.features.ai_study_guides_subtitle':
        'Get personalized Bible study insights',
    'login.features.structured_learning': 'Structured Learning',
    'login.features.structured_learning_subtitle':
        'Follow proven study methodologies',
    'login.features.multi_language': 'Multi-Language Support',
    'login.features.multi_language_subtitle':
        'Study in your preferred language',
  };

  return translations[key] ?? key;
}
