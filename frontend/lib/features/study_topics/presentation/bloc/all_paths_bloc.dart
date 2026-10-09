import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:disciplefy_bible_study/core/error/failures.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/learning_path.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/repositories/learning_paths_repository.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/all_paths_event.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/all_paths_state.dart';

export 'all_paths_event.dart';
export 'all_paths_state.dart';

typedef _Page = ({List<LearningPath> paths, bool hasMore, int? total});

/// All paths: the first page shows as soon as it lands and the next pages
/// load as the list nears its end. Categories come from their own light
/// request, a chip lists its category from the server and a search asks the
/// server; nothing waits for the whole catalogue.
///
/// Events run concurrently. Each new list (open, chip, search, language,
/// refresh) bumps a generation, and a response for an older generation is
/// dropped, so the newest request always wins.
class AllPathsBloc extends Bloc<AllPathsEvent, AllPathsState> {
  /// Paths per request.
  static const pageSize = 25;

  final LearningPathsRepository _repository;

  /// Generation of the list on screen; see the class doc.
  int _generation = 0;

  /// Generation of the categories request, for the same reason.
  int _categoriesGeneration = 0;

  AllPathsBloc({required LearningPathsRepository repository})
      : _repository = repository,
        super(const AllPathsState()) {
    on<AllPathsOpened>(_onOpened);
    on<AllPathsLanguageChanged>(_onLanguageChanged);
    on<AllPathsCategorySelected>(_onCategorySelected);
    on<AllPathsSearchChanged>(_onSearchChanged);
    on<AllPathsMoreRequested>(_onMoreRequested);
    on<AllPathsRefreshed>(_onRefreshed);
    on<AllPathsRetried>(_onRetried);
  }

  Future<void> _onOpened(
      AllPathsOpened event, Emitter<AllPathsState> emit) async {
    emit(AllPathsState(language: event.language, category: event.category));
    await Future.wait([
      _loadCategories(emit),
      _loadFirstPage(emit),
    ]);
  }

  Future<void> _onLanguageChanged(
      AllPathsLanguageChanged event, Emitter<AllPathsState> emit) async {
    if (event.language == state.language) return;
    // The old titles are never shown under the new language.
    emit(AllPathsState(
      language: event.language,
      category: state.category,
      query: state.query,
    ));
    await Future.wait([
      _loadCategories(emit),
      _loadFirstPage(emit),
    ]);
  }

  Future<void> _onCategorySelected(
      AllPathsCategorySelected event, Emitter<AllPathsState> emit) async {
    if (event.category == state.category && !state.searching) return;
    emit(state.copyWith(
      category: event.category,
      clearCategory: event.category == null,
      query: '',
    ));
    await _loadFirstPage(emit);
  }

  Future<void> _onSearchChanged(
      AllPathsSearchChanged event, Emitter<AllPathsState> emit) async {
    final query = event.query.trim();
    if (query == state.query) return;
    // A search covers every path, whatever chip was selected.
    emit(state.copyWith(query: query, clearCategory: query.isNotEmpty));
    await _loadFirstPage(emit);
  }

  Future<void> _onRefreshed(
      AllPathsRefreshed event, Emitter<AllPathsState> emit) async {
    try {
      if (state.language == null) return;
      final keep = state.status == AllPathsStatus.loaded;
      await Future.wait([
        _loadCategories(emit),
        _loadFirstPage(emit, keepVisible: keep),
      ]);
    } finally {
      if (!(event.done?.isCompleted ?? true)) event.done!.complete();
    }
  }

  Future<void> _onRetried(
      AllPathsRetried event, Emitter<AllPathsState> emit) async {
    if (state.language == null) return;
    await Future.wait([
      if (state.categories.isEmpty) _loadCategories(emit),
      _loadFirstPage(emit),
    ]);
  }

  Future<void> _onMoreRequested(
      AllPathsMoreRequested event, Emitter<AllPathsState> emit) async {
    final current = state;
    if (current.status != AllPathsStatus.loaded ||
        !current.hasMore ||
        current.loadingMore ||
        current.refreshing ||
        (current.moreFailed && !event.retry)) {
      return;
    }
    final generation = _generation;
    emit(current.copyWith(loadingMore: true, moreFailed: false));

    final result = await _fetch(current, offset: current.nextOffset);
    if (generation != _generation) return;

    result.fold(
      (_) => emit(state.copyWith(loadingMore: false, moreFailed: true)),
      (page) {
        final ids = {for (final p in state.paths) p.id};
        emit(state.copyWith(
          paths: [
            ...state.paths,
            ...page.paths.where((p) => ids.add(p.id)),
          ],
          nextOffset: current.nextOffset + page.paths.length,
          hasMore: page.hasMore && page.paths.isNotEmpty,
          loadingMore: false,
          moreFailed: false,
          listTotal: _allTotalFrom(current, page),
        ));
      },
    );
  }

  /// Lists the first page of the current list. With [keepVisible] the list
  /// stays on screen meanwhile and a failure keeps it; otherwise the list
  /// is cleared and a failure is an error with Retry.
  Future<void> _loadFirstPage(
    Emitter<AllPathsState> emit, {
    bool keepVisible = false,
  }) async {
    final generation = ++_generation;
    if (keepVisible) {
      emit(state.copyWith(refreshing: true));
    } else {
      emit(state.copyWith(
        status: AllPathsStatus.loading,
        paths: const [],
        nextOffset: 0,
        hasMore: false,
        loadingMore: false,
        moreFailed: false,
        refreshing: false,
      ));
    }
    final request = state;

    final result = await _fetch(request, offset: 0);
    if (generation != _generation) return;

    result.fold(
      (_) => emit(keepVisible
          ? state.copyWith(refreshing: false)
          : state.copyWith(status: AllPathsStatus.error, refreshing: false)),
      (page) {
        final ids = <String>{};
        emit(state.copyWith(
          status: AllPathsStatus.loaded,
          paths: [
            for (final p in page.paths)
              if (ids.add(p.id)) p
          ],
          nextOffset: page.paths.length,
          hasMore: page.hasMore && page.paths.isNotEmpty,
          loadingMore: false,
          moreFailed: false,
          refreshing: false,
          listTotal: _allTotalFrom(request, page),
        ));
      },
    );
  }

  Future<void> _loadCategories(Emitter<AllPathsState> emit) async {
    final language = state.language;
    if (language == null) return;
    final generation = ++_categoriesGeneration;
    final result =
        await _repository.getLearningPathCategorySummaries(language: language);
    if (generation != _categoriesGeneration || state.language != language) {
      return;
    }
    // A failure keeps whatever is shown; the page falls back to the
    // categories of the loaded paths.
    result.fold((_) => null, (categories) {
      if (categories.isNotEmpty) emit(state.copyWith(categories: categories));
    });
  }

  /// The catalogue total when [page] is of the unfiltered list and the
  /// server knows it; otherwise the total already known.
  int? _allTotalFrom(AllPathsState request, _Page page) {
    final total = page.total;
    if (request.category != null || request.searching || total == null) {
      return state.listTotal;
    }
    return total;
  }

  Future<Either<Failure, _Page>> _fetch(
    AllPathsState request, {
    required int offset,
  }) async {
    final language = request.language ?? 'en';
    final category = request.category;
    if (category != null && !request.searching) {
      final result = await _repository.getLearningPathsForCategory(
        category: category,
        language: language,
        limit: pageSize,
        offset: offset,
      );
      return result.map((c) => (
            paths: c.paths,
            hasMore: c.hasMoreInCategory,
            total: null,
          ));
    }
    final result = await _repository.getLearningPaths(
      language: language,
      limit: pageSize,
      offset: offset,
      search: request.searching ? request.query : null,
      // Fresh progress; the persisted first page (keyed by page size) is
      // still written for other readers.
      forceRefresh: true,
    );
    return result.map((r) {
      final seen = offset + r.paths.length;
      // The server sends null (parsed as 0) when it does not know the total.
      final known = r.total > 0 && r.total >= seen;
      return (
        paths: r.paths,
        hasMore: r.hasMore,
        total: known ? r.total : (r.hasMore ? null : seen),
      );
    });
  }
}
