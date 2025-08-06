import '../../domain/entities/onboarding_state_entity.dart';

/// Data model for onboarding state
class OnboardingStateModel extends OnboardingStateEntity {
  const OnboardingStateModel({
    super.selectedLanguage,
    super.isCompleted = false,
    super.currentStep = OnboardingStep.welcome,
  });

  /// Creates model from entity
  factory OnboardingStateModel.fromEntity(OnboardingStateEntity entity) =>
      OnboardingStateModel(
        selectedLanguage: entity.selectedLanguage,
        isCompleted: entity.isCompleted,
        currentStep: entity.currentStep,
      );

  /// Converts model to entity
  OnboardingStateEntity toEntity() => OnboardingStateEntity(
        selectedLanguage: selectedLanguage,
        isCompleted: isCompleted,
        currentStep: currentStep,
      );

  /// Creates a copy with updated fields
  @override
  OnboardingStateModel copyWith({
    String? selectedLanguage,
    bool? isCompleted,
    OnboardingStep? currentStep,
  }) =>
      OnboardingStateModel(
        selectedLanguage: selectedLanguage ?? this.selectedLanguage,
        isCompleted: isCompleted ?? this.isCompleted,
        currentStep: currentStep ?? this.currentStep,
      );
}
