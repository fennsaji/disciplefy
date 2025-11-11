import 'package:equatable/equatable.dart';
import '../../domain/entities/daily_verse_entity.dart';

/// Events for Daily Verse BLoC
abstract class DailyVerseEvent extends Equatable {
  const DailyVerseEvent();

  @override
  List<Object?> get props => [];
}

/// Load today's verse
class LoadTodaysVerse extends DailyVerseEvent {
  final bool forceRefresh;

  const LoadTodaysVerse({this.forceRefresh = false});

  @override
  List<Object?> get props => [forceRefresh];
}

/// Load verse for specific date
class LoadVerseForDate extends DailyVerseEvent {
  final DateTime date;
  final bool forceRefresh;

  const LoadVerseForDate({
    required this.date,
    this.forceRefresh = false,
  });

  @override
  List<Object?> get props => [date, forceRefresh];
}

/// Change displayed language
class ChangeVerseLanguage extends DailyVerseEvent {
  final VerseLanguage language;

  const ChangeVerseLanguage({required this.language});

  @override
  List<Object?> get props => [language];
}

/// Set preferred language (persisted)
class SetPreferredVerseLanguage extends DailyVerseEvent {
  final VerseLanguage language;

  const SetPreferredVerseLanguage({required this.language});

  @override
  List<Object?> get props => [language];
}

/// Refresh current verse
class RefreshVerse extends DailyVerseEvent {
  const RefreshVerse();
}

/// Load cached verse only (offline mode)
class LoadCachedVerse extends DailyVerseEvent {
  final DateTime? date;

  const LoadCachedVerse({this.date});

  @override
  List<Object?> get props => [date];
}

/// Check service availability
class CheckServiceAvailability extends DailyVerseEvent {
  const CheckServiceAvailability();
}

/// Clear verse cache
class ClearVerseCacheEvent extends DailyVerseEvent {
  const ClearVerseCacheEvent();
}

/// Get cache statistics
class GetCacheStatsEvent extends DailyVerseEvent {
  const GetCacheStatsEvent();
}

/// Language preference changed via settings
class LanguagePreferenceChanged extends DailyVerseEvent {
  const LanguagePreferenceChanged();
}

/// Mark today's daily verse as viewed for streak tracking purposes.
///
/// This event is automatically triggered when a user views today's verse,
/// updating their daily verse viewing streak in the database. The streak
/// is either incremented (if viewed consecutively) or reset (if a day was skipped).
///
/// **Behavior:**
/// - Only updates streak if today's verse hasn't been viewed yet
/// - Increments current streak if viewed yesterday
/// - Resets streak to 1 if a day was missed
/// - Updates longest streak if current streak exceeds it
/// - Triggers milestone notifications (7, 30, 100, 365 days)
/// - Triggers streak lost notification if streak was reset
///
/// **Usage:**
/// This event is typically dispatched automatically by the BLoC when
/// [LoadTodaysVerse] completes successfully, so manual invocation is rarely needed.
///
/// **Side Effects:**
/// - Database update to `daily_verse_streaks` table
/// - Push notification sent for milestones or streak loss
/// - State update with new streak information
///
/// **Error Handling:**
/// Failures are silently handled as streak tracking is an optional feature
/// and should not disrupt the core verse viewing experience.
class MarkVerseAsViewed extends DailyVerseEvent {
  const MarkVerseAsViewed();
}
