import 'package:disciplefy_bible_study/core/error/exceptions.dart';
import 'package:disciplefy_bible_study/core/models/reset_progress_result.dart';
import 'package:disciplefy_bible_study/core/services/http_service.dart';
import 'package:disciplefy_bible_study/features/study_topics/data/datasources/learning_paths_remote_datasource.dart';
import 'package:disciplefy_bible_study/features/study_topics/data/services/learning_paths_cache_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'learning_paths_remote_datasource_reset_test.mocks.dart';

@GenerateMocks([HttpService, LearningPathsCacheService])
void main() {
  late MockHttpService httpService;
  late LearningPathsRemoteDataSourceImpl dataSource;

  setUp(() {
    httpService = MockHttpService();
    dataSource = LearningPathsRemoteDataSourceImpl(httpService: httpService);

    when(httpService.createHeaders())
        .thenAnswer((_) async => <String, String>{});
  });

  group('resetLearningProgress status-code mapping', () {
    test('a 429 response throws RateLimitException, not ServerException',
        () async {
      when(httpService.post(
        any,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
        timeout: anyNamed('timeout'),
      )).thenAnswer((_) async => http.Response('{}', 429));

      await expectLater(
        dataSource.resetLearningProgress(),
        throwsA(isA<RateLimitException>()),
      );
    });

    test('a 401 response throws AuthenticationException', () async {
      when(httpService.post(
        any,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
        timeout: anyNamed('timeout'),
      )).thenAnswer((_) async => http.Response('{}', 401));

      await expectLater(
        dataSource.resetLearningProgress(),
        throwsA(isA<AuthenticationException>()),
      );
    });

    test('a 500 response throws ServerException', () async {
      when(httpService.post(
        any,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
        timeout: anyNamed('timeout'),
      )).thenAnswer((_) async => http.Response('{}', 500));

      await expectLater(
        dataSource.resetLearningProgress(),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('resetLearningProgress cache-clear failure', () {
    test(
        'returns the parsed result when the remote reset succeeds but '
        'clearCache() throws afterwards', () async {
      final cache = MockLearningPathsCacheService();
      final dataSourceWithMockCache = LearningPathsRemoteDataSourceImpl(
        httpService: httpService,
        cache: cache,
      );

      when(httpService.post(
        any,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
        timeout: anyNamed('timeout'),
      )).thenAnswer((_) async => http.Response(
            '{"success": true, "data": {"scope": "learning_paths", '
            '"counts": {"paths_reset": 3, "topics_reset": 27}}}',
            200,
          ));
      when(cache.clearCache()).thenThrow(Exception('Hive box I/O error'));

      // The server-side reset is irreversible and already succeeded, so a
      // cache-clear failure must not surface as a thrown exception.
      final result = await dataSourceWithMockCache.resetLearningProgress();

      expect(
        result,
        const ResetProgressResult(
          scope: 'learning_paths',
          counts: {'paths_reset': 3, 'topics_reset': 27},
        ),
      );
      verify(cache.clearCache()).called(1);
    });
  });
}
