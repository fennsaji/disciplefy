import 'dart:convert';
import 'dart:io';

import 'package:disciplefy_bible_study/core/error/exceptions.dart';
import 'package:disciplefy_bible_study/core/error/failures.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/utils/memory_add_error_message.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/features/memory_verses/data/datasources/memory_verse_local_datasource.dart';
import 'package:disciplefy_bible_study/features/memory_verses/data/datasources/memory_verse_remote_datasource.dart';
import 'package:disciplefy_bible_study/features/memory_verses/data/repositories/memory_verse_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/mockito.dart';

import '../datasources/memory_verse_remote_datasource_reset_test.mocks.dart';

/// Body returned by POST add-memory-verse-manual (captured from the local backend).
const _createdBody = {
  'success': true,
  'data': {
    'id': 'be326d15-e95b-434d-8738-fc783f26c82b',
    'verse_reference': 'Matthew 11:28',
    'verse_text':
        'Come to me, all you who are weary and burdened, and I will give you rest.',
    'language': 'en',
    'source_type': 'manual',
    'ease_factor': 2.5,
    'interval_days': 1,
    'repetitions': 0,
    'next_review_date': '2026-09-30T16:31:59.997+00:00',
    'added_date': '2026-09-30T16:31:59.997+00:00',
    'created_at': '2026-09-30T16:31:59.997+00:00',
    'total_reviews': 0,
  },
};

void main() {
  late MockHttpService httpService;
  late MemoryVerseRepositoryImpl repository;
  late Directory hiveDir;

  setUp(() async {
    hiveDir = await Directory.systemTemp.createTemp('mv_add_manual');
    Hive.init(hiveDir.path);
    httpService = MockHttpService();
    when(httpService.createHeaders())
        .thenAnswer((_) async => <String, String>{});
    repository = MemoryVerseRepositoryImpl(
      localDataSource: MemoryVerseLocalDataSource(),
      remoteDataSource: MemoryVerseRemoteDataSource(httpService: httpService),
    );
  });

  tearDown(() async {
    await Hive.close();
    await hiveDir.delete(recursive: true);
  });

  void stubPost(int status, Object body) {
    when(httpService.post(
      any,
      headers: anyNamed('headers'),
      body: anyNamed('body'),
      timeout: anyNamed('timeout'),
    )).thenAnswer((_) async => http.Response(jsonEncode(body), status));
  }

  Future<dynamic> add() async => repository.addVerseManually(
        verseReference: 'Matthew 11:28',
        verseText:
            'Come to me, all you who are weary and burdened, and I will give you rest.',
        language: 'en',
      );

  test('a 201 response yields the added verse', () async {
    stubPost(201, _createdBody);
    final result = await add();
    expect(result.isRight(), isTrue, reason: '$result');
  });

  test('a 409 response maps to VERSE_ALREADY_EXISTS', () async {
    stubPost(409, {
      'success': false,
      'error': {
        'code': 'CONFLICT',
        'message': 'This verse is already in your memory deck'
      }
    });
    final result = await add();
    result.fold(
      (Failure f) => expect(f.code, 'VERSE_ALREADY_EXISTS'),
      (_) => fail('expected failure'),
    );
  });
  test('a network failure is queued and reported as OFFLINE_QUEUED', () async {
    when(httpService.post(
      any,
      headers: anyNamed('headers'),
      body: anyNamed('body'),
      timeout: anyNamed('timeout'),
    )).thenThrow(
        const NetworkException(message: 'offline', code: 'NETWORK_ERROR'));
    final result = await add();
    result.fold(
      (Failure f) {
        expect(f, isA<NetworkFailure>());
        expect(f.code, 'OFFLINE_QUEUED');
      },
      (_) => fail('expected failure'),
    );
  });

  group('memoryAddErrorKey', () {
    test('maps add-verse outcomes to user-facing messages', () {
      expect(memoryAddErrorKey('VERSE_ALREADY_EXISTS'),
          TranslationKeys.memoryAddFeedbackAlreadyExists);
      expect(memoryAddErrorKey('FORBIDDEN'),
          TranslationKeys.memoryAddFeedbackLimitReached);
      expect(memoryAddErrorKey('MEMORY_VERSE_LIMIT_REACHED'),
          TranslationKeys.memoryAddFeedbackLimitReached);
      expect(memoryAddErrorKey('OFFLINE_QUEUED'),
          TranslationKeys.memoryAddFeedbackQueued);
      expect(memoryAddErrorKey('RATE_LIMIT_EXCEEDED'), isNull);
      expect(memoryAddErrorKey('UNEXPECTED_ERROR'), isNull);
      expect(memoryAddErrorKey(null), isNull);
    });
  });
}
