import '../../../../core/di/injection_container.dart';
import '../../../../core/services/system_config_service.dart';
import '../../../../core/utils/logger.dart';
import '../../data/models/subscription_v2_models.dart';

/// Shared utility for extracting and formatting plan features
/// Used by PricingPage and all upgrade pages to ensure consistency
class PlanFeaturesExtractor {
  /// Returns the feature list for a plan.
  ///
  /// Priority:
  /// 1. [marketingFeatures] from DB — marketer-written copy, zero jargon.
  /// 2. Computed fallback from [featuresJson] — used when DB copy is not yet
  ///    populated (e.g. old app versions or missing migration).
  static List<String> extractFeaturesFromPlan(
    SubscriptionPlanModel plan,
  ) {
    if (plan.marketingFeatures.isNotEmpty) {
      return plan.marketingFeatures;
    }
    return extractFeatures(plan.features, plan.planCode);
  }

  /// Extracts a human-readable list of features from plan feature JSON
  /// Reads memory verse / practice limits from SystemConfigService
  static List<String> extractFeatures(
    Map<String, dynamic> featuresJson,
    String planCode,
  ) {
    final features = <String>[];
    final planCodeLower = planCode.toLowerCase();

    final dailyTokens = featuresJson['daily_tokens'] as int?;
    final followUps = featuresJson['followups'] as int?;

    if (dailyTokens != null) {
      if (dailyTokens == -1) {
        features.add('Unlimited AI tokens (all study modes)');
      } else if (dailyTokens == 8) {
        features.add('$dailyTokens AI tokens daily (Quick Read only)');
      } else {
        features.add('$dailyTokens AI tokens daily (all study modes)');
      }
    }

    features.add('Daily verse notifications');
    features.add('Learning paths & Study topics');

    if (dailyTokens != null && dailyTokens != -1) {
      features.add('Purchase additional tokens (4 tokens/₹1)');
    }

    if (followUps != null && followUps > 0) {
      if (followUps == -1) {
        features.add('Unlimited follow-ups per study guide');
      } else {
        features.add('$followUps follow-ups per study guide');
      }
    }

    final aiDiscipler = featuresJson['ai_discipler'] as int?;
    if (aiDiscipler != null) {
      if (aiDiscipler == -1) {
        features.add('Unlimited AI Discipler conversations');
      } else {
        features.add('$aiDiscipler AI Discipler conversations/month');
      }
    }

    // Memory verses from SystemConfigService
    try {
      final systemConfig = sl<SystemConfigService>();
      final memoryConfig = systemConfig.config?.memoryVerseConfig;
      if (memoryConfig != null) {
        final memoryVerses = memoryConfig.verseLimits[planCodeLower];
        if (memoryVerses != null) {
          if (memoryVerses == -1) {
            features.add('Unlimited active memory verses');
          } else {
            features.add('$memoryVerses active memory verses');
          }
        }
      }
    } catch (e) {
      Logger.error('Failed to get memory verse limits from system config',
          tag: 'PLAN_FEATURES', error: e);
      _addFallbackMemoryVerses(features, planCodeLower);
    }

    final practiceModes = featuresJson['practice_modes'] as int?;
    if (practiceModes != null) {
      if (dailyTokens == 8) {
        features.add('2 practice modes (Flip Card, Type It Out)');
      } else if (practiceModes == 8) {
        features.add('All 8 practice modes');
      }
    }

    // Practice unlock limits from SystemConfigService
    try {
      final systemConfig = sl<SystemConfigService>();
      final memoryConfig = systemConfig.config?.memoryVerseConfig;
      if (memoryConfig != null) {
        final practiceLimit = memoryConfig.unlockLimits[planCodeLower];
        if (practiceLimit != null) {
          if (practiceLimit == -1) {
            features.add('Unlimited practice sessions per verse');
          } else {
            features.add(
                '$practiceLimit practice session${practiceLimit > 1 ? 's' : ''} per verse per day');
          }
        }
      }
    } catch (e) {
      Logger.error('Failed to get practice unlock limits from system config',
          tag: 'PLAN_FEATURES', error: e);
      _addFallbackPracticeLimit(features, planCodeLower);
    }

    if (dailyTokens != null && dailyTokens > 8) {
      features.add('Study guide history');
    }

    if (features.isEmpty) {
      features.add('Basic Bible study features');
    }

    return features;
  }

  /// Build comparison rows between two plan tiers
  static List<PlanComparisonRow> buildComparisonRows(
    SubscriptionPlanModel? previousPlan,
    SubscriptionPlanModel currentPlan,
  ) {
    final rows = <PlanComparisonRow>[];

    final prevTokens = previousPlan?.features['daily_tokens'] as int?;
    final currTokens = currentPlan.features['daily_tokens'] as int?;
    rows.add(PlanComparisonRow(
      label: 'Daily Tokens',
      previousValue: _formatTokens(prevTokens),
      currentValue: _formatTokens(currTokens),
    ));

    final prevDiscipler = previousPlan?.features['ai_discipler'] as int?;
    final currDiscipler = currentPlan.features['ai_discipler'] as int?;
    if (currDiscipler != null) {
      rows.add(PlanComparisonRow(
        label: 'AI Discipler',
        previousValue: prevDiscipler != null
            ? (prevDiscipler == -1 ? 'Unlimited' : '$prevDiscipler/month')
            : '✗',
        currentValue:
            currDiscipler == -1 ? 'Unlimited' : '$currDiscipler/month',
      ));
    }

    final prevFollowUps = previousPlan?.features['followups'] as int?;
    final currFollowUps = currentPlan.features['followups'] as int?;
    if (currFollowUps != null) {
      rows.add(PlanComparisonRow(
        label: 'Follow-up Questions',
        previousValue: prevFollowUps != null
            ? (prevFollowUps == -1 ? 'Unlimited' : '$prevFollowUps')
            : 'Limited',
        currentValue: currFollowUps == -1 ? 'Unlimited' : '$currFollowUps',
      ));
    }

    // Memory verses from SystemConfigService
    try {
      final systemConfig = sl<SystemConfigService>();
      final memoryConfig = systemConfig.config?.memoryVerseConfig;
      if (memoryConfig != null) {
        final prevPlanCode = previousPlan?.planCode.toLowerCase();
        final currPlanCode = currentPlan.planCode.toLowerCase();
        final prevMem = prevPlanCode != null
            ? memoryConfig.verseLimits[prevPlanCode]
            : null;
        final currMem = memoryConfig.verseLimits[currPlanCode];
        if (currMem != null) {
          rows.add(PlanComparisonRow(
            label: 'Memory Verses',
            previousValue: prevMem != null
                ? (prevMem == -1 ? 'Unlimited' : '$prevMem')
                : '✗',
            currentValue: currMem == -1 ? 'Unlimited' : '$currMem',
          ));
        }
      }
    } catch (e) {
      Logger.error('Failed to get memory verse limits for comparison',
          tag: 'PLAN_FEATURES', error: e);
    }

    return rows;
  }

  static String _formatTokens(int? tokens) {
    if (tokens == null) return '✗';
    if (tokens == -1) return 'Unlimited';
    return '$tokens';
  }

  static void _addFallbackMemoryVerses(List<String> features, String planCode) {
    switch (planCode) {
      case 'free':
        features.add('3 active memory verses');
        break;
      case 'standard':
        features.add('5 active memory verses');
        break;
      case 'plus':
        features.add('10 active memory verses');
        break;
      case 'premium':
        features.add('Unlimited active memory verses');
        break;
    }
  }

  static void _addFallbackPracticeLimit(
      List<String> features, String planCode) {
    switch (planCode) {
      case 'free':
        features.add('1 practice session per verse per day');
        break;
      case 'standard':
        features.add('2 practice sessions per verse per day');
        break;
      case 'plus':
        features.add('3 practice sessions per verse per day');
        break;
      case 'premium':
        features.add('Unlimited practice sessions per verse');
        break;
    }
  }
}

/// Represents a single row in the plan comparison table
class PlanComparisonRow {
  final String label;
  final String previousValue;
  final String currentValue;

  const PlanComparisonRow({
    required this.label,
    required this.previousValue,
    required this.currentValue,
  });
}
