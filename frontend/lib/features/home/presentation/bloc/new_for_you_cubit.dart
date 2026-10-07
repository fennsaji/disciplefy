import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:disciplefy_bible_study/core/services/activation_analytics.dart';
import 'package:disciplefy_bible_study/core/utils/logger.dart';
import 'package:disciplefy_bible_study/features/home/domain/new_for_you/new_for_you_scheduler.dart';

/// The "New for you" banner shown on Home, or null for none.
///
/// The schedule is stored per user in [SharedPreferences] under
/// `new_for_you_v1_<userId>`.
class NewForYouCubit extends Cubit<NewForYouKind?> {
  final SharedPreferences _prefs;
  final DateTime Function() _clock;

  String? _userId;
  NewForYouState _state = NewForYouState.empty();

  NewForYouCubit({
    required SharedPreferences prefs,
    DateTime Function()? clock,
  })  : _prefs = prefs,
        _clock = clock ?? DateTime.now,
        super(null);

  static String keyFor(String userId) => 'new_for_you_v1_$userId';

  /// Local day (yyyy-MM-dd) [kind]'s banner was last reported as seen.
  static String impressionKeyFor(String userId, NewForYouKind kind) =>
      'new_for_you_seen_v1_${userId}_${kind.name}';

  /// Reads [userId]'s schedule, picks the banner for now and, when it is
  /// shown for the first time, records when.
  Future<void> load(String userId, NewForYouEligibility e) async {
    _userId = userId;
    _state = _read(userId);
    final now = _clock();
    final kind = pickBanner(_state, e, now);
    if (kind != null && !_state.firstShownAt.containsKey(kind)) {
      _state = _state.copyWith(
        firstShownAt: {..._state.firstShownAt, kind: now},
      );
      await _save();
    }
    if (kind != null) await _reportImpression(userId, kind, now);
    if (!isClosed && kind != state) emit(kind);
  }

  /// The person closed the banner. It never returns.
  Future<void> dismiss() => _markDone(NuxEvent.nfyDismiss);

  /// The person opened the banner's introduction. It never returns.
  Future<void> opened() => _markDone(NuxEvent.nfyTap);

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

  Future<void> _markDone(NuxEvent event) async {
    final kind = state;
    if (kind == null || _userId == null) return;
    ActivationAnalytics.maybeTrack(event, {'kind': kind.name});
    _state = _state.copyWith(done: {..._state.done, kind});
    await _save();
    if (!isClosed) emit(null);
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
      Logger.warning('Stored New for you schedule is unreadable',
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
      Logger.warning('Could not save New for you schedule',
          tag: 'NEW_FOR_YOU', context: {'error': e.runtimeType.toString()});
    }
  }
}
