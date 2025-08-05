import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:go_router/go_router.dart';

import 'package:disciplefy_bible_study/features/auth/presentation/pages/login_screen.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/bloc/auth_event.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/bloc/auth_state.dart' as auth_states;
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'login_screen_test.mocks.dart';

@GenerateMocks([GoRouter, AuthBloc, User])
void main() {
  late MockAuthBloc mockAuthBloc;

  setUp(() {
    mockAuthBloc = MockAuthBloc();
  });

  Widget createTestWidget() => MaterialApp(
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
      );

  group('LoginScreen Widget Tests', () {
    testWidgets('should display welcome text and sign-in buttons', (tester) async {
      // Arrange
      when(mockAuthBloc.state).thenReturn(const auth_states.UnauthenticatedState());
      when(mockAuthBloc.stream).thenAnswer((_) => Stream.value(const auth_states.UnauthenticatedState()));

      // Act
      await tester.pumpWidget(createTestWidget());

      // Assert
      expect(find.text('Welcome to Disciplefy'), findsOneWidget);
      expect(find.text('Deepen your faith through guided Bible study'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Continue as Guest'), findsOneWidget);
    });

    testWidgets('should show loading state when authentication is in progress', (tester) async {
      // Arrange
      when(mockAuthBloc.state).thenReturn(const auth_states.AuthLoadingState());
      when(mockAuthBloc.stream).thenAnswer((_) => Stream.value(const auth_states.AuthLoadingState()));

      // Act
      await tester.pumpWidget(createTestWidget());

      // Assert
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Buttons should be disabled during loading
      final googleButton = find.byType(ElevatedButton);
      final guestButton = find.byType(OutlinedButton);

      expect(googleButton, findsOneWidget);
      expect(guestButton, findsOneWidget);

      // Verify buttons are disabled
      final googleButtonWidget = tester.widget<ElevatedButton>(googleButton);
      final guestButtonWidget = tester.widget<OutlinedButton>(guestButton);

      expect(googleButtonWidget.onPressed, isNull);
      expect(guestButtonWidget.onPressed, isNull);
    });

    testWidgets('should trigger Google sign-in when Google button is tapped', (tester) async {
      // Arrange
      when(mockAuthBloc.state).thenReturn(const auth_states.UnauthenticatedState());
      when(mockAuthBloc.stream).thenAnswer((_) => Stream.value(const auth_states.UnauthenticatedState()));

      // Act
      await tester.pumpWidget(createTestWidget());
      await tester.tap(find.text('Continue with Google'));
      await tester.pump();

      // Assert
      verify(mockAuthBloc.add(const GoogleSignInRequested())).called(1);
    });

    testWidgets('should trigger anonymous sign-in when Guest button is tapped', (tester) async {
      // Arrange
      when(mockAuthBloc.state).thenReturn(const auth_states.UnauthenticatedState());
      when(mockAuthBloc.stream).thenAnswer((_) => Stream.value(const auth_states.UnauthenticatedState()));

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

    testWidgets('should show error snackbar when authentication fails', (tester) async {
      // Arrange
      const String errorMessage = 'Authentication failed';
      when(mockAuthBloc.state).thenReturn(const auth_states.UnauthenticatedState());
      when(mockAuthBloc.stream).thenAnswer((_) => Stream.fromIterable([
            const auth_states.UnauthenticatedState(),
            const auth_states.AuthErrorState(message: errorMessage),
          ]));

      // Act
      await tester.pumpWidget(createTestWidget());
      await tester.pump(); // Trigger the stream emission

      // Assert
      expect(find.text(errorMessage), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('should show neutral snackbar when authentication is canceled', (tester) async {
      // Arrange
      const String cancelMessage = 'Google login canceled';
      when(mockAuthBloc.state).thenReturn(const auth_states.UnauthenticatedState());
      when(mockAuthBloc.stream).thenAnswer((_) => Stream.fromIterable([
            const auth_states.UnauthenticatedState(),
            const auth_states.AuthErrorState(message: cancelMessage),
          ]));

      // Act
      await tester.pumpWidget(createTestWidget());
      await tester.pump(); // Trigger the stream emission

      // Assert
      expect(find.text(cancelMessage), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('should navigate to home when authentication succeeds', (tester) async {
      // Arrange
      final mockUser = MockUser();
      when(mockUser.id).thenReturn('test-user-id');
      when(mockUser.email).thenReturn('test@example.com');

      when(mockAuthBloc.state).thenReturn(const auth_states.UnauthenticatedState());
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

    testWidgets('should display Google logo in Google sign-in button', (tester) async {
      // Arrange
      when(mockAuthBloc.state).thenReturn(const auth_states.UnauthenticatedState());
      when(mockAuthBloc.stream).thenAnswer((_) => Stream.value(const auth_states.UnauthenticatedState()));

      // Act
      await tester.pumpWidget(createTestWidget());

      // Assert
      expect(find.byType(Container), findsWidgets);

      // Find the Google button container
      final googleButtonRow = find.descendant(
        of: find.byType(ElevatedButton),
        matching: find.byType(Row),
      );

      expect(googleButtonRow, findsOneWidget);
    });

    testWidgets('should display privacy policy text', (tester) async {
      // Arrange
      when(mockAuthBloc.state).thenReturn(const auth_states.UnauthenticatedState());
      when(mockAuthBloc.stream).thenAnswer((_) => Stream.value(const auth_states.UnauthenticatedState()));

      // Act
      await tester.pumpWidget(createTestWidget());

      // Assert
      expect(
        find.text('By continuing, you agree to our Terms of Service and Privacy Policy'),
        findsOneWidget,
      );
    });

    testWidgets('should display app logo', (tester) async {
      // Arrange
      when(mockAuthBloc.state).thenReturn(const auth_states.UnauthenticatedState());
      when(mockAuthBloc.stream).thenAnswer((_) => Stream.value(const auth_states.UnauthenticatedState()));

      // Act
      await tester.pumpWidget(createTestWidget());

      // Assert
      expect(find.byIcon(Icons.auto_stories), findsOneWidget);
    });
  });

  group('LoginScreen Error Handling Tests', () {
    testWidgets('should handle rate limit error appropriately', (tester) async {
      // Arrange
      const String rateLimitMessage = 'Too many login attempts. Please try again later.';
      when(mockAuthBloc.state).thenReturn(const auth_states.UnauthenticatedState());
      when(mockAuthBloc.stream).thenAnswer((_) => Stream.fromIterable([
            const auth_states.UnauthenticatedState(),
            const auth_states.AuthErrorState(message: rateLimitMessage),
          ]));

      // Act
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      // Assert
      expect(find.text(rateLimitMessage), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('should handle CSRF validation error appropriately', (tester) async {
      // Arrange
      const String csrfMessage = 'Security validation failed. Please try again.';
      when(mockAuthBloc.state).thenReturn(const auth_states.UnauthenticatedState());
      when(mockAuthBloc.stream).thenAnswer((_) => Stream.fromIterable([
            const auth_states.UnauthenticatedState(),
            const auth_states.AuthErrorState(message: csrfMessage),
          ]));

      // Act
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      // Assert
      expect(find.text(csrfMessage), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('should handle network error appropriately', (tester) async {
      // Arrange
      const String networkMessage = 'Network error. Please check your connection';
      when(mockAuthBloc.state).thenReturn(const auth_states.UnauthenticatedState());
      when(mockAuthBloc.stream).thenAnswer((_) => Stream.fromIterable([
            const auth_states.UnauthenticatedState(),
            const auth_states.AuthErrorState(message: networkMessage),
          ]));

      // Act
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      // Assert
      expect(find.text(networkMessage), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });
}
