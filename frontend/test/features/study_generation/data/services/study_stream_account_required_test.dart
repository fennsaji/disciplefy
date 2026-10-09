import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:disciplefy_bible_study/core/error/failures.dart';
import 'package:disciplefy_bible_study/features/study_generation/data/services/study_stream_service.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_stream_event.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/bloc/handlers/study_streaming_handler.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/bloc/study_event.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/bloc/study_state.dart';

/// The backend's standard error envelope for a guest's typed study.
final _envelope = jsonEncode({
  'success': false,
  'error': {
    'code': 'ACCOUNT_REQUIRED',
    'message': 'Create an account to continue.',
    'details': {'reason': 'generate'},
  },
});

/// The flat shape some handlers still answer with.
final _flat = jsonEncode({
  'error': 'ACCOUNT_REQUIRED',
  'message': 'Create an account to continue.',
});

StudyStreamService _service(Stream<String> Function() stream) =>
    StudyStreamService(
      connect: ({required url, headers}) => stream(),
      authHeaders: () async => const {},
    );

Future<List<StudyStreamEvent>> _events(StudyStreamService service) => service
    .streamStudyGuide(inputType: 'topic', inputValue: 'Prayer', language: 'en')
    .toList();

void main() {
  group('StudyStreamService: ACCOUNT_REQUIRED', () {
    test('HTTP 403 on mobile (body in the error) → account error, reason',
        () async {
      final events = await _events(_service(() => Stream.error(
          Exception('HTTP 403: Failed to connect to SSE: $_envelope'))));
      final error = events.single as StudyStreamErrorEvent;
      expect(error.code, 'ACCOUNT_REQUIRED');
      expect(error.reason, 'generate');
      expect(error.retryable, isFalse);
    });

    test('403 on web (JSON passed to onError) → account error', () async {
      final events = await _events(_service(
          () => Stream.error(Exception('EventSource error: ${jsonEncode({
                    'success': false,
                    'error': {
                      'code': 'ACCOUNT_REQUIRED',
                      'message': 'm',
                      'details': {'reason': 'other_path'},
                    },
                  })}'))));
      final error = events.single as StudyStreamErrorEvent;
      expect(error.code, 'ACCOUNT_REQUIRED');
      expect(error.reason, 'other_path');
    });

    test('flat {error, message} shape → account error without a reason',
        () async {
      final events = await _events(
          _service(() => Stream.error(Exception('HTTP 403: $_flat'))));
      final error = events.single as StudyStreamErrorEvent;
      expect(error.code, 'ACCOUNT_REQUIRED');
      expect(error.reason, isNull);
    });

    test('envelope and flat shapes sent as SSE data → account error', () async {
      for (final body in [_envelope, _flat]) {
        final events = await _events(_service(() => Stream.value(body)));
        final error = events.single as StudyStreamErrorEvent;
        expect(error.code, 'ACCOUNT_REQUIRED', reason: body);
      }
    });

    test('any other connection error still surfaces as an exception', () async {
      expect(_events(_service(() => Stream.error(Exception('HTTP 500: boom')))),
          throwsException);
    });
  });

  group('StudyStreamingHandler', () {
    test('ACCOUNT_REQUIRED becomes an AccountRequiredFailure with its reason',
        () {
      final handler = StudyStreamingHandler(
          streamService: _service(() => const Stream.empty()));
      final emitted = <StudyState>[];
      handler.handleStreamErrorOccurred(
        const StudyStreamErrorOccurred(
          code: 'ACCOUNT_REQUIRED',
          message: 'Create an account to continue.',
          retryable: false,
          reason: 'generate',
        ),
        _Emitter(emitted),
        const StudyInitial(),
      );
      final failed = emitted.single as StudyGenerationStreamingFailed;
      expect(failed.failure, isA<AccountRequiredFailure>());
      expect((failed.failure as AccountRequiredFailure).reason, 'generate');
      expect(failed.canRetry, isFalse);
    });
  });
}

class _Emitter implements Emitter<StudyState> {
  final List<StudyState> states;
  _Emitter(this.states);

  @override
  void call(StudyState state) => states.add(state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
