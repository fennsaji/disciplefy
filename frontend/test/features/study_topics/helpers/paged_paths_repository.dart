import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:mocktail/mocktail.dart';

import 'package:disciplefy_bible_study/core/error/failures.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/learning_path.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/repositories/learning_paths_repository.dart';

/// A path named "Path {n}" in [category].
LearningPath pagedPath(int n, {String category = 'Foundations'}) =>
    LearningPath(
      id: 'p$n',
      slug: 'p$n',
      title: 'Path $n',
      description: '',
      iconName: 'park',
      color: '#10B981',
      totalXp: 100,
      estimatedDays: 7,
      discipleLevel: 'seeker',
      topicsCount: 5,
      category: category,
    );

/// A repository that pages like the learning-paths Edge Function: the flat
/// list honours limit/offset/search and reports `hasMore`, categories come
/// four to a page with three paths each, and a category pages on its own.
class PagedPathsRepository extends Fake implements LearningPathsRepository {
  PagedPathsRepository(this.paths);

  final List<LearningPath> paths;

  /// Offsets of the flat-list requests, in order.
  final flatOffsets = <int>[];

  /// Search queries of the flat-list requests, in order.
  final searches = <String?>[];

  /// Offsets of the per-category requests, in order.
  final categoryOffsets = <int>[];

  /// Category names of the per-category requests, in order.
  final categoryRequests = <String>[];

  /// Languages of the category-summary requests, in order.
  final summaryRequests = <String>[];

  /// Languages of the flat-list requests, in order.
  final flatLanguages = <String>[];

  /// Page sizes of the flat-list requests, in order.
  final flatLimits = <int>[];

  /// A flat-list request at this offset waits for its completer.
  final flatGates = <int, Completer<void>>{};

  /// Category-summary requests fail.
  bool failSummaries = false;

  /// A flat-list request in this language fails.
  String? failLanguage;

  /// A flat-list request at this offset fails.
  int? failFlatAt;

  /// Per-category requests fail.
  bool failCategoryPages = false;

  /// Delay before a search for the key answers.
  final searchDelays = <String, Duration>{};

  List<String> get _categoryNames =>
      {for (final p in paths) p.category}.toList();

  @override
  Future<Either<Failure, LearningPathsResult>> getLearningPaths({
    String language = 'en',
    bool includeEnrolled = true,
    bool forceRefresh = false,
    int limit = 10,
    int offset = 0,
    String? search,
    String? fellowshipId,
  }) async {
    flatOffsets.add(offset);
    searches.add(search);
    flatLanguages.add(language);
    flatLimits.add(limit);
    final gate = flatGates[offset];
    if (gate != null) await gate.future;
    if (failLanguage == language) {
      return const Left(ServerFailure(message: 'boom'));
    }
    final delay = search == null ? null : searchDelays[search];
    if (delay != null) await Future<void>.delayed(delay);
    if (failFlatAt == offset) {
      return const Left(NetworkFailure(message: 'offline'));
    }
    final matching = search == null
        ? paths
        : paths
            .where((p) => p.title.toLowerCase().contains(search.toLowerCase()))
            .toList();
    final page = matching.skip(offset).take(limit).toList();
    final hasMore = offset + page.length < matching.length;
    return Right(LearningPathsResult(
      paths: page,
      total: matching.length,
      hasMore: hasMore,
    ));
  }

  LearningPathCategory _category(String name, {int offset = 0, int limit = 3}) {
    final all = paths.where((p) => p.category == name).toList();
    final page = all.skip(offset).take(limit).toList();
    return LearningPathCategory(
      name: name,
      paths: page,
      totalInCategory: all.length,
      hasMoreInCategory: offset + page.length < all.length,
      nextPathOffset: offset + page.length,
    );
  }

  @override
  Future<Either<Failure, LearningPathCategoriesResult>>
      getLearningPathCategories({
    String language = 'en',
    bool includeEnrolled = true,
    int categoryLimit = 4,
    int categoryOffset = 0,
    bool forceRefresh = false,
  }) async {
    final names = _categoryNames.skip(categoryOffset).take(categoryLimit);
    final next = categoryOffset + names.length;
    return Right(LearningPathCategoriesResult(
      categories: [for (final n in names) _category(n)],
      hasMoreCategories: next < _categoryNames.length,
      nextCategoryOffset: next,
    ));
  }

  @override
  Future<Either<Failure, LearningPathCategory>> getLearningPathsForCategory({
    required String category,
    String language = 'en',
    int limit = 3,
    int offset = 0,
  }) async {
    categoryOffsets.add(offset);
    categoryRequests.add(category);
    if (failCategoryPages) {
      return const Left(NetworkFailure(message: 'offline'));
    }
    return Right(_category(category, offset: offset, limit: limit));
  }

  @override
  Future<Either<Failure, List<LearningPathCategorySummary>>>
      getLearningPathCategorySummaries({String language = 'en'}) async {
    summaryRequests.add(language);
    if (failSummaries) {
      return const Left(NetworkFailure(message: 'offline'));
    }
    return Right([
      for (final name in _categoryNames)
        LearningPathCategorySummary(
          name: name,
          totalPaths: paths.where((p) => p.category == name).length,
        ),
    ]);
  }

  @override
  Future<LearningPathCategoriesResult?> getCachedLearningPathCategories({
    String language = 'en',
  }) async =>
      null;

  @override
  Future<Either<Failure, NextPathsResult>> getNextPaths({
    String language = 'en',
    int limit = 3,
  }) async =>
      const Right(NextPathsResult(paths: []));
}
