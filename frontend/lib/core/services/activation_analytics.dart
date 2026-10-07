import 'dart:async';

import 'package:get_it/get_it.dart';
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
    String queueBoxName = defaultQueueBox,
    DateTime Function()? clock,
  })  : _client = client,
        _queueBoxName = queueBoxName,
        _clock = clock ?? DateTime.now;

  /// The Hive box that holds events waiting to be sent.
  static const String defaultQueueBox = 'nux_events';
  static const String _table = 'analytics_events';
  static const String _firstOpenFlag = 'first_open_sent';
  static const int _maxStringLength = 64;

  /// Most events kept waiting; the oldest are dropped beyond this.
  static const int maxQueued = 200;

  /// One id per app launch, shared by every event of that launch.
  static final String appSessionId = const Uuid().v4();

  /// Fire-and-forget [track] on the registered service, for hook points in
  /// the UI. Does nothing when no service is registered (tests, early start)
  /// and never throws.
  static void maybeTrack(NuxEvent e, [Map<String, Object?> data = const {}]) {
    try {
      final locator = GetIt.instance;
      if (!locator.isRegistered<ActivationAnalytics>()) return;
      unawaited(locator<ActivationAnalytics>().track(e, data).catchError(
          (Object err) =>
              Logger.warning('[ActivationAnalytics] track failed: $err')));
    } catch (err) {
      Logger.warning('[ActivationAnalytics] maybeTrack failed: $err');
    }
  }

  final SupabaseClient _client;
  final String _queueBoxName;
  final DateTime Function() _clock;
  bool _flushing = false;

  /// The queue box, resolved per call: logout closes every Hive box
  /// (`Hive.close()`), so a handle kept from start-up would be closed.
  Future<Box<dynamic>> _queue() async => Hive.isBoxOpen(_queueBoxName)
      ? Hive.box<dynamic>(_queueBoxName)
      : await Hive.openBox<dynamic>(_queueBoxName);

  Future<void> track(NuxEvent e, [Map<String, Object?> data = const {}]) async {
    try {
      final clientTs = _clock().toUtc().toIso8601String();
      final eventData = <String, Object?>{
        ..._sanitize(data),
        'client_ts': clientTs,
      };
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        // Signed out: sent as whoever signs in next on this device (the
        // pre-sign-in funnel, e.g. first_open).
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
        if (isPermanentInsertError(err)) {
          Logger.warning('[ActivationAnalytics] insert rejected, dropped: '
              '${err.runtimeType}');
          return;
        }
        Logger.warning('[ActivationAnalytics] insert failed, queued: $err');
        await _enqueue(e.type, eventData, userId: userId);
      }
    } catch (err) {
      Logger.warning('[ActivationAnalytics] track failed: $err');
    }
  }

  /// Sends queued events in order as the current user. Stops at the first
  /// retryable failure and keeps the rest for the next flush.
  ///
  /// An event queued while another user was signed in is dropped, never
  /// sent as this user. An event the server rejects for good (4xx) is
  /// dropped so it cannot block the queue.
  Future<void> flush() async {
    if (_flushing) return;
    _flushing = true;
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return;
      final queue = await _queue();
      final keys = queue.keys.whereType<int>().toList()..sort();
      for (final key in keys) {
        final item = queue.get(key);
        if (item is! Map) {
          await queue.delete(key);
          continue;
        }
        final owner = item['user_id'];
        if (owner != null && owner != userId) {
          await queue.delete(key);
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
          if (isPermanentInsertError(err)) {
            Logger.warning('[ActivationAnalytics] queued event rejected, '
                'dropped: ${err.runtimeType}');
            await queue.delete(key);
            continue;
          }
          Logger.warning('[ActivationAnalytics] flush stopped: $err');
          return;
        }
        await queue.delete(key);
      }
    } catch (err) {
      Logger.warning('[ActivationAnalytics] flush failed: $err');
    } finally {
      _flushing = false;
    }
  }

  /// Sends `nux.first_open` with [data] once per install.
  Future<void> trackFirstOpenOnce(
      [Map<String, Object?> data = const {}]) async {
    try {
      final queue = await _queue();
      if (queue.get(_firstOpenFlag) == true) return;
      await queue.put(_firstOpenFlag, true);
      await track(NuxEvent.firstOpen, data);
    } catch (err) {
      Logger.warning('[ActivationAnalytics] first open failed: $err');
    }
  }

  /// Queues an event. [userId] is set only for an event raised while signed
  /// in, so it is never sent as a different user.
  Future<void> _enqueue(String type, Map<String, Object?> data,
      {String? userId}) async {
    final queue = await _queue();
    await queue.add({
      'type': type,
      'data': data,
      if (userId != null) 'user_id': userId,
    });
    final keys = queue.keys.whereType<int>().toList();
    if (keys.length > maxQueued) {
      keys.sort();
      await queue.deleteAll(keys.take(keys.length - maxQueued));
    }
  }

  /// True when retrying [err] cannot succeed: a PostgREST request or data
  /// error (HTTP 4xx other than 401/408/429, SQLSTATE classes 22/23/42,
  /// PGRST1xx/2xx). Network errors, expired tokens and 5xx are retryable.
  static bool isPermanentInsertError(Object err) {
    if (err is! PostgrestException) return false;
    final code = err.code ?? '';
    if (RegExp(r'^4\d\d$').hasMatch(code)) {
      return code != '401' && code != '408' && code != '429';
    }
    return code.startsWith('22') ||
        code.startsWith('23') ||
        code.startsWith('42') ||
        code.startsWith('PGRST1') ||
        code.startsWith('PGRST2');
  }

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
