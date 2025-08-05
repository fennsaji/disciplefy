import 'package:equatable/equatable.dart';
import '../../domain/entities/onboarding_state_entity.dart';

/// Base class for all onboarding states
abstract class OnboardingState extends Equatable {
  const OnboardingState();

  @override
  List<Object?> get props => [];
}

/// Initial state when BLoC is created
class OnboardingInitial extends OnboardingState {
  const OnboardingInitial();
}

/// State when loading onboarding data
class OnboardingLoading extends OnboardingState {
  const OnboardingLoading();
}

/// State when onboarding data is loaded successfully
class OnboardingLoaded extends OnboardingState {
  final OnboardingStateEntity onboardingState;

  const OnboardingLoaded({
    required this.onboardingState,
  });

  @override
  List<Object> get props => [onboardingState];
}

/// State when there's an error in onboarding
class OnboardingError extends OnboardingState {
  final String message;

  const OnboardingError({
    required this.message,
  });

  @override
  List<Object> get props => [message];
}

/// State when onboarding is completed successfully
class OnboardingCompleted extends OnboardingState {
  const OnboardingCompleted();
}

/// State when navigating between onboarding steps
class OnboardingNavigating extends OnboardingState {
  final OnboardingStep fromStep;
  final OnboardingStep toStep;

  const OnboardingNavigating({
    required this.fromStep,
    required this.toStep,
  });

  @override
  List<Object> get props => [fromStep, toStep];
}
