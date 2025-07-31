import 'package:equatable/equatable.dart';

/// States for Feedback BLoC
abstract class FeedbackState extends Equatable {
  const FeedbackState();

  @override
  List<Object?> get props => [];
}

/// Initial state
class FeedbackInitial extends FeedbackState {
  const FeedbackInitial();
}

/// Submitting feedback
class FeedbackSubmitting extends FeedbackState {
  const FeedbackSubmitting();
}

/// Feedback submitted successfully
class FeedbackSubmitSuccess extends FeedbackState {
  final String message;

  const FeedbackSubmitSuccess({
    this.message = 'Thank you for your feedback!',
  });

  @override
  List<Object?> get props => [message];
}

/// Feedback submission failed
class FeedbackSubmitFailure extends FeedbackState {
  final String message;

  const FeedbackSubmitFailure({
    required this.message,
  });

  @override
  List<Object?> get props => [message];
}