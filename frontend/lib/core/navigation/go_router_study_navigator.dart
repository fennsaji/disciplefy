import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router/app_routes.dart';
import '../../features/study_generation/domain/entities/study_guide.dart';
import 'study_navigator.dart';

/// GoRouter-based implementation of StudyNavigator.
///
/// This concrete implementation provides navigation functionality using
/// GoRouter for study-related flows in the presentation layer.
class GoRouterStudyNavigator implements StudyNavigator {
  @override
  void navigateToStudyGuide(
    BuildContext context, {
    required StudyGuide studyGuide,
    required StudyNavigationSource source,
  }) {
    context.push(
      '${AppRoutes.studyGuide}?source=${source.name}',
      extra: studyGuide,
    );
  }

  @override
  void navigateToSavedStudyGuide(
    BuildContext context, {
    required Map<String, dynamic> routeData,
  }) {
    context.push(
      '${AppRoutes.studyGuide}?source=${StudyNavigationSource.saved.name}',
      extra: routeData,
    );
  }

  @override
  void navigateBack(
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
        case StudyNavigationSource.studyTopics:
          context.go(AppRoutes.studyTopics);
          break;
      }
    }
  }

  @override
  void navigateToGenerateStudy(BuildContext context) {
    context.go(AppRoutes.generateStudy);
  }

  @override
  void navigateToHome(BuildContext context) {
    context.go(AppRoutes.home);
  }

  @override
  void navigateToSaved(BuildContext context) {
    context.go(AppRoutes.saved);
  }

  @override
  void navigateToLogin(BuildContext context) {
    context.go(AppRoutes.login);
  }

  @override
  void showErrorDialog(
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

  @override
  StudyNavigationSource parseNavigationSource(String? sourceString) {
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
}
