import 'dart:convert';
import 'dart:io';

import 'package:disciplefy_bible_study/core/services/http_service.dart';
import 'package:disciplefy_bible_study/features/study_topics/data/datasources/learning_paths_remote_datasource.dart';
import 'package:disciplefy_bible_study/features/study_topics/data/repositories/learning_paths_repository_impl.dart';
import 'package:disciplefy_bible_study/features/study_topics/data/services/learning_cache_scope.dart';
import 'package:disciplefy_bible_study/features/study_topics/data/services/learning_paths_cache_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

class _MockHttpService extends Mock implements HttpService {}

String _recommendedBody(String id, int progress) => jsonEncode({
      'success': true,
      'data': {
        'reason': 'active',
        'path': {
          'id': id,
          'title': 'Path $id',
          'is_enrolled': true,
          'progress_percentage': progress,
        },
      },
    });

String _categoriesBody(String id, int progress) => jsonEncode({
      'success': true,
      'data': {
        'categories': [
          {
            'name': 'Foundations',
            'paths': [
              {
                'id': id,
                'title': 'Path $id',
                'is_enrolled': progress > 0,
                'progress_percentage': progress,
              },
            ],
            'total_in_category': 1,
            'has_more_in_category': false,
            'next_path_offset': 1,
          },
        ],
        'has_more_categories': false,
        'next_category_offset': 1,
      },
    });

void main() {
  late Directory dir;
  late _MockHttpService http_;
  late LearningPathsCacheService cache;
  late LearningPathsRemoteDataSourceImpl dataSource;
  late LearningPathsRepositoryImpl repository;
  var currentUser = 'user-a';

  /// Queue of bodies the next POSTs answer with, keyed by URL fragment.
  final responses = <String, List<http.Response>>{};

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('lp_cache_scope_test');
    Hive.init(dir.path);
    currentUser = 'user-a';
    LearningCacheScope.resolver = () => currentUser;
    responses.clear();

    http_ = _MockHttpService();
    when(() => http_.createHeaders()).thenAnswer((_) async => {});
    when(() => http_.post(any(),
        headers: any(named: 'headers'),
        body: any(named: 'body'))).thenAnswer((inv) async {
      final url = inv.positionalArguments.first as String;
      final key = url.contains('action=recommended') ? 'recommended' : 'list';
      final queue = responses[key]!;
      return queue.length > 1 ? queue.removeAt(0) : queue.first;
    });

    cache = LearningPathsCacheService();
    dataSource =
        LearningPathsRemoteDataSourceImpl(httpService: http_, cache: cache);
    repository = LearningPathsRepositoryImpl(remoteDataSource: dataSource);
  });

  tearDown(() async {
    LearningCacheScope.resolver = null;
    await Hive.close();
    await dir.delete(recursive: true);
  });

  group('LearningPathsCacheService', () {
    test('entries are keyed by user: another account never reads them',
        () async {
      await cache.cacheResponse(
          type: 'categories', language: 'en', responseBody: 'a-body');

      expect(await cache.getCachedResponse(type: 'categories', language: 'en'),
          'a-body');

      currentUser = 'user-b';
      expect(await cache.getCachedResponse(type: 'categories', language: 'en'),
          isNull);

      LearningCacheScope.resolver = () => throw StateError('no auth');
      expect(await cache.getCachedResponse(type: 'categories', language: 'en'),
          isNull,
          reason: 'signed-out scope must not see a user\'s entries');
    });

    test('entries are keyed by language', () async {
      await cache.cacheResponse(
          type: 'categories', language: 'en', responseBody: 'en-body');
      expect(await cache.getCachedResponse(type: 'categories', language: 'hi'),
          isNull);
    });
  });

  group('recommended ("continue learning") path', () {
    test('is persisted and served from disk on the next launch', () async {
      responses['recommended'] = [
        http.Response(_recommendedBody('p1', 40), 200)
      ];

      final fresh = await repository.getRecommendedPath();
      expect(fresh.isRight(), isTrue);

      // A new process: fresh repository and datasource, same Hive box.
      final nextLaunch = LearningPathsRepositoryImpl(
        remoteDataSource: LearningPathsRemoteDataSourceImpl(
            httpService: http_, cache: LearningPathsCacheService()),
      );
      final cached = await nextLaunch.getCachedRecommendedPath();
      expect(cached?.path.id, 'p1');
      expect(cached?.path.progressPercentage, 40);
    });

    test('is isolated per user and per language', () async {
      responses['recommended'] = [
        http.Response(_recommendedBody('p1', 40), 200)
      ];
      await repository.getRecommendedPath();

      expect(await repository.getCachedRecommendedPath(language: 'hi'), isNull);

      currentUser = 'user-b';
      expect(await repository.getCachedRecommendedPath(), isNull);
    });

    test('forceRefresh always fetches and replaces the cached progress',
        () async {
      responses['recommended'] = [
        http.Response(_recommendedBody('p1', 40), 200),
        http.Response(_recommendedBody('p1', 60), 200),
      ];
      await repository.getRecommendedPath();
      final refreshed = await repository.getRecommendedPath(forceRefresh: true);

      expect(refreshed.getOrElse(() => throw 'x').path.progressPercentage, 60);
      expect(
          (await repository.getCachedRecommendedPath())
              ?.path
              .progressPercentage,
          60);
    });

    test('offline: falls back to this user\'s persisted copy', () async {
      responses['recommended'] = [
        http.Response(_recommendedBody('p1', 40), 200)
      ];
      await repository.getRecommendedPath();

      when(() => http_.post(any(),
              headers: any(named: 'headers'), body: any(named: 'body')))
          .thenThrow(const SocketException('offline'));
      final offline = LearningPathsRepositoryImpl(
        remoteDataSource: LearningPathsRemoteDataSourceImpl(
            httpService: http_, cache: LearningPathsCacheService()),
      );
      final result = await offline.getRecommendedPath(forceRefresh: true);
      expect(result.getOrElse(() => throw 'x').path.id, 'p1');

      currentUser = 'user-b';
      final otherUser = await offline.getRecommendedPath(forceRefresh: true);
      expect(otherUser.isLeft(), isTrue);
    });
  });

  group('category listing cache', () {
    test('cached listing is available without network, per user', () async {
      responses['list'] = [http.Response(_categoriesBody('p1', 25), 200)];
      await repository.getLearningPathCategories();

      final cached = await repository.getCachedLearningPathCategories();
      expect(cached?.categories.single.paths.single.progressPercentage, 25);

      currentUser = 'user-b';
      expect(await repository.getCachedLearningPathCategories(), isNull);
    });

    test('clearCache (enroll / complete / reset) drops memory and disk copies',
        () async {
      responses['list'] = [http.Response(_categoriesBody('p1', 25), 200)];
      responses['recommended'] = [
        http.Response(_recommendedBody('p1', 25), 200)
      ];
      await repository.getLearningPathCategories();
      await repository.getRecommendedPath();

      repository.clearCache();
      // clearCache is fire-and-forget on the Hive side.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(await repository.getCachedLearningPathCategories(), isNull);
      expect(await repository.getCachedRecommendedPath(), isNull);
    });
  });
}
