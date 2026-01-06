import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/logger.dart';
import '../../domain/entities/personalization_entity.dart';
import '../../domain/repositories/personalization_repository.dart';
import '../../data/repositories/personalization_repository_impl.dart';
import 'personalization_event.dart';
import 'personalization_state.dart';

/// BLoC for managing personalization questionnaire
class PersonalizationBloc
    extends Bloc<PersonalizationEvent, PersonalizationState> {
  final PersonalizationRepository _repository;

  PersonalizationBloc({PersonalizationRepository? repository})
      : _repository = repository ?? PersonalizationRepositoryImpl(),
        super(const PersonalizationInitial()) {
    on<LoadPersonalization>(_onLoadPersonalization);
    on<SelectFaithStage>(_onSelectFaithStage);
    on<ToggleSpiritualGoal>(_onToggleSpiritualGoal);
    on<SelectTimeAvailability>(_onSelectTimeAvailability);
    on<SelectLearningStyle>(_onSelectLearningStyle);
    on<SelectLifeStageFocus>(_onSelectLifeStageFocus);
    on<SelectBiggestChallenge>(_onSelectBiggestChallenge);
    on<NextQuestion>(_onNextQuestion);
    on<PreviousQuestion>(_onPreviousQuestion);
    on<SubmitQuestionnaire>(_onSubmitQuestionnaire);
    on<SkipQuestionnaire>(_onSkipQuestionnaire);
  }

  Future<void> _onLoadPersonalization(
    LoadPersonalization event,
    Emitter<PersonalizationState> emit,
  ) async {
    emit(const PersonalizationLoading());

    try {
      final personalization = await _repository.getPersonalization();

      if (personalization.questionnaireCompleted ||
          personalization.questionnaireSkipped) {
        emit(PersonalizationComplete(personalization));
      } else {
        emit(const PersonalizationNeedsQuestionnaire());
      }
    } catch (e) {
      Logger.error('Failed to load personalization',
          tag: 'PERSONALIZATION', error: e);
      // On error, skip personalization prompt (graceful degradation)
      // This allows the app to continue without blocking the user
      emit(const PersonalizationSkipped());
    }
  }

  // =========================================================================
  // Question 1: Faith Stage
  // =========================================================================

  void _onSelectFaithStage(
    SelectFaithStage event,
    Emitter<PersonalizationState> emit,
  ) {
    final currentState = state;
    if (currentState is QuestionnaireInProgress) {
      emit(currentState.copyWith(faithStage: event.faithStage));
    } else {
      emit(QuestionnaireInProgress(faithStage: event.faithStage));
    }
  }

  // =========================================================================
  // Question 2: Spiritual Goals (Multi-select, max 3)
  // =========================================================================

  void _onToggleSpiritualGoal(
    ToggleSpiritualGoal event,
    Emitter<PersonalizationState> emit,
  ) {
    final currentState = state;
    if (currentState is QuestionnaireInProgress) {
      final newGoals = List<SpiritualGoal>.from(currentState.spiritualGoals);
      if (newGoals.contains(event.goal)) {
        newGoals.remove(event.goal);
      } else {
        // Only add if less than 3 already selected
        if (newGoals.length < 3) {
          newGoals.add(event.goal);
        }
      }
      emit(currentState.copyWith(spiritualGoals: newGoals));
    }
  }

  // =========================================================================
  // Question 3: Time Availability
  // =========================================================================

  void _onSelectTimeAvailability(
    SelectTimeAvailability event,
    Emitter<PersonalizationState> emit,
  ) {
    final currentState = state;
    if (currentState is QuestionnaireInProgress) {
      emit(currentState.copyWith(timeAvailability: event.timeAvailability));
    }
  }

  // =========================================================================
  // Question 4: Learning Style
  // =========================================================================

  void _onSelectLearningStyle(
    SelectLearningStyle event,
    Emitter<PersonalizationState> emit,
  ) {
    final currentState = state;
    if (currentState is QuestionnaireInProgress) {
      emit(currentState.copyWith(learningStyle: event.learningStyle));
    }
  }

  // =========================================================================
  // Question 5: Life Stage Focus
  // =========================================================================

  void _onSelectLifeStageFocus(
    SelectLifeStageFocus event,
    Emitter<PersonalizationState> emit,
  ) {
    final currentState = state;
    if (currentState is QuestionnaireInProgress) {
      emit(currentState.copyWith(lifeStageFocus: event.lifeStageFocus));
    }
  }

  // =========================================================================
  // Question 6: Biggest Challenge
  // =========================================================================

  void _onSelectBiggestChallenge(
    SelectBiggestChallenge event,
    Emitter<PersonalizationState> emit,
  ) {
    final currentState = state;
    if (currentState is QuestionnaireInProgress) {
      emit(currentState.copyWith(biggestChallenge: event.biggestChallenge));
    }
  }

  // =========================================================================
  // Navigation
  // =========================================================================

  void _onNextQuestion(
    NextQuestion event,
    Emitter<PersonalizationState> emit,
  ) {
    final currentState = state;
    if (currentState is QuestionnaireInProgress) {
      if (currentState.currentQuestion < 5) {
        emit(currentState.copyWith(
          currentQuestion: currentState.currentQuestion + 1,
        ));
      }
    } else if (currentState is PersonalizationNeedsQuestionnaire ||
        currentState is PersonalizationInitial) {
      // Start the questionnaire from initial or needs state
      emit(const QuestionnaireInProgress());
    }
  }

  void _onPreviousQuestion(
    PreviousQuestion event,
    Emitter<PersonalizationState> emit,
  ) {
    final currentState = state;
    if (currentState is QuestionnaireInProgress) {
      if (currentState.currentQuestion > 0) {
        emit(currentState.copyWith(
          currentQuestion: currentState.currentQuestion - 1,
        ));
      }
    }
  }

  // =========================================================================
  // Submission
  // =========================================================================

  Future<void> _onSubmitQuestionnaire(
    SubmitQuestionnaire event,
    Emitter<PersonalizationState> emit,
  ) async {
    final currentState = state;
    if (currentState is! QuestionnaireInProgress) return;

    emit(const QuestionnaireSubmitting());

    try {
      final personalization = await _repository.savePersonalization(
        faithStage: currentState.faithStage,
        spiritualGoals: currentState.spiritualGoals,
        timeAvailability: currentState.timeAvailability,
        learningStyle: currentState.learningStyle,
        lifeStageFocus: currentState.lifeStageFocus,
        biggestChallenge: currentState.biggestChallenge,
      );

      Logger.info(
        'Questionnaire submitted successfully (6 questions)',
        tag: 'PERSONALIZATION',
        context: {
          'faith_stage': currentState.faithStage?.value,
          'spiritual_goals':
              currentState.spiritualGoals.map((g) => g.value).toList(),
          'time_availability': currentState.timeAvailability?.value,
          'learning_style': currentState.learningStyle?.value,
          'life_stage_focus': currentState.lifeStageFocus?.value,
          'biggest_challenge': currentState.biggestChallenge?.value,
        },
      );

      emit(QuestionnaireSubmitted(personalization));
    } catch (e) {
      Logger.error('Failed to submit questionnaire',
          tag: 'PERSONALIZATION', error: e);
      emit(PersonalizationError(e.toString()));
    }
  }

  Future<void> _onSkipQuestionnaire(
    SkipQuestionnaire event,
    Emitter<PersonalizationState> emit,
  ) async {
    emit(const QuestionnaireSubmitting());

    try {
      final personalization = await _repository.skipQuestionnaire();

      Logger.info('Questionnaire skipped', tag: 'PERSONALIZATION');

      emit(PersonalizationComplete(personalization));
    } catch (e) {
      Logger.error('Failed to skip questionnaire',
          tag: 'PERSONALIZATION', error: e);
      // Even on error, let user proceed with empty personalization
      emit(PersonalizationComplete(
          const PersonalizationEntity(questionnaireSkipped: true)));
    }
  }
}
