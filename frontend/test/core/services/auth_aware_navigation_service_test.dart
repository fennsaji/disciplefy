import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:disciplefy_bible_study/core/services/auth_aware_navigation_service.dart';
import 'package:disciplefy_bible_study/core/router/app_routes.dart';

void main() {
  group('AuthAwareNavigationService', () {
    group('navigateAfterAuth', () {
      testWidgets('should navigate to home by default', (tester) async {
        final router = _createTestRouter();
        await tester.pumpWidget(
          MaterialApp.router(
            routerConfig: router,
          ),
        );

        // Wait for initial navigation to complete
        await tester.pumpAndSettle();

        // Get a context that has access to GoRouter
        final context = router.routerDelegate.navigatorKey.currentContext!;

        // Test navigation after auth
        AuthAwareNavigationService.navigateAfterAuth(context);

        // Verify the navigation occurred
        await tester.pumpAndSettle();
        expect(find.text('Home'), findsOneWidget);
      });

      testWidgets('should navigate to custom route when provided',
          (tester) async {
        final router = _createTestRouter();
        await tester.pumpWidget(
          MaterialApp.router(
            routerConfig: router,
          ),
        );

        // Wait for initial navigation to complete
        await tester.pumpAndSettle();

        // Get a context that has access to GoRouter
        final context = router.routerDelegate.navigatorKey.currentContext!;

        // Test navigation to custom route
        AuthAwareNavigationService.navigateAfterAuth(context,
            route: '/settings');

        await tester.pumpAndSettle();
        expect(find.text('Settings'), findsOneWidget);
      });
    });

    group('handleAuthLogout', () {
      testWidgets('should navigate to login screen', (tester) async {
        final router = _createTestRouter(initialLocation: '/');
        await tester.pumpWidget(
          MaterialApp.router(
            routerConfig: router,
          ),
        );

        // Wait for initial navigation to complete
        await tester.pumpAndSettle();

        // Get a context that has access to GoRouter
        final context = router.routerDelegate.navigatorKey.currentContext!;

        // Test logout navigation
        AuthAwareNavigationService.handleAuthLogout(context);

        await tester.pumpAndSettle();
        expect(find.text('Login'), findsOneWidget);
      });
    });

    group('navigateWithContext', () {
      testWidgets('should perform normal navigation', (tester) async {
        final router = _createTestRouter();
        await tester.pumpWidget(
          MaterialApp.router(
            routerConfig: router,
          ),
        );

        // Wait for initial navigation to complete
        await tester.pumpAndSettle();

        // Get a context that has access to GoRouter
        final context = router.routerDelegate.navigatorKey.currentContext!;

        AuthAwareNavigationService.navigateWithContext(
          context,
          '/settings',
        );

        await tester.pumpAndSettle();
        expect(find.text('Settings'), findsOneWidget);
      });

      testWidgets('should perform auth transition navigation', (tester) async {
        final router = _createTestRouter();
        await tester.pumpWidget(
          MaterialApp.router(
            routerConfig: router,
          ),
        );

        // Wait for initial navigation to complete
        await tester.pumpAndSettle();

        // Get a context that has access to GoRouter
        final context = router.routerDelegate.navigatorKey.currentContext!;

        AuthAwareNavigationService.navigateWithContext(
          context,
          '/',
          type: NavigationType.authTransition,
        );

        await tester.pumpAndSettle();
        expect(find.text('Home'), findsOneWidget);
      });
    });

    group('shouldPreventNavigation', () {
      test('should prevent authenticated user from accessing auth routes', () {
        final shouldPrevent =
            AuthAwareNavigationService.shouldPreventNavigation(
          '/',
          AppRoutes.login,
          true, // isAuthenticated
        );

        expect(shouldPrevent, isTrue);
      });

      test(
          'should prevent unauthenticated user from accessing protected routes',
          () {
        final shouldPrevent =
            AuthAwareNavigationService.shouldPreventNavigation(
          AppRoutes.login,
          '/',
          false, // isAuthenticated
        );

        expect(shouldPrevent, isTrue);
      });

      test('should allow authenticated user to access protected routes', () {
        final shouldPrevent =
            AuthAwareNavigationService.shouldPreventNavigation(
          AppRoutes.login,
          '/',
          true, // isAuthenticated
        );

        expect(shouldPrevent, isFalse);
      });

      test('should allow unauthenticated user to access auth routes', () {
        final shouldPrevent =
            AuthAwareNavigationService.shouldPreventNavigation(
          '/',
          AppRoutes.login,
          false, // isAuthenticated
        );

        expect(shouldPrevent, isFalse);
      });
    });

    group('getRedirectRoute', () {
      test('should redirect authenticated user from auth route to home', () {
        final redirectRoute = AuthAwareNavigationService.getRedirectRoute(
          AppRoutes.login,
          true, // isAuthenticated
        );

        expect(redirectRoute, equals(AppRoutes.home));
      });

      test('should redirect unauthenticated user from protected route to login',
          () {
        final redirectRoute = AuthAwareNavigationService.getRedirectRoute(
          '/',
          false, // isAuthenticated
        );

        expect(redirectRoute, equals(AppRoutes.login));
      });

      test('should return null when no redirect is needed', () {
        final redirectRoute = AuthAwareNavigationService.getRedirectRoute(
          '/',
          true, // isAuthenticated
        );

        expect(redirectRoute, isNull);
      });
    });

    group('navigateWithValidation', () {
      testWidgets('should redirect when navigation is prevented',
          (tester) async {
        final router = _createTestRouter(initialLocation: '/');
        await tester.pumpWidget(
          MaterialApp.router(
            routerConfig: router,
          ),
        );

        // Wait for initial navigation to complete
        await tester.pumpAndSettle();

        // Find a context within the actual widget tree that has GoRouterState
        final testContentWidget = find.byType(Scaffold).first;
        final context = tester.element(testContentWidget);

        // Try to navigate to login while authenticated
        final result = await AuthAwareNavigationService.navigateWithValidation(
          context,
          AppRoutes.login,
          isAuthenticated: true,
        );

        await tester.pumpAndSettle();

        // Should return false (navigation prevented) and stay on home
        expect(result, isFalse);
        expect(find.text('Home'), findsOneWidget);
      });

      testWidgets('should allow valid navigation', (tester) async {
        final router = _createTestRouter();
        await tester.pumpWidget(
          MaterialApp.router(
            routerConfig: router,
          ),
        );

        // Wait for initial navigation to complete
        await tester.pumpAndSettle();

        // Find a context within the actual widget tree that has GoRouterState
        final testContentWidget = find.byType(Scaffold).first;
        final context = tester.element(testContentWidget);

        // Navigate to settings while authenticated (valid)
        final result = await AuthAwareNavigationService.navigateWithValidation(
          context,
          '/settings',
          isAuthenticated: true,
        );

        await tester.pumpAndSettle();

        // Should return true (navigation allowed)
        expect(result, isTrue);
        expect(find.text('Settings'), findsOneWidget);
      });
    });

    group('getNavigationAnalytics', () {
      test('should return proper analytics data', () {
        final analytics = AuthAwareNavigationService.getNavigationAnalytics();

        expect(analytics, containsPair('service_version', '1.0.0'));
        expect(analytics, containsPair('platform', isA<String>()));
        expect(
            analytics, containsPair('features_enabled', isA<List<String>>()));
        expect(analytics, containsPair('timestamp', isA<String>()));

        final features = analytics['features_enabled'] as List<String>;
        expect(features, contains('auth_aware_routing'));
        expect(features, contains('stack_management'));
        expect(features, contains('browser_history_control'));
        expect(features, contains('navigation_validation'));
      });
    });

    group('Context Extension Methods', () {
      testWidgets('should provide convenient navigation methods',
          (tester) async {
        final router = _createTestRouter();
        await tester.pumpWidget(
          MaterialApp.router(
            routerConfig: router,
          ),
        );

        // Wait for initial navigation to complete
        await tester.pumpAndSettle();

        // Get a context that has access to GoRouter
        final context = router.routerDelegate.navigatorKey.currentContext!;

        // Test extension method
        context.navigateAfterAuth();

        await tester.pumpAndSettle();
        expect(find.text('Home'), findsOneWidget);
      });

      testWidgets('should handle logout navigation', (tester) async {
        final router = _createTestRouter(initialLocation: '/');
        await tester.pumpWidget(
          MaterialApp.router(
            routerConfig: router,
          ),
        );

        // Wait for initial navigation to complete
        await tester.pumpAndSettle();

        // Get a context that has access to GoRouter
        final context = router.routerDelegate.navigatorKey.currentContext!;

        // Test logout extension method
        context.navigateAfterLogout();

        await tester.pumpAndSettle();
        expect(find.text('Login'), findsOneWidget);
      });

      testWidgets('should handle typed navigation', (tester) async {
        final router = _createTestRouter();
        await tester.pumpWidget(
          MaterialApp.router(
            routerConfig: router,
          ),
        );

        // Wait for initial navigation to complete
        await tester.pumpAndSettle();

        // Get a context that has access to GoRouter
        final context = router.routerDelegate.navigatorKey.currentContext!;

        // Test typed navigation
        context.navigateWithType(
          '/settings',
          type: NavigationType.replace,
        );

        await tester.pumpAndSettle();
        expect(find.text('Settings'), findsOneWidget);
      });

      testWidgets('should handle validated navigation', (tester) async {
        final router = _createTestRouter();
        await tester.pumpWidget(
          MaterialApp.router(
            routerConfig: router,
          ),
        );

        // Wait for initial navigation to complete
        await tester.pumpAndSettle();

        // Find a context within the actual widget tree that has GoRouterState
        final testContentWidget = find.byType(Scaffold).first;
        final context = tester.element(testContentWidget);

        // Test validated navigation
        final result = await context.navigateWithAuthValidation(
          '/settings',
          isAuthenticated: true,
        );

        await tester.pumpAndSettle();
        expect(result, isTrue);
        expect(find.text('Settings'), findsOneWidget);
      });
    });
  });
}

/// Creates a test router for navigation testing
GoRouter _createTestRouter({String initialLocation = '/login'}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Home')),
        ),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Login')),
        ),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Settings')),
        ),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Onboarding')),
        ),
      ),
    ],
  );
}
