import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'home_event.dart';
import 'home_state.dart';
import 'recommended_topics_bloc.dart';
import 'recommended_topics_event.dart' as topics_events;
import 'recommended_topics_state.dart' as topics_states;
import 'home_study_generation_bloc.dart';
import 'home_study_generation_event.dart' as generation_events;
import 'home_study_generation_state.dart' as generation_states;

/// Refactored BLoC for coordinating Home screen concerns.
///
/// This BLoC now follows the Single Responsibility Principle by delegating
/// specific responsibilities to specialized BLoCs while coordinating their interactions.
class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final RecommendedTopicsBloc _topicsBloc;
  final HomeStudyGenerationBloc _studyGenerationBloc;

  late final StreamSubscription _topicsSubscription;
  late final StreamSubscription _studyGenerationSubscription;

  HomeBloc({
    required RecommendedTopicsBloc topicsBloc,
    required HomeStudyGenerationBloc studyGenerationBloc,
  })  : _topicsBloc = topicsBloc,
        _studyGenerationBloc = studyGenerationBloc,
        super(const HomeCombinedState()) {
    // Subscribe to child BLoC states and trigger events instead of direct emit
    _topicsSubscription = _topicsBloc.stream.listen((state) {
      add(TopicsStateChangedEvent(state));
    });
    _studyGenerationSubscription = _studyGenerationBloc.stream.listen((state) {
      add(StudyGenerationStateChangedEvent(state));
    });

    // Register event handlers
    on<LoadRecommendedTopics>(_onLoadRecommendedTopics);
    on<RefreshRecommendedTopics>(_onRefreshRecommendedTopics);
    on<GenerateStudyGuideFromVerse>(_onGenerateStudyGuideFromVerse);
    on<GenerateStudyGuideFromTopic>(_onGenerateStudyGuideFromTopic);
    on<ClearHomeError>(_onClearHomeError);

    // Register internal coordination events
    on<TopicsStateChangedEvent>(_onTopicsStateChanged);
    on<StudyGenerationStateChangedEvent>(_onStudyGenerationStateChanged);
  }

  /// Handle topics state changes through proper event system
  void _onTopicsStateChanged(
    TopicsStateChangedEvent event,
    Emitter<HomeState> emit,
  ) {
    final topicsState = event.topicsState;
    final currentState = state;
    if (currentState is HomeCombinedState) {
      switch (topicsState) {
        case topics_states.RecommendedTopicsLoading _:
          emit(currentState.copyWith(
            isLoadingTopics: true,
            clearTopicsError: true,
          ));
          break;
        case final topics_states.RecommendedTopicsLoaded loaded:
          emit(currentState.copyWith(
            isLoadingTopics: false,
            topics: loaded.topics,
            clearTopicsError: true,
          ));
          break;
        case final topics_states.RecommendedTopicsError error:
          emit(currentState.copyWith(
            isLoadingTopics: false,
            topicsError: error.message,
          ));
          break;
        default:
          break;
      }
    }
  }

  /// Handle study generation state changes through proper event system
  void _onStudyGenerationStateChanged(
    StudyGenerationStateChangedEvent event,
    Emitter<HomeState> emit,
  ) {
    final generationState = event.generationState;
    final currentState = state;
    if (currentState is HomeCombinedState) {
      switch (generationState) {
        case final generation_states.HomeStudyGenerationInProgress progress:
          emit(currentState.copyWith(
            isGeneratingStudyGuide: true,
            generationInput: progress.input,
            generationInputType: progress.inputType,
            clearGenerationError: true,
          ));
          break;
        case final generation_states.HomeStudyGenerationSuccess success:
          // First, update combined state to stop generating
          emit(currentState.copyWith(
            isGeneratingStudyGuide: false,
            clearGenerationError: true,
          ));
          // Then emit navigation state, but preserve topics by extending HomeCombinedState
          emit(HomeStudyGuideGeneratedCombined(
            studyGuide: success.studyGuide,
            topics: currentState.topics,
            isLoadingTopics: currentState.isLoadingTopics,
            topicsError: currentState.topicsError,
            generationInput: currentState.generationInput,
            generationInputType: currentState.generationInputType,
          ));
          break;
        case final generation_states.HomeStudyGenerationError error:
          emit(currentState.copyWith(
            isGeneratingStudyGuide: false,
            generationError: error.message,
          ));
          break;
        default:
          break;
      }
    }
  }

  /// Handle loading recommended topics by delegating to topics BLoC
  void _onLoadRecommendedTopics(
    LoadRecommendedTopics event,
    Emitter<HomeState> emit,
  ) {
    _topicsBloc.add(topics_events.LoadRecommendedTopics(
      limit: event.limit,
      category: event.category,
      difficulty: event.difficulty,
      forceRefresh: event.forceRefresh,
    ));
  }

  /// Handle refreshing recommended topics by delegating to topics BLoC
  void _onRefreshRecommendedTopics(
    RefreshRecommendedTopics event,
    Emitter<HomeState> emit,
  ) {
    _topicsBloc.add(const topics_events.RefreshRecommendedTopics());
  }

  /// Handle generating study guide from verse by delegating to generation BLoC
  void _onGenerateStudyGuideFromVerse(
    GenerateStudyGuideFromVerse event,
    Emitter<HomeState> emit,
  ) {
    _studyGenerationBloc.add(generation_events.GenerateStudyGuideFromVerse(
      verseReference: event.verseReference,
      language: event.language,
    ));
  }

  /// Handle generating study guide from topic by delegating to generation BLoC
  void _onGenerateStudyGuideFromTopic(
    GenerateStudyGuideFromTopic event,
    Emitter<HomeState> emit,
  ) {
    _studyGenerationBloc.add(generation_events.GenerateStudyGuideFromTopic(
      topicName: event.topicName,
      language: event.language,
    ));
  }

  /// Handle clearing errors by delegating to child BLoCs
  void _onClearHomeError(
    ClearHomeError event,
    Emitter<HomeState> emit,
  ) {
    _topicsBloc.add(const topics_events.ClearRecommendedTopicsError());
    _studyGenerationBloc
        .add(const generation_events.ClearHomeStudyGenerationError());
  }

  @override
  Future<void> close() async {
    // Cancel stream subscriptions first
    await _topicsSubscription.cancel();
    await _studyGenerationSubscription.cancel();

    // Close child BLoCs
    await _topicsBloc.close();
    await _studyGenerationBloc.close();

    // Close parent BLoC
    return super.close();
  }
}
