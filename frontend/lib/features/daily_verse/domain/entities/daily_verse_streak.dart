import 'package:equatable/equatable.dart';

/// Domain entity for daily verse streak tracking
class DailyVerseStreak extends Equatable {
  final String userId;
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastViewedAt;
  final int totalViews;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DailyVerseStreak({
    required this.userId,
    required this.currentStreak,
    required this.longestStreak,
    this.lastViewedAt,
    required this.totalViews,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Check if user has viewed verse today
  bool get hasViewedToday {
    if (lastViewedAt == null) return false;

    final now = DateTime.now();
    final lastViewed = lastViewedAt!;

    return lastViewed.year == now.year &&
        lastViewed.month == now.month &&
        lastViewed.day == now.day;
  }

  /// Check if streak can continue (last view was yesterday)
  bool get canContinueStreak {
    if (lastViewedAt == null) return false;

    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    final lastViewed = lastViewedAt!;

    return lastViewed.year == yesterday.year &&
        lastViewed.month == yesterday.month &&
        lastViewed.day == yesterday.day;
  }

  /// Check if streak should be reset (last view was before yesterday)
  bool get shouldResetStreak {
    if (lastViewedAt == null) return false;
    if (hasViewedToday || canContinueStreak) return false;
    return true;
  }

  /// Get milestone badge emoji based on streak count
  String? get milestoneEmoji {
    if (currentStreak >= 365) return '🌟'; // Yearly Champion
    if (currentStreak >= 100) return '🏆'; // Century Scholar
    if (currentStreak >= 30) return '✨'; // Monthly Master
    if (currentStreak >= 7) return '🔥'; // Week Warrior
    return null;
  }

  /// Get milestone name based on streak count
  String? get milestoneName {
    if (currentStreak >= 365) return 'Yearly Champion';
    if (currentStreak >= 100) return 'Century Scholar';
    if (currentStreak >= 30) return 'Monthly Master';
    if (currentStreak >= 7) return 'Week Warrior';
    return null;
  }

  /// Check if current streak is at a milestone
  bool get isAtMilestone {
    return currentStreak == 7 ||
        currentStreak == 30 ||
        currentStreak == 100 ||
        currentStreak == 365;
  }

  /// Create a copy with updated fields
  DailyVerseStreak copyWith({
    String? userId,
    int? currentStreak,
    int? longestStreak,
    DateTime? lastViewedAt,
    int? totalViews,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DailyVerseStreak(
      userId: userId ?? this.userId,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastViewedAt: lastViewedAt ?? this.lastViewedAt,
      totalViews: totalViews ?? this.totalViews,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Create initial streak for new user
  factory DailyVerseStreak.initial(String userId) {
    final now = DateTime.now();
    return DailyVerseStreak(
      userId: userId,
      currentStreak: 0,
      longestStreak: 0,
      totalViews: 0,
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  List<Object?> get props => [
        userId,
        currentStreak,
        longestStreak,
        lastViewedAt,
        totalViews,
        createdAt,
        updatedAt,
      ];
}
