import 'package:equatable/equatable.dart';

/// Domain entity representing the onboarding state
class OnboardingStateEntity extends Equatable {
  /// Selected language code (en, hi, ml)
  final String? selectedLanguage;

  /// Whether onboarding has been completed
  final bool isCompleted;

  /// Current onboarding step
  final OnboardingStep currentStep;

  const OnboardingStateEntity({
    this.selectedLanguage,
    this.isCompleted = false,
    this.currentStep = OnboardingStep.welcome,
  });

  /// Creates a copy with updated fields
  OnboardingStateEntity copyWith({
    String? selectedLanguage,
    bool? isCompleted,
    OnboardingStep? currentStep,
  }) =>
      OnboardingStateEntity(
        selectedLanguage: selectedLanguage ?? this.selectedLanguage,
        isCompleted: isCompleted ?? this.isCompleted,
        currentStep: currentStep ?? this.currentStep,
      );

  @override
  List<Object?> get props => [selectedLanguage, isCompleted, currentStep];
}

/// Enum representing onboarding steps
enum OnboardingStep {
  welcome,
  language,
  purpose,
  completed,
}
