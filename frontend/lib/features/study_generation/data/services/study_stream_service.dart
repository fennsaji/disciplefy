import 'dart:async';
import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/utils/event_source_bridge.dart';
import '../../domain/entities/study_mode.dart';
import '../../domain/entities/study_stream_event.dart';
import '../../../../core/utils/logger.dart';

/// Service for streaming study guide generation via SSE
///
/// Uses the study-generate-v2 endpoint which supports Server-Sent Events
/// for progressive section rendering.
class StudyStreamService {
  /// Opens the SSE connection; [EventSourceBridge.connect] unless a test
  /// passes its own.
  final Stream<String> Function({
    required String url,
    Map<String, String>? headers,
  }) _connect;

  /// Auth headers for the request; the Supabase session unless a test passes
  /// its own.
  final Future<Map<String, String>> Function()? _authHeadersOverride;

  StudyStreamService({
    Stream<String> Function({
      required String url,
      Map<String, String>? headers,
    })? connect,
    Future<Map<String, String>> Function()? authHeaders,
  })  : _connect = connect ?? EventSourceBridge.connect,
        _authHeadersOverride = authHeaders;

  /// Stream study guide generation, yielding events as they arrive
  ///
  /// Parameters:
  /// - [inputType]: Type of input ('scripture', 'topic', or 'question')
  /// - [inputValue]: The actual input value (verse reference, topic, or question)
  /// - [topicDescription]: Optional description for topic-based studies
  /// - [language]: Target language code ('en', 'hi', 'ml')
  /// - [studyMode]: Study mode ('quick', 'standard', 'deep', 'lectio')
  ///
  /// Returns a stream of [StudyStreamEvent] objects representing:
  /// - init: Stream started or cache hit
  /// - section: A completed study guide section
  /// - complete: All sections done, includes study guide ID
  /// - error: An error occurred
  Stream<StudyStreamEvent> streamStudyGuide({
    required String inputType,
    required String inputValue,
    String? topicDescription,
    String? pathTitle,
    String? pathDescription,
    String? discipleLevel,
    required String language,
    StudyMode studyMode = StudyMode.standard,
    // TODO: Remove or update this when learning path token pricing is finalized.
    String? topicId,
  }) async* {
    // Build URL with query parameters (auth is passed via headers, not query params)
    final baseUrl = '${AppConfig.baseApiUrl}/study-generate-v2';
    final queryParams = <String, String>{
      'input_type': inputType,
      'input_value': inputValue,
      'language': language,
      'mode': studyMode.name,
    };

    // Truncate long text fields to prevent URL length overflow (Malayalam/Hindi text
    // URL-encodes at ~9 chars per character, easily exceeding 8KB URL limits).
    const int descMaxChars = 300;
    const int pathDescMaxChars = 200;
    const int pathTitleMaxChars = 100;

    if (topicDescription != null && topicDescription.isNotEmpty) {
      queryParams['topic_description'] = topicDescription.length > descMaxChars
          ? topicDescription.substring(0, descMaxChars)
          : topicDescription;
    }

    if (pathTitle != null && pathTitle.isNotEmpty) {
      queryParams['path_title'] = pathTitle.length > pathTitleMaxChars
          ? pathTitle.substring(0, pathTitleMaxChars)
          : pathTitle;
    }

    if (pathDescription != null && pathDescription.isNotEmpty) {
      queryParams['path_description'] =
          pathDescription.length > pathDescMaxChars
              ? pathDescription.substring(0, pathDescMaxChars)
              : pathDescription;
    }

    if (discipleLevel != null && discipleLevel.isNotEmpty) {
      queryParams['disciple_level'] = discipleLevel;
    }

    // TODO: Remove or update this when learning path token pricing is finalized.
    if (topicId != null && topicId.isNotEmpty) {
      queryParams['topic_id'] = topicId;
    }

    final uri = Uri.parse(baseUrl).replace(queryParameters: queryParams);
    final url = uri.toString();

    Logger.debug('🌊 [STUDY_STREAM] Connecting to: $url');

    // Get auth headers for fetchEventSource (supports custom headers unlike native EventSource)
    final authHeaders =
        await (_authHeadersOverride?.call() ?? _getAuthHeaders());

    // Connect to SSE stream. A refused connection (HTTP 403
    // ACCOUNT_REQUIRED: a guest's typed study or paid mode) arrives as a
    // stream error carrying the response body; it becomes an error event
    // so the UI offers an account instead of "generation failed".
    final stream = _connect(
      url: url,
      headers: {
        'Accept': 'text/event-stream',
        'Cache-Control': 'no-cache',
        ...authHeaders,
      },
    ).handleError(
      (Object error) => throw _AccountRequiredSignal(accountRequiredIn(error)!),
      test: (error) => accountRequiredIn(error) != null,
    );

    try {
      await for (final event in _events(stream)) {
        yield event;
        if (event is StudyStreamErrorEvent ||
            event is StudyStreamCompleteEvent) {
          break;
        }
      }
    } on _AccountRequiredSignal catch (signal) {
      yield signal.event;
    }

    Logger.debug('🌊 [STUDY_STREAM] Stream ended');
  }

  /// The `ACCOUNT_REQUIRED` error described by a refused connection
  /// ([error]'s text holds the JSON body), or null for any other error.
  static StudyStreamErrorEvent? accountRequiredIn(Object error) {
    final text = error.toString();
    if (!text.contains('ACCOUNT_REQUIRED')) return null;
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start >= 0 && end > start) {
      try {
        final json = jsonDecode(text.substring(start, end + 1));
        if (json is Map<String, dynamic>) {
          final event = StudyStreamErrorEvent.fromJson(json);
          if (event.code == 'ACCOUNT_REQUIRED') return event;
        }
      } catch (_) {
        // Not JSON: fall through to the bare code.
      }
    }
    return const StudyStreamErrorEvent(
      code: 'ACCOUNT_REQUIRED',
      message: 'Create an account to continue.',
      retryable: false,
    );
  }

  Stream<StudyStreamEvent> _events(Stream<String> stream) async* {
    await for (final rawData in stream) {
      Logger.debug('🌊 [STUDY_STREAM] Raw: $rawData');

      // fetch-event-source library already parses SSE format and gives us just the data
      // The rawData is the JSON content directly (no "event:" or "data:" prefixes)

      // Skip empty data
      if (rawData.isEmpty) continue;

      // Infer event type from the JSON content
      final eventType = _inferEventType(rawData);

      try {
        final event = StudyStreamEvent.parse(eventType, rawData);
        Logger.debug('🌊 [STUDY_STREAM] Event: $eventType');
        yield event;

        // If we got an error or complete event, we're done
        if (event is StudyStreamErrorEvent ||
            event is StudyStreamCompleteEvent) {
          return;
        }
      } on UnknownStudySectionException catch (e) {
        // A section this build does not model (e.g. the generator's internal
        // interpretationPartN fields). Skip it and keep reading the stream —
        // aborting here ended generation with "Generation interrupted".
        Logger.debug('🌊 [STUDY_STREAM] Skipping unknown section: $e');
        continue;
      } catch (e) {
        Logger.debug('🌊 [STUDY_STREAM] Parse error: $e');
        yield StudyStreamErrorEvent(
          code: 'PARSE_ERROR',
          message: 'Failed to parse stream event: $e',
          retryable: true,
        );
        return;
      }
    }
  }

  /// Get authentication headers for fetchEventSource
  ///
  /// Unlike native EventSource, fetch-event-source library supports custom headers.
  /// This is the preferred method for authentication.
  Future<Map<String, String>> _getAuthHeaders() async {
    final headers = <String, String>{
      'apikey': AppConfig.supabaseAnonKey,
    };

    // Get access token if authenticated
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null && session.accessToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer ${session.accessToken}';
      Logger.debug(
          '🔐 [STUDY_STREAM] Auth header set for user: ${session.user.id}');
    }

    return headers;
  }

  /// Infer event type from data content (fallback)
  String _inferEventType(String data) {
    if (data.contains('"status"')) return 'init';
    if (data.contains('"type"') && data.contains('"content"')) return 'section';
    if (data.contains('"studyGuideId"')) return 'complete';
    if (data.contains('"code"') && data.contains('"message"')) return 'error';
    // The flat `{error: 'CODE', message}` shape.
    if (data.contains('"error"') && data.contains('"message"')) return 'error';
    return 'unknown';
  }

  /// Check if streaming is available on this platform
  bool get isStreamingAvailable => EventSourceBridge.isAvailable;

  /// Close all active stream connections
  void closeAllConnections() {
    EventSourceBridge.closeAll();
  }
}

/// Carries an `ACCOUNT_REQUIRED` refusal out of the connection stream.
class _AccountRequiredSignal implements Exception {
  final StudyStreamErrorEvent event;

  const _AccountRequiredSignal(this.event);
}
