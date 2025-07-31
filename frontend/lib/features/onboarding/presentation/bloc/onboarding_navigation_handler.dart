import '../../../../core/utils/logger.dart';
import '../../domain/entities/onboarding_state_entity.dart';

/// Handler for onboarding navigation logic.
/// 
/// This class centralizes all navigation state transitions and validation
/// following the Single Responsibility Principle.
class OnboardingNavigationHandler {
  /// Determines the next step in the onboarding flow.
  /// 
  /// Returns null if navigation is not possible (e.g., missing requirements).
  OnboardingStep? getNextStep(OnboardingStateEntity currentState) {
    final currentStep = currentState.currentStep;
    
    switch (currentStep) {
      case OnboardingStep.welcome:
        return OnboardingStep.language;
        
      case OnboardingStep.language:
        // Only proceed if language is selected
        if (currentState.selectedLanguage != null) {
          return OnboardingStep.purpose;
        }
        return null; // Cannot proceed without language selection
        
      case OnboardingStep.purpose:
        return OnboardingStep.completed;
        
      case OnboardingStep.completed:
        return null; // Already at the end
    }
  }

  /// Determines the previous step in the onboarding flow.
  /// 
  /// Returns null if we're already at the beginning.
  OnboardingStep? getPreviousStep(OnboardingStep currentStep) {
    switch (currentStep) {
      case OnboardingStep.welcome:
        return null; // Already at the beginning
        
      case OnboardingStep.language:
        return OnboardingStep.welcome;
        
      case OnboardingStep.purpose:
        return OnboardingStep.language;
        
      case OnboardingStep.completed:
        return OnboardingStep.purpose;
    }
  }

  /// Validates if navigation to the next step is allowed.
  /// 
  /// Returns a validation error message if navigation is not allowed,
  /// otherwise returns null.
  String? validateNextStepNavigation(OnboardingStateEntity currentState) {
    final currentStep = currentState.currentStep;
    
    switch (currentStep) {
      case OnboardingStep.language:
        if (currentState.selectedLanguage == null) {
          return 'Please select a language before proceeding';
        }
        break;
        
      case OnboardingStep.completed:
        return 'Onboarding is already completed';
        
      default:
        break;
    }
    
    return null; // Navigation is valid
  }

  /// Validates if navigation to the previous step is allowed.
  /// 
  /// Returns a validation error message if navigation is not allowed,
  /// otherwise returns null.
  String? validatePreviousStepNavigation(OnboardingStep currentStep) {
    if (currentStep == OnboardingStep.welcome) {
      return 'Already at the first step';
    }
    
    return null; // Navigation is valid
  }

  /// Logs navigation events with proper context.
  void logNavigation({
    required OnboardingStep fromStep,
    required OnboardingStep toStep,
    required String direction,
  }) {
    // Use dedicated navigation logging method
    Logger.navigation(
      fromStep.toString(),
      toStep.toString(),
      context: {
        'direction': direction,
        'flow': 'onboarding',
        'from_step_display': getStepDisplayName(fromStep),
        'to_step_display': getStepDisplayName(toStep),
      },
    );
  }

  /// Gets user-friendly step names for display purposes.
  String getStepDisplayName(OnboardingStep step) {
    switch (step) {
      case OnboardingStep.welcome:
        return 'Welcome';
      case OnboardingStep.language:
        return 'Language Selection';
      case OnboardingStep.purpose:
        return 'Purpose Selection';
      case OnboardingStep.completed:
        return 'Completed';
    }
  }

  /// Gets the total number of steps in the onboarding flow.
  int get totalSteps => OnboardingStep.values.length - 1; // Exclude completed

  /// Gets the current step index (0-based) for progress indicators.
  int getStepIndex(OnboardingStep step) {
    switch (step) {
      case OnboardingStep.welcome:
        return 0;
      case OnboardingStep.language:
        return 1;
      case OnboardingStep.purpose:
        return 2;
      case OnboardingStep.completed:
        return 3;
    }
  }

  /// Calculates progress percentage (0.0 to 1.0) for the current step.
  double getProgressPercentage(OnboardingStep step) {
    final stepIndex = getStepIndex(step);
    return stepIndex / totalSteps;
  }
}