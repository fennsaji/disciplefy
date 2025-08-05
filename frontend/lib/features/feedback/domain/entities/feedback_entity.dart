import 'package:equatable/equatable.dart';

/// Feedback entity representing user feedback submission
class FeedbackEntity extends Equatable {
  final String? studyGuideId;
  final String? jeffReedSessionId;
  final bool wasHelpful;
  final String? message;
  final String? category;
  final UserContextEntity userContext;

  const FeedbackEntity({
    this.studyGuideId,
    this.jeffReedSessionId,
    required this.wasHelpful,
    this.message,
    this.category,
    required this.userContext,
  });

  @override
  List<Object?> get props => [
        studyGuideId,
        jeffReedSessionId,
        wasHelpful,
        message,
        category,
        userContext,
      ];
}

/// User context entity for feedback submissions
class UserContextEntity extends Equatable {
  final bool isAuthenticated;
  final String? userId;
  final String? sessionId;

  const UserContextEntity({
    required this.isAuthenticated,
    this.userId,
    this.sessionId,
  });

  /// Create user context for authenticated user
  const UserContextEntity.authenticated({
    required String userId,
  })  : isAuthenticated = true,
        userId = userId,
        sessionId = null;

  /// Create user context for anonymous user
  const UserContextEntity.anonymous({
    required String sessionId,
  })  : isAuthenticated = false,
        userId = null,
        sessionId = sessionId;

  @override
  List<Object?> get props => [isAuthenticated, userId, sessionId];
}
