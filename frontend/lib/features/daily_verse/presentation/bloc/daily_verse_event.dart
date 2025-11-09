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

/// Mark today's verse as viewed for streak tracking
class MarkVerseAsViewed extends DailyVerseEvent {
  const MarkVerseAsViewed();
}
