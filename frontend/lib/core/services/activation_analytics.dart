import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:disciplefy_bible_study/core/utils/logger.dart';

/// New-user activation events written to `analytics_events` (`nux.*` types).
enum NuxEvent {
  firstOpen,
  languageSelected,
  goalSelected,
  verseViewed,
  lessonStarted,
  lessonCompleted,
  signupCompleted,
  guestContinued,
  accountNeededShown,
  nfyImpression,
  nfyTap,
  nfyDismiss,
  creditWarningShown,
  reminderOptIn,
}

extension NuxEventName on NuxEvent {
  /// The `event_type` stored in the database, e.g. `nux.first_open`.
  String get type => 'nux.${_snake(name)}';

  static String _snake(String camel) => camel.replaceAllMapped(
        RegExp('[A-Z]'),
        (m) => '_${m.group(0)!.toLowerCase()}',
      );
}

/// Records activation events. Events raised while signed out or offline wait in
/// a Hive queue and are sent with their original time once a user exists.
///
/// Neither [track] nor [flush] ever throws: analytics must not break the app.
class ActivationAnalytics {
  ActivationAnalytics({
    required SupabaseClient client,
    required Box<dynamic> queue,
    DateTime Function()? clock,
  })  : _client = client,
        _queue = queue,
        _clock = clock ?? DateTime.now;

  static const String _table = 'analytics_events';
  static const String _firstOpenFlag = 'first_open_sent';
  static const int _maxStringLength = 64;

  /// One id per app launch, shared by every event of that launch.
  static final String appSessionId = const Uuid().v4();

  final SupabaseClient _client;
  final Box<dynamic> _queue;
  final DateTime Function() _clock;
  bool _flushing = false;

  Future<void> track(NuxEvent e, [Map<String, Object?> data = const {}]) async {
    try {
      final clientTs = _clock().toUtc().toIso8601String();
      final eventData = <String, Object?>{
        ..._sanitize(data),
        'client_ts': clientTs,
      };
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        await _enqueue(e.type, eventData);
        return;
      }
      try {
        await _client.from(_table).insert({
          'user_id': userId,
          'event_type': e.type,
          'event_data': eventData,
          'session_id': appSessionId,
        });
      } catch (err) {
        Logger.warning('[ActivationAnalytics] insert failed, queued: $err');
        await _enqueue(e.type, eventData);
      }
    } catch (err) {
      Logger.warning('[ActivationAnalytics] track failed: $err');
    }
  }

  /// Sends queued events in order. Stops at the first failure and keeps the
  /// rest for the next flush.
  Future<void> flush() async {
    if (_flushing) return;
    _flushing = true;
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return;
      final keys = _queue.keys.whereType<int>().toList()..sort();
      for (final key in keys) {
        final item = _queue.get(key);
        if (item is! Map) {
          await _queue.delete(key);
          continue;
        }
        final eventData = Map<String, Object?>.from(
            (item['data'] as Map?)?.cast<String, Object?>() ?? const {});
        final clientTs = eventData['client_ts'];
        try {
          await _client.from(_table).insert({
            'user_id': userId,
            'event_type': item['type'],
            'event_data': eventData,
            'session_id': appSessionId,
            if (clientTs is String) 'created_at': clientTs,
          });
        } catch (err) {
          Logger.warning('[ActivationAnalytics] flush stopped: $err');
          return;
        }
        await _queue.delete(key);
      }
    } catch (err) {
      Logger.warning('[ActivationAnalytics] flush failed: $err');
    } finally {
      _flushing = false;
    }
  }

  /// Sends `nux.first_open` once per install.
  Future<void> trackFirstOpenOnce() async {
    try {
      if (_queue.get(_firstOpenFlag) == true) return;
      await _queue.put(_firstOpenFlag, true);
      await track(NuxEvent.firstOpen);
    } catch (err) {
      Logger.warning('[ActivationAnalytics] first open failed: $err');
    }
  }

  Future<void> _enqueue(String type, Map<String, Object?> data) =>
      _queue.add({'type': type, 'data': data});

  /// Keeps String (up to 64 chars), num and bool only.
  Map<String, Object?> _sanitize(Map<String, Object?> data) {
    final out = <String, Object?>{};
    data.forEach((k, v) {
      if (v is bool || v is num) {
        out[k] = v;
      } else if (v is String && v.length <= _maxStringLength) {
        out[k] = v;
      }
    });
    return out;
  }
}
