import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/topic_progress_repository.dart';
import 'continue_learning_event.dart';
import 'continue_learning_state.dart';
import 'package:disciplefy_bible_study/core/utils/error_message_sanitizer.dart';

/// BLoC for managing continue learning section.
///
/// Handles loading in-progress topics that the user has started
/// but not yet completed, enabling them to continue where they left off.
class ContinueLearningBloc
    extends Bloc<ContinueLearningEvent, ContinueLearningState> {
  final TopicProgressRepository _repository;

  ContinueLearningBloc({
    required TopicProgressRepository repository,
  })  : _repository = repository,
        super(const ContinueLearningInitial()) {
    on<LoadContinueLearning>(_onLoadContinueLearning);
    on<RefreshContinueLearning>(_onRefreshContinueLearning);
    on<ClearContinueLearningCache>(_onClearCache);
  }

  /// Content language of the topics in the state, or null when the state
  /// holds none.
  String? _loadedLanguage;

  /// Whether the state already holds a result (topics or "none in progress")
  /// fetched in [language].
  bool _hasResultIn(String language) =>
      (state is ContinueLearningLoaded || state is ContinueLearningEmpty) &&
      _loadedLanguage == language;

  Future<void> _onLoadContinueLearning(
    LoadContinueLearning event,
    Emitter<ContinueLearningState> emit,
  ) async {
    // Don't reload if already loaded (unless force refresh)
    if (state is ContinueLearningLoaded && !event.forceRefresh) {
      return;
    }
    await _fetch(event.language, event.limit, emit);
  }

  Future<void> _onRefreshContinueLearning(
    RefreshContinueLearning event,
    Emitter<ContinueLearningState> emit,
  ) =>
      _fetch(event.language, 5, emit);

  /// Refreshes in the background when the state already holds a result in
  /// [language] (it stays on screen, and a failed refresh keeps it);
  /// otherwise — first load or a language switch — shows the loading state
  /// so topics in another language never linger.
  Future<void> _fetch(
    String language,
    int limit,
    Emitter<ContinueLearningState> emit,
  ) async {
    final hadData = _hasResultIn(language);
    if (!hadData) {
      _loadedLanguage = null;
      emit(const ContinueLearningLoading());
    }

    final result = await _repository.getInProgressTopics(
      language: language,
      limit: limit,
    );

    result.fold(
      (failure) {
        if (hadData && _hasResultIn(language)) return;
        _loadedLanguage = null;
        emit(ContinueLearningError(
          message: ErrorMessageSanitizer.sanitize(failure),
        ));
      },
      (topics) {
        _loadedLanguage = language;
        if (topics.isEmpty) {
          emit(const ContinueLearningEmpty());
        } else {
          emit(ContinueLearningLoaded(topics: topics));
        }
      },
    );
  }

  void _onClearCache(
    ClearContinueLearningCache event,
    Emitter<ContinueLearningState> emit,
  ) {
    _loadedLanguage = null;
    emit(const ContinueLearningInitial());
  }
}
