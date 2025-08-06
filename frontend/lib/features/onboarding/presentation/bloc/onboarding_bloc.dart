import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/error_handler.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/entities/onboarding_state_entity.dart';
import '../../domain/usecases/get_onboarding_state.dart';
import '../../domain/usecases/save_language_preference.dart';
import '../../domain/usecases/complete_onboarding.dart';
import 'onboarding_event.dart';
import 'onboarding_state.dart';
import 'onboarding_navigation_handler.dart';

/// BLoC for managing onboarding state and business logic
class OnboardingBloc extends Bloc<OnboardingEvent, OnboardingState> {
  final GetOnboardingState _getOnboardingState;
  final SaveLanguagePreference _saveLanguagePreference;
  final CompleteOnboarding _completeOnboarding;
  final OnboardingNavigationHandler _navigationHandler;

  OnboardingStateEntity? _currentOnboardingState;

  OnboardingBloc({
    required GetOnboardingState getOnboardingState,
    required SaveLanguagePreference saveLanguagePreference,
    required CompleteOnboarding completeOnboarding,
    OnboardingNavigationHandler? navigationHandler,
  })  : _getOnboardingState = getOnboardingState,
        _saveLanguagePreference = saveLanguagePreference,
        _completeOnboarding = completeOnboarding,
        _navigationHandler = navigationHandler ?? OnboardingNavigationHandler(),
        super(const OnboardingInitial()) {
    on<LoadOnboardingState>(_onLoadOnboardingState);
    on<LanguageSelected>(_onLanguageSelected);
    on<NextStep>(_onNextStep);
    on<PreviousStep>(_onPreviousStep);
    on<CompleteOnboardingRequested>(_onCompleteOnboardingRequested);
  }

  /// Handle loading onboarding state
  Future<void> _onLoadOnboardingState(
    LoadOnboardingState event,
    Emitter<OnboardingState> emit,
  ) async {
    emit(const OnboardingLoading());

    await ErrorHandler.wrapAsyncOperation(
      operation: () async {
        final onboardingState = await _getOnboardingState();
        _currentOnboardingState = onboardingState;

        Logger.info(
          'Onboarding state loaded successfully',
          tag: 'ONBOARDING',
          context: {
            'language': onboardingState.selectedLanguage,
            'completed': onboardingState.isCompleted,
            'step': onboardingState.currentStep.toString(),
          },
        );

        if (onboardingState.isCompleted) {
          emit(const OnboardingCompleted());
        } else {
          emit(OnboardingLoaded(onboardingState: onboardingState));
        }
      },
      emit: emit,
      createErrorState: (message, errorCode) =>
          OnboardingError(message: message),
      operationName: 'load onboarding state',
    );
  }

  /// Handle language selection
  Future<void> _onLanguageSelected(
    LanguageSelected event,
    Emitter<OnboardingState> emit,
  ) async {
    if (_currentOnboardingState == null) return;

    await ErrorHandler.wrapAsyncOperation(
      operation: () async {
        Logger.info(
          'Language selected',
          tag: 'ONBOARDING',
          context: {'language_code': event.languageCode},
        );

        await _saveLanguagePreference(event.languageCode);

        // Update current state
        _currentOnboardingState = _currentOnboardingState!.copyWith(
          selectedLanguage: event.languageCode,
        );

        emit(OnboardingLoaded(onboardingState: _currentOnboardingState!));
      },
      emit: emit,
      createErrorState: (message, errorCode) =>
          OnboardingError(message: message),
      operationName: 'save language preference',
    );
  }

  /// Handle next step navigation
  Future<void> _onNextStep(
    NextStep event,
    Emitter<OnboardingState> emit,
  ) async {
    if (_currentOnboardingState == null) return;

    // Validate navigation using navigation handler
    final validationError =
        _navigationHandler.validateNextStepNavigation(_currentOnboardingState!);
    if (validationError != null) {
      emit(OnboardingError(message: validationError));
      return;
    }

    // Get next step using navigation handler
    final currentStep = _currentOnboardingState!.currentStep;
    final nextStep = _navigationHandler.getNextStep(_currentOnboardingState!);

    if (nextStep != null) {
      // Log navigation using navigation handler
      _navigationHandler.logNavigation(
        fromStep: currentStep,
        toStep: nextStep,
        direction: 'forward',
      );

      emit(OnboardingNavigating(fromStep: currentStep, toStep: nextStep));

      _currentOnboardingState = _currentOnboardingState!.copyWith(
        currentStep: nextStep,
      );

      if (nextStep == OnboardingStep.completed) {
        add(const CompleteOnboardingRequested());
      } else {
        emit(OnboardingLoaded(onboardingState: _currentOnboardingState!));
      }
    }
  }

  /// Handle previous step navigation
  Future<void> _onPreviousStep(
    PreviousStep event,
    Emitter<OnboardingState> emit,
  ) async {
    if (_currentOnboardingState == null) return;

    final currentStep = _currentOnboardingState!.currentStep;

    // Validate navigation using navigation handler
    final validationError =
        _navigationHandler.validatePreviousStepNavigation(currentStep);
    if (validationError != null) {
      emit(OnboardingError(message: validationError));
      return;
    }

    // Get previous step using navigation handler
    final previousStep = _navigationHandler.getPreviousStep(currentStep);

    if (previousStep != null) {
      // Log navigation using navigation handler
      _navigationHandler.logNavigation(
        fromStep: currentStep,
        toStep: previousStep,
        direction: 'backward',
      );

      emit(OnboardingNavigating(fromStep: currentStep, toStep: previousStep));

      _currentOnboardingState = _currentOnboardingState!.copyWith(
        currentStep: previousStep,
      );

      emit(OnboardingLoaded(onboardingState: _currentOnboardingState!));
    }
  }

  /// Handle onboarding completion
  Future<void> _onCompleteOnboardingRequested(
    CompleteOnboardingRequested event,
    Emitter<OnboardingState> emit,
  ) async {
    await ErrorHandler.wrapAsyncOperation(
      operation: () async {
        Logger.info(
          'Completing onboarding',
          tag: 'ONBOARDING',
          context: {'user_action': 'complete_onboarding'},
        );

        await _completeOnboarding();

        _currentOnboardingState = _currentOnboardingState?.copyWith(
          isCompleted: true,
          currentStep: OnboardingStep.completed,
        );

        emit(const OnboardingCompleted());
      },
      emit: emit,
      createErrorState: (message, errorCode) =>
          OnboardingError(message: message),
      operationName: 'complete onboarding',
    );
  }

  /// Get current onboarding state (for external access)
  OnboardingStateEntity? get currentOnboardingState => _currentOnboardingState;

  /// Get navigation information for the current state
  OnboardingNavigationInfo? get navigationInfo {
    if (_currentOnboardingState == null) return null;

    final currentStep = _currentOnboardingState!.currentStep;
    return OnboardingNavigationInfo(
      currentStep: currentStep,
      currentStepDisplayName:
          _navigationHandler.getStepDisplayName(currentStep),
      stepIndex: _navigationHandler.getStepIndex(currentStep),
      totalSteps: _navigationHandler.totalSteps,
      progressPercentage: _navigationHandler.getProgressPercentage(currentStep),
      canGoNext:
          _navigationHandler.getNextStep(_currentOnboardingState!) != null,
      canGoPrevious: _navigationHandler.getPreviousStep(currentStep) != null,
      nextStepValidationError: _navigationHandler
          .validateNextStepNavigation(_currentOnboardingState!),
    );
  }
}

/// Navigation information for UI components
class OnboardingNavigationInfo {
  final OnboardingStep currentStep;
  final String currentStepDisplayName;
  final int stepIndex;
  final int totalSteps;
  final double progressPercentage;
  final bool canGoNext;
  final bool canGoPrevious;
  final String? nextStepValidationError;

  const OnboardingNavigationInfo({
    required this.currentStep,
    required this.currentStepDisplayName,
    required this.stepIndex,
    required this.totalSteps,
    required this.progressPercentage,
    required this.canGoNext,
    required this.canGoPrevious,
    this.nextStepValidationError,
  });
}
