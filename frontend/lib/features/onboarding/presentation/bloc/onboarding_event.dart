import 'package:equatable/equatable.dart';

/// Base class for all onboarding events
abstract class OnboardingEvent extends Equatable {
  const OnboardingEvent();

  @override
  List<Object?> get props => [];
}

/// Event to load the current onboarding state
class LoadOnboardingState extends OnboardingEvent {
  const LoadOnboardingState();
}

/// Event when user selects a language
class LanguageSelected extends OnboardingEvent {
  final String languageCode;

  const LanguageSelected(this.languageCode);

  @override
  List<Object> get props => [languageCode];
}

/// Event to navigate to the next onboarding step
class NextStep extends OnboardingEvent {
  const NextStep();
}

/// Event to navigate to the previous onboarding step
class PreviousStep extends OnboardingEvent {
  const PreviousStep();
}

/// Event to complete onboarding
class CompleteOnboardingRequested extends OnboardingEvent {
  const CompleteOnboardingRequested();
}

/// Event to reset onboarding (for testing/debugging)
class ResetOnboarding extends OnboardingEvent {
  const ResetOnboarding();
}
