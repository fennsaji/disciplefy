import 'package:equatable/equatable.dart';

/// Entity representing user's study streak data
class StudyStreak extends Equatable {
  final String? id;
  final String userId;
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastStudyDate;
  final int totalStudyDays;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const StudyStreak({
    this.id,
    required this.userId,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastStudyDate,
    this.totalStudyDays = 0,
    this.createdAt,
    this.updatedAt,
  });

  /// Check if user has studied today
  bool get hasStudiedToday {
    if (lastStudyDate == null) return false;
    final today = DateTime.now();
    return lastStudyDate!.year == today.year &&
        lastStudyDate!.month == today.month &&
        lastStudyDate!.day == today.day;
  }

  /// Check if streak is at risk (last studied yesterday)
  bool get isStreakAtRisk {
    if (lastStudyDate == null || currentStreak == 0) return false;
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return lastStudyDate!.year == yesterday.year &&
        lastStudyDate!.month == yesterday.month &&
        lastStudyDate!.day == yesterday.day;
  }

  /// Check if streak is broken (last studied more than 1 day ago)
  bool get isStreakBroken {
    if (lastStudyDate == null) return false;
    final twoDaysAgo = DateTime.now().subtract(const Duration(days: 2));
    return lastStudyDate!.isBefore(twoDaysAgo);
  }

  /// Get days since last study
  int get daysSinceLastStudy {
    if (lastStudyDate == null) return -1;
    return DateTime.now().difference(lastStudyDate!).inDays;
  }

  StudyStreak copyWith({
    String? id,
    String? userId,
    int? currentStreak,
    int? longestStreak,
    DateTime? lastStudyDate,
    int? totalStudyDays,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StudyStreak(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastStudyDate: lastStudyDate ?? this.lastStudyDate,
      totalStudyDays: totalStudyDays ?? this.totalStudyDays,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        currentStreak,
        longestStreak,
        lastStudyDate,
        totalStudyDays,
        createdAt,
        updatedAt,
      ];
}

/// Result from updating study streak
class StudyStreakUpdateResult extends Equatable {
  final int currentStreak;
  final int longestStreak;
  final bool streakIncreased;
  final bool isNewRecord;

  const StudyStreakUpdateResult({
    required this.currentStreak,
    required this.longestStreak,
    required this.streakIncreased,
    required this.isNewRecord,
  });

  @override
  List<Object?> get props => [
        currentStreak,
        longestStreak,
        streakIncreased,
        isNewRecord,
      ];
}
