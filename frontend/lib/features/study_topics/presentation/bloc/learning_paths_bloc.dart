import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import 'package:disciplefy_bible_study/core/error/account_required.dart';
import 'package:disciplefy_bible_study/core/utils/logger.dart';
import '../../domain/entities/learning_path.dart';
import '../../domain/repositories/learning_paths_repository.dart';
import '../../domain/usecases/reset_learning_progress.dart';
import 'learning_paths_event.dart';
import 'learning_paths_state.dart';
import 'package:disciplefy_bible_study/core/utils/error_message_sanitizer.dart';

/// BLoC for managing learning paths.
///
/// Handles loading, enrolling, and viewing learning paths
/// which are curated collections of topics for structured learning.
class LearningPathsBloc extends Bloc<LearningPathsEvent, LearningPathsState> {
  final LearningPathsRepository _repository;
  final ResetLearningProgress _resetLearningProgress;

  static const _categoryPageSize = 4;
  static const _pathsPerCategory = 3;

  LearningPathsBloc({
    required LearningPathsRepository repository,
    required ResetLearningProgress resetLearningProgress,
  })  : _repository = repository,
        _resetLearningProgress = resetLearningProgress,
        super(const LearningPathsInitial()) {
    on<LoadLearningPaths>(_onLoadLearningPaths);
    on<LoadLearningPathDetails>(_onLoadLearningPathDetails);
    on<EnrollInLearningPath>(_onEnrollInLearningPath);
    on<RefreshLearningPaths>(_onRefreshLearningPaths);
    on<ClearLearningPathsCache>(_onClearCache);
    on<LoadMoreCategories>(_onLoadMoreCategories);
    on<LoadMorePathsForCategory>(_onLoadMorePathsForCategory);
    on<SearchLearningPaths>(_onSearchLearningPaths);
    on<LoadFlatLearningPaths>(_onLoadFlatLearningPaths);
    on<LoadPersonalizedPaths>(_onLoadPersonalizedPaths);
    on<ResetLearningProgressRequested>(_onResetLearningProgress);
  }

  /// Latest personalized paths, held outside the state.
  ///
  /// LoadPersonalizedPaths and LoadLearningPaths are dispatched together on
  /// first open, and the personalized fetch is the lighter of the two, so its
  /// result usually arrives while the state is still LearningPathsLoading.
  /// Emitting only into an existing LearningPathsLoaded therefore dropped it,
  /// and the For You section fell back to featured paths — including ones the
  /// user had already completed — until a manual refresh. Holding the result
  /// here lets whichever request finishes last present both.
  List<LearningPath> _personalizedPaths = const [];

  /// Content language [_personalizedPaths] was fetched for. Personalized paths
  /// are language-specific, so they are only reused for a matching language.
  String? _personalizedLanguage;

  /// The personalized paths to emit alongside a listing in [language].
  List<LearningPath> _personalizedFor(String? language) =>
      _personalizedLanguage == language ? _personalizedPaths : const [];

  /// Content language of the category listing currently in the state, or
  /// null when the state holds no category listing.
  String? _listingLanguage;

  /// Whether the state already shows the category listing in [language].
  bool _isShowingListingIn(String language) =>
      state is LearningPathsLoaded && _listingLanguage == language;

  /// Number of listings fetched from the server so far; see
  /// [LearningPathsLoaded.listingRevision].
  int _listingRevision = 0;

  /// Emits [categoriesResult] as the listing in [language]. [fresh] marks a
  /// listing from the server (as opposed to one painted from the cache).
  void _emitListing(
    LearningPathCategoriesResult categoriesResult,
    String language,
    Emitter<LearningPathsState> emit, {
    bool fresh = true,
  }) {
    if (fresh) _listingRevision++;
    if (!categoriesResult.categories.any((c) => c.paths.isNotEmpty)) {
      _listingLanguage = null;
      emit(const LearningPathsEmpty());
      return;
    }
    final enrolledPaths = categoriesResult.categories
        .expand((c) => c.paths)
        .where((p) => p.isEnrolled)
        .toList();
    _listingLanguage = language;
    // Personalized paths are held on the bloc, so they survive this
    // re-emission whether they arrived before or after the listing.
    emit(LearningPathsLoaded(
      categories: categoriesResult.categories,
      enrolledPaths: enrolledPaths,
      hasMoreCategories: categoriesResult.hasMoreCategories,
      nextCategoryOffset: categoriesResult.nextCategoryOffset,
      personalizedPaths: _personalizedFor(language),
      listingRevision: _listingRevision,
    ));
  }

  /// Paints the cached listing in [language] (no network) when the state
  /// does not already show it. Returns whether a listing is now on screen.
  ///
  /// Never shows a listing in another language: without a cache for
  /// [language] the caller shows its loading state instead.
  Future<bool> _showCachedListing(
    String language,
    Emitter<LearningPathsState> emit,
  ) async {
    if (_isShowingListingIn(language)) return true;
    LearningPathCategoriesResult? cached;
    try {
      cached =
          await _repository.getCachedLearningPathCategories(language: language);
    } catch (e) {
      Logger.debug('[LearningPathsBloc] Cached listing unavailable: $e');
    }
    if (cached == null || !cached.categories.any((c) => c.paths.isNotEmpty)) {
      return false;
    }
    _emitListing(cached, language, emit, fresh: false);
    return true;
  }

  /// Stale-while-revalidate: the cached listing is shown at once and the
  /// fresh one replaces it when it lands. A failed refresh keeps the listing
  /// on screen; the error state is only shown when there is nothing to show.
  Future<void> _onLoadLearningPaths(
    LoadLearningPaths event,
    Emitter<LearningPathsState> emit,
  ) async {
    if (_isShowingListingIn(event.language) && !event.forceRefresh) {
      return;
    }

    final showingListing = await _showCachedListing(event.language, emit);
    if (!showingListing) emit(const LearningPathsLoading());

    final result = await _repository.getLearningPathCategories(
      language: event.language,
      includeEnrolled: event.includeEnrolled,
      forceRefresh: event.forceRefresh,
    );

    result.fold(
      (failure) {
        if (showingListing && _isShowingListingIn(event.language)) {
          Logger.warning(
            'Background refresh of learning paths failed: '
            '${ErrorMessageSanitizer.sanitize(failure)}',
            tag: 'LEARNING_PATHS',
          );
          return;
        }
        _listingLanguage = null;
        emit(LearningPathsError(
            message: ErrorMessageSanitizer.sanitize(failure)));
      },
      (categoriesResult) =>
          _emitListing(categoriesResult, event.language, emit),
    );
  }

  Future<void> _onLoadLearningPathDetails(
    LoadLearningPathDetails event,
    Emitter<LearningPathsState> emit,
  ) async {
    emit(LearningPathDetailLoading(pathId: event.pathId));

    final result = await _repository.getLearningPathDetails(
      pathId: event.pathId,
      language: event.language,
      forceRefresh: event.forceRefresh,
    );

    result.fold(
      (failure) => emit(
          LearningPathsError(message: ErrorMessageSanitizer.sanitize(failure))),
      (pathDetail) => emit(LearningPathDetailLoaded(pathDetail: pathDetail)),
    );
  }

  Future<void> _onEnrollInLearningPath(
    EnrollInLearningPath event,
    Emitter<LearningPathsState> emit,
  ) async {
    emit(LearningPathEnrolling(pathId: event.pathId));

    final result = await _repository.enrollInPath(pathId: event.pathId);

    result.fold(
      (failure) => emit(LearningPathsError(
        message: ErrorMessageSanitizer.sanitize(failure),
        isInitialLoadError: false,
        accountReason: isAccountRequired(failure)
            ? (failure is AccountRequiredFailure ? failure.reason : null) ??
                'other_path'
            : null,
      )),
      (enrollment) => emit(LearningPathEnrolled(enrollment: enrollment)),
    );
  }

  Future<void> _onRefreshLearningPaths(
    RefreshLearningPaths event,
    Emitter<LearningPathsState> emit,
  ) async {
    // A listing in another language (a content-language switch) is never
    // kept on screen: the cached one in the new language replaces it at
    // once, or the loading state does.
    final hadData = await _showCachedListing(event.language, emit);
    if (!hadData) {
      emit(const LearningPathsLoading());
    }

    final result = await _repository.getLearningPathCategories(
      language: event.language,
      forceRefresh: true,
    );

    result.fold(
      (failure) {
        _listingLanguage = null;
        emit(LearningPathsError(
          message: ErrorMessageSanitizer.sanitize(failure),
          isInitialLoadError: !hadData,
        ));
      },
      // Only personalized paths fetched for this same language are carried
      // over; a language switch drops them until the matching
      // LoadPersonalizedPaths (dispatched alongside this refresh) lands.
      (categoriesResult) =>
          _emitListing(categoriesResult, event.language, emit),
    );
  }

  void _onClearCache(
    ClearLearningPathsCache event,
    Emitter<LearningPathsState> emit,
  ) {
    _repository.clearCache();
    _listingLanguage = null;
    emit(const LearningPathsInitial());
  }

  Future<void> _onLoadMoreCategories(
    LoadMoreCategories event,
    Emitter<LearningPathsState> emit,
  ) async {
    final current = state;
    if (current is! LearningPathsLoaded ||
        !current.hasMoreCategories ||
        current.isFetchingMoreCategories) {
      return;
    }

    emit(current.copyWith(isFetchingMoreCategories: true));

    final result = await _repository.getLearningPathCategories(
      language: event.language,
      categoryOffset: current.nextCategoryOffset,
      forceRefresh: true,
    );

    result.fold(
      (failure) => emit(current.copyWith(isFetchingMoreCategories: false)),
      (categoriesResult) {
        final combined = [
          ...current.categories,
          ...categoriesResult.categories,
        ];
        final enrolledPaths =
            combined.expand((c) => c.paths).where((p) => p.isEnrolled).toList();
        emit(LearningPathsLoaded(
          categories: combined,
          enrolledPaths: enrolledPaths,
          hasMoreCategories: categoriesResult.hasMoreCategories,
          nextCategoryOffset: categoriesResult.nextCategoryOffset,
          personalizedPaths: current.personalizedPaths,
          listingRevision: current.listingRevision,
        ));
      },
    );
  }

  Future<void> _onLoadMorePathsForCategory(
    LoadMorePathsForCategory event,
    Emitter<LearningPathsState> emit,
  ) async {
    final current = state;
    if (current is! LearningPathsLoaded) return;

    final catIndex =
        current.categories.indexWhere((c) => c.name == event.category);
    if (catIndex == -1) return;

    final cat = current.categories[catIndex];
    if (!cat.hasMoreInCategory ||
        current.loadingCategories.contains(event.category)) {
      return;
    }

    // Mark category as loading
    emit(current.copyWith(
      loadingCategories: [...current.loadingCategories, event.category],
    ));

    final result = await _repository.getLearningPathsForCategory(
      category: event.category,
      language: event.language,
      offset: cat.nextPathOffset,
    );

    final updated = state;
    if (updated is! LearningPathsLoaded) return;

    result.fold(
      (failure) {
        // Remove loading indicator on failure
        emit(updated.copyWith(
          loadingCategories: updated.loadingCategories
              .where((c) => c != event.category)
              .toList(),
        ));
      },
      (newCatData) {
        final updatedCategories =
            List<LearningPathCategory>.from(updated.categories);
        final idx =
            updatedCategories.indexWhere((c) => c.name == event.category);
        if (idx != -1) {
          final existing = updatedCategories[idx];
          updatedCategories[idx] = existing.copyWith(
            paths: [...existing.paths, ...newCatData.paths],
            hasMoreInCategory: newCatData.hasMoreInCategory,
            nextPathOffset: newCatData.nextPathOffset,
          );
        }
        final enrolledPaths = updatedCategories
            .expand((c) => c.paths)
            .where((p) => p.isEnrolled)
            .toList();
        emit(LearningPathsLoaded(
          categories: updatedCategories,
          enrolledPaths: enrolledPaths,
          hasMoreCategories: updated.hasMoreCategories,
          nextCategoryOffset: updated.nextCategoryOffset,
          loadingCategories: updated.loadingCategories
              .where((c) => c != event.category)
              .toList(),
          personalizedPaths: updated.personalizedPaths,
          listingRevision: updated.listingRevision,
        ));
      },
    );
  }

  /// Loads all paths as a flat list (no category grouping, no per-category limit).
  ///
  /// Used by the fellowship picker so that completed paths (sorted last in the
  /// category API) are never cut off by the 3-paths-per-category limit.
  Future<void> _onLoadFlatLearningPaths(
    LoadFlatLearningPaths event,
    Emitter<LearningPathsState> emit,
  ) async {
    final current = state;
    if (current is LearningPathsLoaded) {
      emit(current.copyWith(isSearching: true, searchQuery: ''));
    } else {
      emit(const LearningPathsLoading());
    }

    final result = await _repository.getLearningPaths(
      language: event.language,
      limit: 100,
      forceRefresh: true,
      fellowshipId: event.fellowshipId,
    );

    // The flat list replaces the category listing in the state.
    _listingLanguage = null;
    result.fold(
      (failure) => emit(
          LearningPathsError(message: ErrorMessageSanitizer.sanitize(failure))),
      (data) => emit(LearningPathsLoaded(
        categories: const [],
        searchResults: data.paths,
        searchQuery: '',
      )),
    );
  }

  /// Fetches personalized paths and stores them in the current loaded state.
  ///
  /// Fires-and-forgets if the BLoC is not yet in [LearningPathsLoaded].
  /// The For You section will pick up the update on the next rebuild.
  Future<void> _onLoadPersonalizedPaths(
    LoadPersonalizedPaths event,
    Emitter<LearningPathsState> emit,
  ) async {
    final result = await _repository.getPersonalizedPaths(
      language: event.language,
      limit: event.limit,
      forceRefresh: event.forceRefresh,
    );

    result.fold(
      (_) => null, // Personalization is supplementary — never block the UI
      (paths) {
        _personalizedPaths = paths;
        _personalizedLanguage = event.language;
        final current = state;
        if (current is LearningPathsLoaded) {
          emit(current.copyWith(personalizedPaths: paths));
        }
        // Otherwise the listing is still loading; its emit picks these up.
      },
    );
  }

  /// Handles search queries.
  ///
  /// When [event.query] is empty, clears search state and returns to the
  /// normal category listing. Otherwise, fetches matching paths from the
  /// server (bypassing cache) using the user's content language and emits
  /// results into [LearningPathsLoaded.searchResults].
  Future<void> _onSearchLearningPaths(
    SearchLearningPaths event,
    Emitter<LearningPathsState> emit,
  ) async {
    final current = state;

    // Empty query → restore normal listing
    if (event.query.isEmpty) {
      if (current is LearningPathsLoaded) {
        emit(current.copyWith(clearSearch: true));
      }
      return;
    }

    // Keep the existing categories visible while search loads
    if (current is LearningPathsLoaded) {
      emit(current.copyWith(
        searchQuery: event.query,
        isSearching: true,
      ));
    }

    // Search using the user's content language
    final result = await _repository.getLearningPaths(
      language: event.language,
      forceRefresh: true,
      limit: 50,
      search: event.query,
    );

    // A failed search is not an empty search: folding the error into an empty
    // list renders "no paths found" for what was actually a network failure,
    // with no error and no way to retry.
    final searchFailed = result.isLeft();
    final paths = result.fold((_) => <LearningPath>[], (data) => data.paths);

    final afterSearch = state;
    if (afterSearch is LearningPathsLoaded) {
      emit(afterSearch.copyWith(
        searchQuery: event.query,
        searchResults: paths,
        isSearching: false,
        searchFailed: searchFailed,
      ));
    } else {
      // Bloc was reset while we were searching — emit a fresh loaded state
      _listingLanguage = null;
      emit(LearningPathsLoaded(
        categories: const [],
        searchQuery: event.query,
        searchResults: paths,
        searchFailed: searchFailed,
      ));
    }
  }

  Future<void> _onResetLearningProgress(
    ResetLearningProgressRequested event,
    Emitter<LearningPathsState> emit,
  ) async {
    emit(const LearningPathsResetting());

    final result = await _resetLearningProgress();

    result.fold(
      (failure) => emit(LearningPathsResetError(
        message: ErrorMessageSanitizer.sanitize(failure),
        code: failure.code,
        isNetworkError: failure is NetworkFailure,
      )),
      (resetResult) => emit(LearningPathsResetSuccess(result: resetResult)),
    );
  }
}
