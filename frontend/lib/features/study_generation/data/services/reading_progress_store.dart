import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:disciplefy_bible_study/core/utils/logger.dart';

/// How far the user has read one study guide.
class ReadingProgress {
  /// 1-based number of sections the reader has reached (the X in
  /// "SECTION X OF Y"). Never above [total].
  final int section;

  /// Number of sections the guide has (the Y).
  final int total;

  /// When this progress was last written.
  final DateTime updatedAt;

  const ReadingProgress({
    required this.section,
    required this.total,
    required this.updatedAt,
  });

  /// 0.0–1.0, for a progress line.
  double get fraction => total <= 0 ? 0 : (section / total).clamp(0.0, 1.0);

  bool get isComplete => total > 0 && section >= total;

  Map<String, dynamic> _toJson() => {
        's': section,
        't': total,
        'u': updatedAt.millisecondsSinceEpoch,
      };

  static ReadingProgress? _fromJson(Object? json) {
    if (json is! Map) return null;
    final s = json['s'];
    final t = json['t'];
    final u = json['u'];
    if (s is! int || t is! int || u is! int || t <= 0) return null;
    return ReadingProgress(
      section: s.clamp(0, t),
      total: t,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(u),
    );
  }

  @override
  String toString() => 'ReadingProgress($section/$total @ $updatedAt)';
}

/// Local, per-guide reading progress (ruling 5 of the Generate V2 redesign).
///
/// The study guide screen writes it whenever its segmented progress header
/// advances; the library's "Continue" card reads it to show
/// "CONTINUE · SECTION X OF Y". Stored in SharedPreferences as one JSON map
/// keyed by guide id, capped at [maxEntries] (oldest dropped).
///
/// Progress only moves forward: scrolling back up does not lower it. A
/// different [ReadingProgress.total] (the guide was regenerated with other
/// sections) replaces the entry.
class ReadingProgressStore {
  static const String prefsKey = 'study_guide_reading_progress_v1';
  static const int maxEntries = 100;

  final Future<SharedPreferences> Function() _prefs;

  ReadingProgressStore({Future<SharedPreferences> Function()? prefs})
      : _prefs = prefs ?? SharedPreferences.getInstance;

  /// Records that the reader of [guideId] has reached section [section]
  /// (1-based) of [total]. Ignored for empty ids or a non-positive total.
  Future<void> save(String guideId, int section, int total) async {
    if (guideId.isEmpty || total <= 0) return;
    try {
      final prefs = await _prefs();
      final all = _decode(prefs.getString(prefsKey));
      final previous = all[guideId];
      final clamped = section.clamp(0, total);
      if (previous != null &&
          previous.total == total &&
          previous.section >= clamped) {
        return; // Never move backwards; nothing new to write.
      }
      all[guideId] = ReadingProgress(
        section: clamped,
        total: total,
        updatedAt: DateTime.now(),
      );
      _trim(all);
      await prefs.setString(
        prefsKey,
        jsonEncode(all.map((k, v) => MapEntry(k, v._toJson()))),
      );
    } catch (e) {
      Logger.warning('[READING_PROGRESS] save failed: $e');
    }
  }

  /// Progress for [guideId], or null when the guide was never opened here.
  Future<ReadingProgress?> get(String guideId) async {
    final all = await getAll();
    return all[guideId];
  }

  /// Every stored entry, keyed by guide id.
  Future<Map<String, ReadingProgress>> getAll() async {
    try {
      final prefs = await _prefs();
      return _decode(prefs.getString(prefsKey));
    } catch (e) {
      Logger.warning('[READING_PROGRESS] read failed: $e');
      return {};
    }
  }

  /// Forgets [guideId] (e.g. when a guide is deleted).
  Future<void> remove(String guideId) async {
    try {
      final prefs = await _prefs();
      final all = _decode(prefs.getString(prefsKey));
      if (all.remove(guideId) == null) return;
      await prefs.setString(
        prefsKey,
        jsonEncode(all.map((k, v) => MapEntry(k, v._toJson()))),
      );
    } catch (e) {
      Logger.warning('[READING_PROGRESS] remove failed: $e');
    }
  }

  static Map<String, ReadingProgress> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final result = <String, ReadingProgress>{};
      decoded.forEach((key, value) {
        final progress = ReadingProgress._fromJson(value);
        if (key is String && progress != null) result[key] = progress;
      });
      return result;
    } catch (_) {
      return {};
    }
  }

  static void _trim(Map<String, ReadingProgress> all) {
    if (all.length <= maxEntries) return;
    final byAge = all.entries.toList()
      ..sort((a, b) => a.value.updatedAt.compareTo(b.value.updatedAt));
    for (final entry in byAge.take(all.length - maxEntries)) {
      all.remove(entry.key);
    }
  }
}
