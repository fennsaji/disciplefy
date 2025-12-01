import 'package:flutter/material.dart';

import '../../features/study_generation/domain/entities/study_guide.dart';

/// Abstract interface for study navigation operations.
///
/// This interface provides navigation abstraction for study-related flows,
/// allowing presentation layer to handle navigation without coupling to
/// specific navigation implementations.
abstract class StudyNavigator {
  /// Navigates to the study guide screen with proper data passing.
  ///
  /// [context] The build context for navigation
  /// [studyGuide] The study guide to display
  /// [source] The navigation source for proper back navigation
  void navigateToStudyGuide(
    BuildContext context, {
    required StudyGuide studyGuide,
    required StudyNavigationSource source,
  });

  /// Navigates to the study guide screen with saved guide data.
  ///
  /// [context] The build context for navigation
  /// [routeData] The saved guide data from the database
  void navigateToSavedStudyGuide(
    BuildContext context, {
    required Map<String, dynamic> routeData,
  });

  /// Handles back navigation based on the navigation source.
  ///
  /// [context] The build context for navigation
  /// [source] The original navigation source
  void navigateBack(
    BuildContext context, {
    required StudyNavigationSource source,
  });

  /// Navigates to the generate study screen.
  void navigateToGenerateStudy(BuildContext context);

  /// Navigates to the home screen.
  void navigateToHome(BuildContext context);

  /// Navigates to the saved guides screen.
  void navigateToSaved(BuildContext context);

  /// Navigates to the login screen.
  void navigateToLogin(BuildContext context);

  /// Shows an error dialog and optionally navigates to login.
  ///
  /// [context] The build context
  /// [title] The error dialog title
  /// [message] The error message
  /// [requiresLogin] Whether the error requires login
  void showErrorDialog(
    BuildContext context, {
    required String title,
    required String message,
    bool requiresLogin = false,
  });

  /// Parses navigation source from string.
  ///
  /// [sourceString] The source string from query parameters
  /// Returns the corresponding [StudyNavigationSource] or [StudyNavigationSource.saved] as default
  StudyNavigationSource parseNavigationSource(String? sourceString);
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

  /// Navigated from study topics screen.
  studyTopics,

  /// Navigated from continue learning section.
  continueLearning,

  /// Navigated from a learning path detail page.
  learningPath,
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
      case StudyNavigationSource.studyTopics:
        return 'Study Topics';
      case StudyNavigationSource.continueLearning:
        return 'Continue Learning';
      case StudyNavigationSource.learningPath:
        return 'Learning Path';
    }
  }
}
