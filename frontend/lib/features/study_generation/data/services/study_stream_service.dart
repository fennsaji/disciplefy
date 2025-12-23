import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/utils/event_source_bridge.dart';
import '../../domain/entities/study_mode.dart';
import '../../domain/entities/study_stream_event.dart';

/// Service for streaming study guide generation via SSE
///
/// Uses the study-generate-v2 endpoint which supports Server-Sent Events
/// for progressive section rendering.
class StudyStreamService {
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
    required String language,
    StudyMode studyMode = StudyMode.standard,
  }) async* {
    // Build URL with query parameters (auth is passed via headers, not query params)
    final baseUrl = '${AppConfig.baseApiUrl}/study-generate-v2';
    final queryParams = <String, String>{
      'input_type': inputType,
      'input_value': inputValue,
      'language': language,
      'mode': studyMode.name,
    };

    if (topicDescription != null && topicDescription.isNotEmpty) {
      queryParams['topic_description'] = topicDescription;
    }

    final uri = Uri.parse(baseUrl).replace(queryParameters: queryParams);
    final url = uri.toString();

    debugPrint('🌊 [STUDY_STREAM] Connecting to: $url');

    // Get auth headers for fetchEventSource (supports custom headers unlike native EventSource)
    final authHeaders = await _getAuthHeaders();

    // Connect to SSE stream
    final stream = EventSourceBridge.connect(
      url: url,
      headers: {
        'Accept': 'text/event-stream',
        'Cache-Control': 'no-cache',
        ...authHeaders,
      },
    );

    await for (final rawData in stream) {
      debugPrint('🌊 [STUDY_STREAM] Raw: $rawData');

      // fetch-event-source library already parses SSE format and gives us just the data
      // The rawData is the JSON content directly (no "event:" or "data:" prefixes)

      // Skip empty data
      if (rawData.isEmpty) continue;

      // Infer event type from the JSON content
      final eventType = _inferEventType(rawData);

      try {
        final event = StudyStreamEvent.parse(eventType, rawData);
        debugPrint('🌊 [STUDY_STREAM] Event: $eventType');
        yield event;

        // If we got an error or complete event, we're done
        if (event is StudyStreamErrorEvent ||
            event is StudyStreamCompleteEvent) {
          break;
        }
      } catch (e) {
        debugPrint('🌊 [STUDY_STREAM] Parse error: $e');
        yield StudyStreamErrorEvent(
          code: 'PARSE_ERROR',
          message: 'Failed to parse stream event: $e',
          retryable: true,
        );
        break;
      }
    }

    debugPrint('🌊 [STUDY_STREAM] Stream ended');
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
      debugPrint(
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
    return 'unknown';
  }

  /// Check if streaming is available on this platform
  bool get isStreamingAvailable => EventSourceBridge.isAvailable;

  /// Close all active stream connections
  void closeAllConnections() {
    EventSourceBridge.closeAll();
  }
}
