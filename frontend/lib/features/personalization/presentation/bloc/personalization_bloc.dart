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
    on<SelectFaithJourney>(_onSelectFaithJourney);
    on<ToggleSeeking>(_onToggleSeeking);
    on<SelectTimeCommitment>(_onSelectTimeCommitment);
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

  void _onSelectFaithJourney(
    SelectFaithJourney event,
    Emitter<PersonalizationState> emit,
  ) {
    final currentState = state;
    if (currentState is QuestionnaireInProgress) {
      emit(currentState.copyWith(faithJourney: event.faithJourney));
    } else {
      emit(QuestionnaireInProgress(faithJourney: event.faithJourney));
    }
  }

  void _onToggleSeeking(
    ToggleSeeking event,
    Emitter<PersonalizationState> emit,
  ) {
    final currentState = state;
    if (currentState is QuestionnaireInProgress) {
      final newSeeking = List<String>.from(currentState.seeking);
      if (newSeeking.contains(event.seeking)) {
        newSeeking.remove(event.seeking);
      } else {
        newSeeking.add(event.seeking);
      }
      emit(currentState.copyWith(seeking: newSeeking));
    }
  }

  void _onSelectTimeCommitment(
    SelectTimeCommitment event,
    Emitter<PersonalizationState> emit,
  ) {
    final currentState = state;
    if (currentState is QuestionnaireInProgress) {
      emit(currentState.copyWith(timeCommitment: event.timeCommitment));
    }
  }

  void _onNextQuestion(
    NextQuestion event,
    Emitter<PersonalizationState> emit,
  ) {
    final currentState = state;
    if (currentState is QuestionnaireInProgress) {
      if (currentState.currentQuestion < 2) {
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

  Future<void> _onSubmitQuestionnaire(
    SubmitQuestionnaire event,
    Emitter<PersonalizationState> emit,
  ) async {
    final currentState = state;
    if (currentState is! QuestionnaireInProgress) return;

    emit(const QuestionnaireSubmitting());

    try {
      final personalization = await _repository.savePersonalization(
        faithJourney: currentState.faithJourney,
        seeking: currentState.seeking,
        timeCommitment: currentState.timeCommitment,
      );

      Logger.info(
        'Questionnaire submitted successfully',
        tag: 'PERSONALIZATION',
        context: {
          'faith_journey': currentState.faithJourney,
          'seeking': currentState.seeking,
          'time_commitment': currentState.timeCommitment,
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
