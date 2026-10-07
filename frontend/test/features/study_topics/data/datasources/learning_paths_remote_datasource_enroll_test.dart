import 'dart:convert';

import 'package:disciplefy_bible_study/core/error/exceptions.dart';
import 'package:disciplefy_bible_study/features/study_topics/data/datasources/learning_paths_remote_datasource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/mockito.dart';

import 'learning_paths_remote_datasource_reset_test.mocks.dart';

void main() {
  late MockHttpService httpService;
  late MockLearningPathsCacheService cache;
  late LearningPathsRemoteDataSourceImpl dataSource;

  const okBody = '{"success": true, "data": {"id": "prog-1", '
      '"learning_path_id": "path-1", "enrolled_at": "2026-10-07T00:00:00Z"}}';

  void stubPost(http.Response response) {
    when(httpService.post(
      any,
      headers: anyNamed('headers'),
      body: anyNamed('body'),
      timeout: anyNamed('timeout'),
    )).thenAnswer((_) async => response);
  }

  String sentBody() => verify(httpService.post(
        any,
        headers: anyNamed('headers'),
        body: captureAnyNamed('body'),
        timeout: anyNamed('timeout'),
      )).captured.single as String;

  setUp(() {
    httpService = MockHttpService();
    cache = MockLearningPathsCacheService();
    dataSource = LearningPathsRemoteDataSourceImpl(
        httpService: httpService, cache: cache);
    when(httpService.createHeaders())
        .thenAnswer((_) async => <String, String>{});
    when(cache.clearCache()).thenAnswer((_) async {});
  });

  group('enrollInPath', () {
    test('sends pathId and parses the enrolment', () async {
      stubPost(http.Response(okBody, 200));

      final result = await dataSource.enrollInPath(pathId: 'path-1');

      expect(jsonDecode(sentBody()), {'pathId': 'path-1'});
      expect(result.learningPathId, 'path-1');
    });

    test('sends only the slug and returns the resolved learningPathId',
        () async {
      stubPost(http.Response(okBody, 200));

      final result = await dataSource.enrollInPath(slug: 'rooted-in-christ');

      expect(jsonDecode(sentBody()), {'slug': 'rooted-in-christ'});
      expect(result.learningPathId, 'path-1');
    });

    test('a 403 ACCOUNT_REQUIRED throws AccountRequiredException with reason',
        () async {
      stubPost(http.Response(
        '{"success": false, "error": {"code": "ACCOUNT_REQUIRED", '
        '"message": "Create an account to start another path.", '
        '"details": {"reason": "second_path"}}}',
        403,
      ));

      await expectLater(
        dataSource.enrollInPath(slug: 'faith-and-reason'),
        throwsA(isA<AccountRequiredException>()
            .having((e) => e.reason, 'reason', 'second_path')
            .having((e) => e.code, 'code', 'ACCOUNT_REQUIRED')
            .having((e) => e.message, 'message',
                'Create an account to start another path.')),
      );
    });

    test('any other 403 stays a ServerException', () async {
      stubPost(http.Response(
        '{"success": false, "error": {"code": "FEATURE_NOT_AVAILABLE", '
        '"message": "x"}}',
        403,
      ));

      await expectLater(
        dataSource.enrollInPath(pathId: 'path-1'),
        throwsA(isA<ServerException>()),
      );
    });

    test('neither pathId nor slug throws ValidationException without a call',
        () async {
      await expectLater(
        dataSource.enrollInPath(),
        throwsA(isA<ValidationException>()),
      );
      verifyNever(httpService.post(
        any,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
        timeout: anyNamed('timeout'),
      ));
    });
  });
}
