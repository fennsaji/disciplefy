import 'dart:async';
import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:disciplefy_bible_study/core/services/activation_analytics.dart';
import 'package:disciplefy_bible_study/core/utils/logger.dart';
import 'package:disciplefy_bible_study/features/home/domain/new_for_you/new_for_you_remote.dart';
import 'package:disciplefy_bible_study/features/home/domain/new_for_you/new_for_you_scheduler.dart';

/// The signed-in user's creation time as the auth server reported it, or
/// null when there is no session.
DateTime? currentAccountCreatedAt() {
  try {
    final created = Supabase.instance.client.auth.currentUser?.createdAt;
    return created == null ? null : DateTime.tryParse(created);
  } catch (_) {
    return null;
  }
}

/// The "New for you" banner shown on Home, or null for none.
///
/// The state lives on the server (see [NewForYouRemote]) and is cached per
/// user in [SharedPreferences] under `new_for_you_v2_<userId>`, so Home can
/// decide offline and a different account on the device starts fresh.
class NewForYouCubit extends Cubit<NewForYouKind?> {
  static const Duration _remoteWait = Duration(seconds: 5);

  final SharedPreferences _prefs;
  final NewForYouRemote? _remote;
  final DateTime Function() _clock;
  final DateTime? Function() _accountCreatedAt;

  String? _userId;
  NewForYouState _state = NewForYouState.empty();

  NewForYouCubit({
    required SharedPreferences prefs,
    NewForYouRemote? remote,
    DateTime Function()? clock,
    DateTime? Function()? accountCreatedAt,
  })  : _prefs = prefs,
        _remote = remote,
        _clock = clock ?? DateTime.now,
        _accountCreatedAt = accountCreatedAt ?? currentAccountCreatedAt,
        super(null);

  static String keyFor(String userId) => 'new_for_you_v2_$userId';

  /// Local day (yyyy-MM-dd) [kind]'s banner was last reported as seen.
  static String impressionKeyFor(String userId, NewForYouKind kind) =>
      'new_for_you_seen_v1_${userId}_${kind.name}';

  /// Reads [userId]'s state (device cache merged with the server copy),
  /// picks the banner for now and records it as today's.
  ///
  /// The start date is the server's (falling back to the session's account
  /// creation time when the server cannot be reached).
  Future<void> load(String userId, NewForYouEligibility e) async {
    _userId = userId;
    var s = _read(userId);
    final synced = await _sync(s);
    if (isClosed || _userId != userId) return;
    if (synced != null) s = s.merge(synced.state);
    final started = synced?.startedAt ?? e.startedAt ?? _accountCreatedAt();
    final now = _clock();
    final kind = pickBanner(s, e.withStartedAt(started), now);
    final record = kind != null &&
        (s.lastShownKind != kind ||
            s.lastShownAt == null ||
            !_sameDay(s.lastShownAt!, now));
    if (record) s = s.copyWith(lastShownKind: kind, lastShownAt: now);
    _state = s;
    await _save();
    if (record) _push();
    if (kind != null) await _reportImpression(userId, kind, now);
    if (!isClosed && kind != state) emit(kind);
  }

  /// The person closed the banner: that kind never returns.
  Future<void> dismiss() async {
    final kind = state;
    if (kind == null || _userId == null) return;
    ActivationAnalytics.maybeTrack(NuxEvent.nfyDismiss, {'kind': kind.name});
    _state = _state.copyWith(retired: {..._state.retired, kind});
    await _finish();
  }

  /// The person opened the banner's introduction: nothing more today. The
  /// kind is retired only once the feature is actually tried.
  Future<void> opened() async {
    final kind = state;
    if (kind == null || _userId == null) return;
    ActivationAnalytics.maybeTrack(NuxEvent.nfyTap, {'kind': kind.name});
    _state = _state.copyWith(openedAt: _clock());
    await _finish();
  }

  Future<void> _finish() async {
    await _save();
    _push();
    if (!isClosed) emit(null);
  }

  static bool _sameDay(DateTime a, DateTime b) {
    final x = a.toLocal();
    final y = b.toLocal();
    return x.year == y.year && x.month == y.month && x.day == y.day;
  }

  Future<NewForYouSync?> _sync(NewForYouState local) async {
    final remote = _remote;
    if (remote == null) return null;
    try {
      return await remote.sync(local).timeout(_remoteWait);
    } catch (e) {
      Logger.warning('New for you sync failed; using the device copy',
          tag: 'NEW_FOR_YOU', context: {'error': e.runtimeType.toString()});
      return null;
    }
  }

  /// Sends the current state to the server without waiting, and folds the
  /// answer (e.g. a kind retired on another device) into the cache.
  void _push() {
    final userId = _userId;
    if (userId == null || _remote == null) return;
    unawaited(_sync(_state).then((synced) async {
      if (synced == null || isClosed || _userId != userId) return;
      _state = _state.merge(synced.state);
      await _save();
    }));
  }

  /// Sends `nux.nfy_impression` for [kind] once per local day.
  Future<void> _reportImpression(
      String userId, NewForYouKind kind, DateTime now) async {
    final day = '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    final key = impressionKeyFor(userId, kind);
    try {
      if (_prefs.getString(key) == day) return;
      await _prefs.setString(key, day);
    } catch (e) {
      Logger.warning('Could not save New for you impression day',
          tag: 'NEW_FOR_YOU', context: {'error': e.runtimeType.toString()});
    }
    ActivationAnalytics.maybeTrack(NuxEvent.nfyImpression, {'kind': kind.name});
  }

  NewForYouState _read(String userId) {
    final raw = _prefs.getString(keyFor(userId));
    if (raw == null) return NewForYouState.empty();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return NewForYouState.fromJson(decoded);
      }
    } catch (e) {
      Logger.warning('Stored New for you state is unreadable',
          tag: 'NEW_FOR_YOU', context: {'error': e.runtimeType.toString()});
    }
    return NewForYouState.empty();
  }

  Future<void> _save() async {
    final userId = _userId;
    if (userId == null) return;
    try {
      await _prefs.setString(keyFor(userId), jsonEncode(_state.toJson()));
    } catch (e) {
      Logger.warning('Could not save New for you state',
          tag: 'NEW_FOR_YOU', context: {'error': e.runtimeType.toString()});
    }
  }
}
