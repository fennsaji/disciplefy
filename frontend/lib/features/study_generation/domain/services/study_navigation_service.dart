import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../entities/study_guide.dart';

/// Domain service for study generation navigation.
///
/// This service provides a centralized, consistent way to handle
/// navigation flows within the study generation feature,
/// eliminating duplicate navigation logic and inconsistent patterns.
class StudyNavigationService {
  /// Navigates to the study guide screen with proper data passing.
  ///
  /// [context] The build context for navigation
  /// [studyGuide] The study guide to display
  /// [source] The navigation source for proper back navigation
  static void navigateToStudyGuide(
    BuildContext context, {
    required StudyGuide studyGuide,
    required StudyNavigationSource source,
  }) {
    context.go(
      '${AppRoutes.studyGuide}?source=${source.name}',
      extra: studyGuide,
    );
  }

  /// Navigates to the study guide screen with saved guide data.
  ///
  /// [context] The build context for navigation
  /// [routeData] The saved guide data from the database
  static void navigateToSavedStudyGuide(
    BuildContext context, {
    required Map<String, dynamic> routeData,
  }) {
    context.go(
      '${AppRoutes.studyGuide}?source=${StudyNavigationSource.saved.name}',
      extra: routeData,
    );
  }

  /// Handles back navigation based on the navigation source.
  ///
  /// [context] The build context for navigation
  /// [source] The original navigation source
  static void navigateBack(
    BuildContext context, {
    required StudyNavigationSource source,
  }) {
    // Use context.pop() to go back in the navigation stack
    // This preserves the navigation history and allows proper back navigation
    if (context.canPop()) {
      context.pop();
    } else {
      // Fallback to specific routes if there's nothing in the stack
      switch (source) {
        case StudyNavigationSource.home:
          context.go(AppRoutes.home);
          break;
        case StudyNavigationSource.generate:
          context.go(AppRoutes.generateStudy);
          break;
        case StudyNavigationSource.saved:
        case StudyNavigationSource.recent:
          context.go(AppRoutes.saved);
          break;
      }
    }
  }

  /// Navigates to the generate study screen.
  static void navigateToGenerateStudy(BuildContext context) {
    context.go(AppRoutes.generateStudy);
  }

  /// Navigates to the home screen.
  static void navigateToHome(BuildContext context) {
    context.go(AppRoutes.home);
  }

  /// Navigates to the saved guides screen.
  static void navigateToSaved(BuildContext context) {
    context.go(AppRoutes.saved);
  }

  /// Navigates to the login screen.
  static void navigateToLogin(BuildContext context) {
    context.go(AppRoutes.login);
  }

  /// Parses navigation source from string.
  ///
  /// [sourceString] The source string from query parameters
  /// Returns the corresponding [StudyNavigationSource] or [StudyNavigationSource.saved] as default
  static StudyNavigationSource parseNavigationSource(String? sourceString) {
    if (sourceString == null) return StudyNavigationSource.saved;

    try {
      return StudyNavigationSource.values.firstWhere(
        (source) => source.name == sourceString,
        orElse: () => StudyNavigationSource.saved,
      );
    } catch (e) {
      return StudyNavigationSource.saved;
    }
  }

  /// Shows an error dialog and optionally navigates to login.
  ///
  /// [context] The build context
  /// [title] The error dialog title
  /// [message] The error message
  /// [requiresLogin] Whether the error requires login
  static void showErrorDialog(
    BuildContext context, {
    required String title,
    required String message,
    bool requiresLogin = false,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
          if (requiresLogin)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                navigateToLogin(context);
              },
              child: const Text('Login'),
            ),
        ],
      ),
    );
  }
}

/// Enum representing different navigation sources for proper back navigation.
enum StudyNavigationSource {
  /// Navigated from home screen.
  home,

  /// Navigated from study generation screen.
  generate,

  /// Navigated from saved guides screen.
  saved,

  /// Navigated from recent guides section.
  recent,
}

/// Extension on StudyNavigationSource for convenience methods.
extension StudyNavigationSourceExtension on StudyNavigationSource {
  /// Returns the display name for the navigation source.
  String get displayName {
    switch (this) {
      case StudyNavigationSource.home:
        return 'Home';
      case StudyNavigationSource.generate:
        return 'Generate Study';
      case StudyNavigationSource.saved:
        return 'Saved Guides';
      case StudyNavigationSource.recent:
        return 'Recent Guides';
    }
  }

  /// Returns the route path for this navigation source.
  String get routePath {
    switch (this) {
      case StudyNavigationSource.home:
        return AppRoutes.home;
      case StudyNavigationSource.generate:
        return AppRoutes.generateStudy;
      case StudyNavigationSource.saved:
      case StudyNavigationSource.recent:
        return AppRoutes.saved;
    }
  }
}
