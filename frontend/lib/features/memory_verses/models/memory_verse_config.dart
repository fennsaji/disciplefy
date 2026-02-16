// Memory Verse Configuration Models
// Database-driven configuration for memory verse system

/// Spaced Repetition Configuration (SM-2 Algorithm)
class SpacedRepetitionConfig {
  final double initialEaseFactor;
  final int initialIntervalDays;
  final double minEaseFactor;
  final int maxIntervalDays;

  const SpacedRepetitionConfig({
    required this.initialEaseFactor,
    required this.initialIntervalDays,
    required this.minEaseFactor,
    required this.maxIntervalDays,
  });

  factory SpacedRepetitionConfig.fromJson(Map<String, dynamic> json) {
    return SpacedRepetitionConfig(
      initialEaseFactor: (json['initialEaseFactor'] as num?)?.toDouble() ?? 2.5,
      initialIntervalDays: json['initialIntervalDays'] as int? ?? 1,
      minEaseFactor: (json['minEaseFactor'] as num?)?.toDouble() ?? 1.3,
      maxIntervalDays: json['maxIntervalDays'] as int? ?? 365,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'initialEaseFactor': initialEaseFactor,
      'initialIntervalDays': initialIntervalDays,
      'minEaseFactor': minEaseFactor,
      'maxIntervalDays': maxIntervalDays,
    };
  }

  SpacedRepetitionConfig copyWith({
    double? initialEaseFactor,
    int? initialIntervalDays,
    double? minEaseFactor,
    int? maxIntervalDays,
  }) {
    return SpacedRepetitionConfig(
      initialEaseFactor: initialEaseFactor ?? this.initialEaseFactor,
      initialIntervalDays: initialIntervalDays ?? this.initialIntervalDays,
      minEaseFactor: minEaseFactor ?? this.minEaseFactor,
      maxIntervalDays: maxIntervalDays ?? this.maxIntervalDays,
    );
  }
}

/// Gamification Configuration (XP, Mastery)
class GamificationConfig {
  final int masteryThreshold;
  final int xpPerReview;
  final int xpMasteryBonus;

  const GamificationConfig({
    required this.masteryThreshold,
    required this.xpPerReview,
    required this.xpMasteryBonus,
  });

  factory GamificationConfig.fromJson(Map<String, dynamic> json) {
    return GamificationConfig(
      masteryThreshold: json['masteryThreshold'] as int? ?? 5,
      xpPerReview: json['xpPerReview'] as int? ?? 10,
      xpMasteryBonus: json['xpMasteryBonus'] as int? ?? 50,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'masteryThreshold': masteryThreshold,
      'xpPerReview': xpPerReview,
      'xpMasteryBonus': xpMasteryBonus,
    };
  }

  /// Calculate total XP for mastering a verse
  int calculateMasteryXP() {
    return (masteryThreshold * xpPerReview) + xpMasteryBonus;
  }

  GamificationConfig copyWith({
    int? masteryThreshold,
    int? xpPerReview,
    int? xpMasteryBonus,
  }) {
    return GamificationConfig(
      masteryThreshold: masteryThreshold ?? this.masteryThreshold,
      xpPerReview: xpPerReview ?? this.xpPerReview,
      xpMasteryBonus: xpMasteryBonus ?? this.xpMasteryBonus,
    );
  }
}

/// Memory Verse Configuration
/// Contains all configurable limits and settings for memory verse system
class MemoryVerseConfig {
  final Map<String, int> unlockLimits; // free, standard, plus, premium
  final Map<String, int> verseLimits; // free, standard, plus, premium
  final Map<String, List<String>> availableModes; // free, paid
  final SpacedRepetitionConfig spacedRepetition;
  final GamificationConfig gamification;

  const MemoryVerseConfig({
    required this.unlockLimits,
    required this.verseLimits,
    required this.availableModes,
    required this.spacedRepetition,
    required this.gamification,
  });

  /// Default configuration (fallback if database fetch fails)
  factory MemoryVerseConfig.defaultConfig() {
    return MemoryVerseConfig(
      unlockLimits: {
        'free': 1,
        'standard': 2,
        'plus': 3,
        'premium': -1, // unlimited
      },
      verseLimits: {
        'free': 3,
        'standard': 5,
        'plus': 10,
        'premium': -1, // unlimited
      },
      availableModes: {
        'free': ['flip_card', 'type_it_out'],
        'paid': [
          'flip_card',
          'type_it_out',
          'cloze',
          'first_letter',
          'progressive',
          'word_scramble',
          'word_bank',
          'audio',
        ],
      },
      spacedRepetition: const SpacedRepetitionConfig(
        initialEaseFactor: 2.5,
        initialIntervalDays: 1,
        minEaseFactor: 1.3,
        maxIntervalDays: 365,
      ),
      gamification: const GamificationConfig(
        masteryThreshold: 5,
        xpPerReview: 10,
        xpMasteryBonus: 50,
      ),
    );
  }

  factory MemoryVerseConfig.fromJson(Map<String, dynamic> json) {
    return MemoryVerseConfig(
      unlockLimits: {
        'free': json['unlockLimits']?['free'] as int? ?? 1,
        'standard': json['unlockLimits']?['standard'] as int? ?? 2,
        'plus': json['unlockLimits']?['plus'] as int? ?? 3,
        'premium': json['unlockLimits']?['premium'] as int? ?? -1,
      },
      verseLimits: {
        'free': json['verseLimits']?['free'] as int? ?? 3,
        'standard': json['verseLimits']?['standard'] as int? ?? 5,
        'plus': json['verseLimits']?['plus'] as int? ?? 10,
        'premium': json['verseLimits']?['premium'] as int? ?? -1,
      },
      availableModes: {
        'free': (json['availableModes']?['free'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            ['flip_card', 'type_it_out'],
        'paid': (json['availableModes']?['paid'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [
              'flip_card',
              'type_it_out',
              'cloze',
              'first_letter',
              'progressive',
              'word_scramble',
              'word_bank',
              'audio',
            ],
      },
      spacedRepetition: json['spacedRepetition'] != null
          ? SpacedRepetitionConfig.fromJson(json['spacedRepetition'])
          : const SpacedRepetitionConfig(
              initialEaseFactor: 2.5,
              initialIntervalDays: 1,
              minEaseFactor: 1.3,
              maxIntervalDays: 365,
            ),
      gamification: json['gamification'] != null
          ? GamificationConfig.fromJson(json['gamification'])
          : const GamificationConfig(
              masteryThreshold: 5,
              xpPerReview: 10,
              xpMasteryBonus: 50,
            ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'unlockLimits': unlockLimits,
      'verseLimits': verseLimits,
      'availableModes': availableModes,
      'spacedRepetition': spacedRepetition.toJson(),
      'gamification': gamification.toJson(),
    };
  }

  /// Get unlock limit for specific tier
  /// Returns -1 for unlimited (premium)
  int getUnlockLimitForTier(String tier) {
    final normalizedTier = tier.toLowerCase();
    return unlockLimits[normalizedTier] ?? unlockLimits['free'] ?? 1;
  }

  /// Get verse limit for specific tier
  /// Returns -1 for unlimited (premium)
  int getVerseLimitForTier(String tier) {
    final normalizedTier = tier.toLowerCase();
    return verseLimits[normalizedTier] ?? verseLimits['free'] ?? 3;
  }

  /// Get available practice modes for specific tier
  List<String> getAvailableModesForTier(String tier) {
    final normalizedTier = tier.toLowerCase();
    if (normalizedTier == 'free') {
      return availableModes['free'] ?? ['flip_card', 'type_it_out'];
    }
    // Standard, Plus, Premium get all modes
    return availableModes['paid'] ?? [];
  }

  /// Check if tier has access to specific practice mode
  bool hasAccessToMode(String tier, String mode) {
    final availableModes = getAvailableModesForTier(tier);
    return availableModes.contains(mode);
  }

  /// Get user-friendly unlock limit text
  String getUnlockLimitText(String tier) {
    final limit = getUnlockLimitForTier(tier);
    if (limit == -1) {
      return 'All modes unlocked';
    }
    return '$limit mode${limit > 1 ? 's' : ''} per verse per day';
  }

  /// Get user-friendly verse limit text
  String getVerseLimitText(String tier) {
    final limit = getVerseLimitForTier(tier);
    if (limit == -1) {
      return 'Unlimited verses';
    }
    return '$limit active verse${limit > 1 ? 's' : ''}';
  }

  /// Get recommended upgrade tier
  String getRecommendedUpgradeTier(String currentTier) {
    final tier = currentTier.toLowerCase();
    if (tier == 'free') return 'standard';
    if (tier == 'standard') return 'plus';
    if (tier == 'plus') return 'premium';
    return 'premium';
  }

  /// Get tier comparison for upgrade dialogs
  List<TierComparison> getTierComparison() {
    return [
      TierComparison(
        tier: 'free',
        tierName: 'Free',
        unlockLimit: getUnlockLimitForTier('free'),
        unlockLimitText: getUnlockLimitText('free'),
        verseLimit: getVerseLimitForTier('free'),
        verseLimitText: getVerseLimitText('free'),
        modeCount: getAvailableModesForTier('free').length,
      ),
      TierComparison(
        tier: 'standard',
        tierName: 'Standard',
        unlockLimit: getUnlockLimitForTier('standard'),
        unlockLimitText: getUnlockLimitText('standard'),
        verseLimit: getVerseLimitForTier('standard'),
        verseLimitText: getVerseLimitText('standard'),
        modeCount: getAvailableModesForTier('standard').length,
      ),
      TierComparison(
        tier: 'plus',
        tierName: 'Plus',
        unlockLimit: getUnlockLimitForTier('plus'),
        unlockLimitText: getUnlockLimitText('plus'),
        verseLimit: getVerseLimitForTier('plus'),
        verseLimitText: getVerseLimitText('plus'),
        modeCount: getAvailableModesForTier('plus').length,
      ),
      TierComparison(
        tier: 'premium',
        tierName: 'Premium',
        unlockLimit: getUnlockLimitForTier('premium'),
        unlockLimitText: getUnlockLimitText('premium'),
        verseLimit: getVerseLimitForTier('premium'),
        verseLimitText: getVerseLimitText('premium'),
        modeCount: getAvailableModesForTier('premium').length,
      ),
    ];
  }

  MemoryVerseConfig copyWith({
    Map<String, int>? unlockLimits,
    Map<String, int>? verseLimits,
    Map<String, List<String>>? availableModes,
    SpacedRepetitionConfig? spacedRepetition,
    GamificationConfig? gamification,
  }) {
    return MemoryVerseConfig(
      unlockLimits: unlockLimits ?? this.unlockLimits,
      verseLimits: verseLimits ?? this.verseLimits,
      availableModes: availableModes ?? this.availableModes,
      spacedRepetition: spacedRepetition ?? this.spacedRepetition,
      gamification: gamification ?? this.gamification,
    );
  }
}

/// Tier comparison data for upgrade dialogs
class TierComparison {
  final String tier;
  final String tierName;
  final int unlockLimit;
  final String unlockLimitText;
  final int verseLimit;
  final String verseLimitText;
  final int modeCount;

  const TierComparison({
    required this.tier,
    required this.tierName,
    required this.unlockLimit,
    required this.unlockLimitText,
    required this.verseLimit,
    required this.verseLimitText,
    required this.modeCount,
  });

  /// Check if this tier is unlimited
  bool get isUnlimited => unlockLimit == -1 || verseLimit == -1;

  /// Get feature comparison text
  String getFeatureText() {
    final features = <String>[];
    features.add(unlockLimitText);
    features.add(verseLimitText);
    features.add('$modeCount practice modes');
    return features.join(' • ');
  }
}
