import 'package:equatable/equatable.dart';
import '../../domain/entities/feedback_entity.dart';

/// Events for Feedback BLoC
abstract class FeedbackEvent extends Equatable {
  const FeedbackEvent();

  @override
  List<Object?> get props => [];
}

/// Submit feedback event
class SubmitFeedbackRequested extends FeedbackEvent {
  final FeedbackEntity feedback;

  const SubmitFeedbackRequested({required this.feedback});

  @override
  List<Object?> get props => [feedback];
}

/// Submit general feedback event (convenience)
class SubmitGeneralFeedbackRequested extends FeedbackEvent {
  final bool wasHelpful;
  final String message;
  final String category;
  final UserContextEntity userContext;

  const SubmitGeneralFeedbackRequested({
    required this.wasHelpful,
    required this.message,
    required this.category,
    required this.userContext,
  });

  @override
  List<Object?> get props => [wasHelpful, message, category, userContext];
}

/// Submit bug report event (convenience)
class SubmitBugReportRequested extends FeedbackEvent {
  final String message;
  final UserContextEntity userContext;

  const SubmitBugReportRequested({
    required this.message,
    required this.userContext,
  });

  @override
  List<Object?> get props => [message, userContext];
}

/// Reset feedback state
class ResetFeedbackState extends FeedbackEvent {
  const ResetFeedbackState();
}