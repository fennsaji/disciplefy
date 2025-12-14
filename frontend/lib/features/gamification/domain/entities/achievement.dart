import 'package:equatable/equatable.dart';

/// Category types for achievements
enum AchievementCategory {
  study,
  streak,
  memory,
  voice,
  saved,
}

/// Entity representing an achievement badge
class Achievement extends Equatable {
  final String id;
  final String name;
  final String description;
  final String icon;
  final int xpReward;
  final AchievementCategory category;
  final int? threshold;
  final DateTime? unlockedAt;
  final bool isUnlocked;

  const Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    this.xpReward = 0,
    required this.category,
    this.threshold,
    this.unlockedAt,
    this.isUnlocked = false,
  });

  /// Get progress percentage (0.0 to 1.0) based on current count
  double getProgress(int currentCount) {
    if (threshold == null || threshold == 0) return isUnlocked ? 1.0 : 0.0;
    if (isUnlocked) return 1.0;
    return (currentCount / threshold!).clamp(0.0, 1.0);
  }

  Achievement copyWith({
    String? id,
    String? name,
    String? description,
    String? icon,
    int? xpReward,
    AchievementCategory? category,
    int? threshold,
    DateTime? unlockedAt,
    bool? isUnlocked,
  }) {
    return Achievement(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      xpReward: xpReward ?? this.xpReward,
      category: category ?? this.category,
      threshold: threshold ?? this.threshold,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      isUnlocked: isUnlocked ?? this.isUnlocked,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        icon,
        xpReward,
        category,
        threshold,
        unlockedAt,
        isUnlocked,
      ];
}

/// Result from checking achievements - newly unlocked achievement
class AchievementUnlockResult extends Equatable {
  final String achievementId;
  final String achievementName;
  final int xpReward;
  final bool isNew;

  const AchievementUnlockResult({
    required this.achievementId,
    required this.achievementName,
    required this.xpReward,
    required this.isNew,
  });

  @override
  List<Object?> get props => [
        achievementId,
        achievementName,
        xpReward,
        isNew,
      ];
}
