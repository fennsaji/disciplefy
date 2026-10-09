import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

import 'package:disciplefy_bible_study/core/services/http_service.dart';
import 'package:disciplefy_bible_study/features/study_topics/data/datasources/learning_paths_remote_datasource.dart';
import 'package:disciplefy_bible_study/features/study_topics/data/repositories/learning_paths_repository_impl.dart';
import 'package:disciplefy_bible_study/features/study_topics/data/services/learning_cache_scope.dart';
import 'package:disciplefy_bible_study/features/study_topics/data/services/learning_paths_cache_service.dart';

class _MockHttpService extends Mock implements HttpService {}

/// The flat list the server would return for [body]: 60 paths, paged.
http.Response _answer(Map<String, dynamic> body, {int progress = 0}) {
  final limit = body['limit'] as int;
  final offset = body['offset'] as int;
  final ids = [for (var i = 1; i <= 60; i++) i].skip(offset).take(limit);
  return http.Response(
      jsonEncode({
        'success': true,
        'data': {
          'paths': [
            for (final i in ids)
              {
                'id': 'p$i',
                'title': 'Path $i',
                'progress_percentage': progress,
                'is_enrolled': progress > 0,
              },
          ],
          'total': 60,
          'has_more': offset + ids.length < 60,
        },
      }),
      200);
}

void main() {
  late Directory dir;
  late _MockHttpService http_;
  late LearningPathsRepositoryImpl repository;
  var progress = 0;
  final bodies = <Map<String, dynamic>>[];

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('lp_flat_cache_test');
    Hive.init(dir.path);
    LearningCacheScope.resolver = () => 'user-a';
    progress = 0;
    bodies.clear();
    http_ = _MockHttpService();
    when(() => http_.createHeaders()).thenAnswer((_) async => {});
    when(() => http_.post(any(),
        headers: any(named: 'headers'),
        body: any(named: 'body'))).thenAnswer((inv) async {
      final body = jsonDecode(inv.namedArguments[#body] as String)
          as Map<String, dynamic>;
      bodies.add(body);
      return _answer(body, progress: progress);
    });
    repository = LearningPathsRepositoryImpl(
      remoteDataSource: LearningPathsRemoteDataSourceImpl(
          httpService: http_, cache: LearningPathsCacheService()),
    );
  });

  tearDown(() async {
    LearningCacheScope.resolver = null;
    await Hive.close();
    await dir.delete(recursive: true);
  });

  test('a cached 10-path page never answers a 50-path request', () async {
    final small = await repository.getLearningPaths();
    expect(small.getOrElse(() => throw StateError('')).paths, hasLength(10));

    // A fresh repository (new launch) still has the persisted page.
    repository = LearningPathsRepositoryImpl(
      remoteDataSource: LearningPathsRemoteDataSourceImpl(
          httpService: http_, cache: LearningPathsCacheService()),
    );
    final large = await repository.getLearningPaths(limit: 50);
    final data = large.getOrElse(() => throw StateError(''));
    expect(data.paths, hasLength(50));
    expect(data.hasMore, isTrue);
  });

  test('forceRefresh skips the persisted page', () async {
    await repository.getLearningPaths(limit: 50);
    progress = 40;
    repository = LearningPathsRepositoryImpl(
      remoteDataSource: LearningPathsRemoteDataSourceImpl(
          httpService: http_, cache: LearningPathsCacheService()),
    );
    final fresh =
        await repository.getLearningPaths(limit: 50, forceRefresh: true);
    expect(
        fresh
            .getOrElse(() => throw StateError(''))
            .paths
            .first
            .progressPercentage,
        40);
    expect(bodies, hasLength(2));
  });

  test('a fellowship listing is never served as the plain list', () async {
    await repository.getLearningPaths(limit: 50, fellowshipId: 'f1');
    await repository.getLearningPaths(limit: 50);
    expect(bodies, hasLength(2));
    expect(bodies.last.containsKey('fellowship_id'), isFalse);
  });
}
