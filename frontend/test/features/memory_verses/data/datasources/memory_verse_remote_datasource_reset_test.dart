import 'package:disciplefy_bible_study/core/error/exceptions.dart';
import 'package:disciplefy_bible_study/core/services/http_service.dart';
import 'package:disciplefy_bible_study/features/memory_verses/data/datasources/memory_verse_remote_datasource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'memory_verse_remote_datasource_reset_test.mocks.dart';

@GenerateMocks([HttpService])
void main() {
  late MockHttpService httpService;
  late MemoryVerseRemoteDataSource dataSource;

  setUp(() {
    httpService = MockHttpService();
    dataSource = MemoryVerseRemoteDataSource(httpService: httpService);

    when(httpService.createHeaders())
        .thenAnswer((_) async => <String, String>{});
  });

  group('resetMemoryProgress status-code mapping', () {
    test('a 429 response throws RateLimitException, not ServerException',
        () async {
      when(httpService.post(
        any,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
        timeout: anyNamed('timeout'),
      )).thenAnswer((_) async => http.Response('{}', 429));

      await expectLater(
        dataSource.resetMemoryProgress(),
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
        dataSource.resetMemoryProgress(),
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
        dataSource.resetMemoryProgress(),
        throwsA(isA<ServerException>()),
      );
    });

    test('a 200 response with a malformed body throws ServerException',
        () async {
      when(httpService.post(
        any,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
        timeout: anyNamed('timeout'),
      )).thenAnswer((_) async => http.Response('{"success":true}', 200));

      await expectLater(
        dataSource.resetMemoryProgress(),
        throwsA(isA<ServerException>()),
      );
    });

    test('a 200 response parses and returns the reset result', () async {
      when(httpService.post(
        any,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
        timeout: anyNamed('timeout'),
      )).thenAnswer((_) async => http.Response(
            '{"success":true,"data":{"scope":"memory_verses","counts":{"verses_deleted":3}}}',
            200,
          ));

      final result = await dataSource.resetMemoryProgress();

      expect(result.scope, 'memory_verses');
      expect(result.counts['verses_deleted'], 3);
    });
  });
}
