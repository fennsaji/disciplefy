import '../../domain/entities/achievement.dart';

/// Data model for Achievement from Supabase
class AchievementModel extends Achievement {
  const AchievementModel({
    required super.id,
    required super.name,
    required super.description,
    required super.icon,
    super.xpReward,
    required super.category,
    super.threshold,
    super.unlockedAt,
    super.isUnlocked,
  });

  /// Create from Supabase RPC response
  factory AchievementModel.fromJson(Map<String, dynamic> json) {
    return AchievementModel(
      id: json['achievement_id'] as String,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      icon: json['icon'] as String? ?? '🏆',
      xpReward: (json['xp_reward'] as num?)?.toInt() ?? 0,
      category: _parseCategory(json['category'] as String?),
      threshold: (json['threshold'] as num?)?.toInt(),
      unlockedAt: json['unlocked_at'] != null
          ? DateTime.tryParse(json['unlocked_at'].toString())
          : null,
      isUnlocked: json['is_unlocked'] as bool? ?? false,
    );
  }

  static AchievementCategory _parseCategory(String? category) {
    switch (category) {
      case 'study':
        return AchievementCategory.study;
      case 'streak':
        return AchievementCategory.streak;
      case 'memory':
        return AchievementCategory.memory;
      case 'voice':
        return AchievementCategory.voice;
      case 'saved':
        return AchievementCategory.saved;
      default:
        return AchievementCategory.study;
    }
  }

  /// Convert to JSON (for debugging/logging)
  Map<String, dynamic> toJson() {
    return {
      'achievement_id': id,
      'name': name,
      'description': description,
      'icon': icon,
      'xp_reward': xpReward,
      'category': category.name,
      'threshold': threshold,
      'unlocked_at': unlockedAt?.toIso8601String(),
      'is_unlocked': isUnlocked,
    };
  }

  /// Convert to domain entity
  Achievement toEntity() {
    return Achievement(
      id: id,
      name: name,
      description: description,
      icon: icon,
      xpReward: xpReward,
      category: category,
      threshold: threshold,
      unlockedAt: unlockedAt,
      isUnlocked: isUnlocked,
    );
  }
}

/// Model for achievement unlock result
class AchievementUnlockResultModel extends AchievementUnlockResult {
  const AchievementUnlockResultModel({
    required super.achievementId,
    required super.achievementName,
    required super.xpReward,
    required super.isNew,
  });

  factory AchievementUnlockResultModel.fromJson(Map<String, dynamic> json) {
    return AchievementUnlockResultModel(
      achievementId: json['achievement_id'] as String,
      achievementName: json['achievement_name'] as String? ?? '',
      xpReward: (json['xp_reward'] as num?)?.toInt() ?? 0,
      isNew: json['is_new'] as bool? ?? false,
    );
  }
}
