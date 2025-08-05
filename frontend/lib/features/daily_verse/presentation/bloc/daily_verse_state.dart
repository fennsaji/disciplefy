import 'package:equatable/equatable.dart';
import '../../domain/entities/daily_verse_entity.dart';

/// States for Daily Verse BLoC
abstract class DailyVerseState extends Equatable {
  const DailyVerseState();

  @override
  List<Object?> get props => [];
}

/// Mixin for states that contain verse data with language switching capability
mixin VerseDataStateMixin {
  DailyVerseEntity get verse;
  VerseLanguage get currentLanguage;
  VerseLanguage get preferredLanguage;

  /// Get current verse text based on selected language
  String get currentVerseText => verse.getVerseText(currentLanguage);

  /// Get formatted date
  String get formattedDate => verse.formattedDate;
}

/// Initial state
class DailyVerseInitial extends DailyVerseState {
  const DailyVerseInitial();
}

/// Loading verse
class DailyVerseLoading extends DailyVerseState {
  final bool isRefreshing;

  const DailyVerseLoading({this.isRefreshing = false});

  @override
  List<Object?> get props => [isRefreshing];
}

/// Verse loaded successfully
class DailyVerseLoaded extends DailyVerseState with VerseDataStateMixin {
  @override
  final DailyVerseEntity verse;
  @override
  final VerseLanguage currentLanguage;
  @override
  final VerseLanguage preferredLanguage;
  final bool isFromCache;
  final bool isServiceAvailable;

  const DailyVerseLoaded({
    required this.verse,
    required this.currentLanguage,
    required this.preferredLanguage,
    this.isFromCache = false,
    this.isServiceAvailable = true,
  });

  /// Check if verse is for today
  bool get isToday => verse.isToday;

  /// Copy with new values
  DailyVerseLoaded copyWith({
    DailyVerseEntity? verse,
    VerseLanguage? currentLanguage,
    VerseLanguage? preferredLanguage,
    bool? isFromCache,
    bool? isServiceAvailable,
  }) =>
      DailyVerseLoaded(
        verse: verse ?? this.verse,
        currentLanguage: currentLanguage ?? this.currentLanguage,
        preferredLanguage: preferredLanguage ?? this.preferredLanguage,
        isFromCache: isFromCache ?? this.isFromCache,
        isServiceAvailable: isServiceAvailable ?? this.isServiceAvailable,
      );

  @override
  List<Object?> get props => [
        verse,
        currentLanguage,
        preferredLanguage,
        isFromCache,
        isServiceAvailable,
      ];
}

/// Error loading verse
class DailyVerseError extends DailyVerseState {
  final String message;
  final bool hasCachedFallback;

  const DailyVerseError({
    required this.message,
    this.hasCachedFallback = false,
  });

  @override
  List<Object?> get props => [message, hasCachedFallback];
}

/// Offline mode with cached verse
class DailyVerseOffline extends DailyVerseState with VerseDataStateMixin {
  @override
  final DailyVerseEntity verse;
  @override
  final VerseLanguage currentLanguage;
  @override
  final VerseLanguage preferredLanguage;

  const DailyVerseOffline({
    required this.verse,
    required this.currentLanguage,
    required this.preferredLanguage,
  });

  /// Copy with new language
  DailyVerseOffline copyWith({
    DailyVerseEntity? verse,
    VerseLanguage? currentLanguage,
    VerseLanguage? preferredLanguage,
  }) =>
      DailyVerseOffline(
        verse: verse ?? this.verse,
        currentLanguage: currentLanguage ?? this.currentLanguage,
        preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      );

  @override
  List<Object?> get props => [verse, currentLanguage, preferredLanguage];
}

/// Cache statistics loaded
class DailyVerseCacheStats extends DailyVerseState {
  final Map<String, dynamic> stats;

  const DailyVerseCacheStats({required this.stats});

  @override
  List<Object?> get props => [stats];
}

/// Cache cleared successfully
class DailyVerseCacheCleared extends DailyVerseState {
  const DailyVerseCacheCleared();
}

/// Language preference updated
class DailyVerseLanguageUpdated extends DailyVerseState {
  final VerseLanguage newLanguage;

  const DailyVerseLanguageUpdated({required this.newLanguage});

  @override
  List<Object?> get props => [newLanguage];
}
