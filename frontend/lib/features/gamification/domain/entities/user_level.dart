import 'package:equatable/equatable.dart';

/// Level configuration with XP thresholds and localized titles
class LevelConfig {
  final int level;
  final int xpRequired;
  final String titleEn;
  final String titleHi;
  final String titleMl;

  const LevelConfig({
    required this.level,
    required this.xpRequired,
    required this.titleEn,
    required this.titleHi,
    required this.titleMl,
  });

  String getTitle(String languageCode) {
    switch (languageCode) {
      case 'hi':
        return titleHi;
      case 'ml':
        return titleMl;
      default:
        return titleEn;
    }
  }
}

/// Static level configurations - Discipleship Journey
class LevelConfigs {
  static const List<LevelConfig> levels = [
    LevelConfig(
        level: 1,
        xpRequired: 0,
        titleEn: 'Seeker',
        titleHi: 'खोजी',
        titleMl: 'അന്വേഷകൻ'),
    LevelConfig(
        level: 2,
        xpRequired: 100,
        titleEn: 'Listener',
        titleHi: 'श्रोता',
        titleMl: 'ശ്രോതാവ്'),
    LevelConfig(
        level: 3,
        xpRequired: 300,
        titleEn: 'Learner',
        titleHi: 'शिक्षार्थी',
        titleMl: 'പഠിതാവ്'),
    LevelConfig(
        level: 4,
        xpRequired: 600,
        titleEn: 'Believer',
        titleHi: 'विश्वासी',
        titleMl: 'വിശ്വാസി'),
    LevelConfig(
        level: 5,
        xpRequired: 1000,
        titleEn: 'Follower',
        titleHi: 'अनुयायी',
        titleMl: 'അനുയായി'),
    LevelConfig(
        level: 6,
        xpRequired: 1500,
        titleEn: 'Apprentice',
        titleHi: 'शिष्य',
        titleMl: 'ശിഷ്യൻ'),
    LevelConfig(
        level: 7,
        xpRequired: 2500,
        titleEn: 'Practitioner',
        titleHi: 'साधक',
        titleMl: 'സാധകൻ'),
    LevelConfig(
        level: 8,
        xpRequired: 4000,
        titleEn: 'Servant',
        titleHi: 'सेवक',
        titleMl: 'ദാസൻ'),
    LevelConfig(
        level: 9,
        xpRequired: 6000,
        titleEn: 'Disciple',
        titleHi: 'चेला',
        titleMl: 'ശിഷ്യൻ'),
    LevelConfig(
        level: 10,
        xpRequired: 10000,
        titleEn: 'Discipler',
        titleHi: 'चेला बनाने वाला',
        titleMl: 'ശിഷ്യനാക്കുന്നവൻ'),
  ];

  /// Get level config for given XP
  static LevelConfig getLevelForXp(int xp) {
    for (int i = levels.length - 1; i >= 0; i--) {
      if (xp >= levels[i].xpRequired) {
        return levels[i];
      }
    }
    return levels.first;
  }

  /// Get next level config (or null if max level)
  static LevelConfig? getNextLevel(int currentLevel) {
    if (currentLevel >= levels.length) return null;
    return levels[
        currentLevel]; // currentLevel is 1-indexed, array is 0-indexed
  }

  /// Get XP required for next level
  static int? getXpForNextLevel(int currentLevel) {
    final next = getNextLevel(currentLevel);
    return next?.xpRequired;
  }
}

/// Entity representing user's current level and progress
class UserLevel extends Equatable {
  final int level;
  final String title;
  final int currentXp;
  final int xpForCurrentLevel;
  final int? xpForNextLevel;
  final double progressToNextLevel;

  const UserLevel({
    required this.level,
    required this.title,
    required this.currentXp,
    required this.xpForCurrentLevel,
    this.xpForNextLevel,
    required this.progressToNextLevel,
  });

  /// Calculate user level from XP
  factory UserLevel.fromXp(int xp, String languageCode) {
    final levelConfig = LevelConfigs.getLevelForXp(xp);
    final nextLevelConfig = LevelConfigs.getNextLevel(levelConfig.level);

    double progress = 0.0;
    if (nextLevelConfig != null) {
      final xpInCurrentLevel = xp - levelConfig.xpRequired;
      final xpNeededForNextLevel =
          nextLevelConfig.xpRequired - levelConfig.xpRequired;
      progress = xpInCurrentLevel / xpNeededForNextLevel;
    } else {
      progress = 1.0; // Max level
    }

    return UserLevel(
      level: levelConfig.level,
      title: levelConfig.getTitle(languageCode),
      currentXp: xp,
      xpForCurrentLevel: levelConfig.xpRequired,
      xpForNextLevel: nextLevelConfig?.xpRequired,
      progressToNextLevel: progress.clamp(0.0, 1.0),
    );
  }

  /// Check if at max level
  bool get isMaxLevel => xpForNextLevel == null;

  /// Get XP needed for next level
  int get xpNeededForNextLevel {
    if (xpForNextLevel == null) return 0;
    return xpForNextLevel! - currentXp;
  }

  @override
  List<Object?> get props => [
        level,
        title,
        currentXp,
        xpForCurrentLevel,
        xpForNextLevel,
        progressToNextLevel,
      ];
}
