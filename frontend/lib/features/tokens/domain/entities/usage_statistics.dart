import 'package:equatable/equatable.dart';

/// Breakdown of token usage by feature
class FeatureBreakdown extends Equatable {
  /// Feature name (e.g., 'study_generate', 'study_followup')
  final String featureName;

  /// Total tokens consumed by this feature
  final int tokenCount;

  /// Number of operations performed
  final int operationCount;

  const FeatureBreakdown({
    required this.featureName,
    required this.tokenCount,
    required this.operationCount,
  });

  /// Returns user-friendly display name for the feature
  String get displayName {
    switch (featureName) {
      case 'study_generate':
        return 'Study Generation';
      case 'study_followup':
        return 'Follow-up Questions';
      case 'continue_learning':
        return 'Continue Learning';
      default:
        return featureName
            .split('_')
            .where((word) => word.isNotEmpty)
            .map((word) => word[0].toUpperCase() + word.substring(1))
            .join(' ');
    }
  }

  /// Returns average tokens per operation
  double get averageTokensPerOperation {
    if (operationCount == 0) return 0.0;
    return tokenCount / operationCount;
  }

  @override
  List<Object?> get props => [featureName, tokenCount, operationCount];
}

/// Breakdown of token usage by language
class LanguageBreakdown extends Equatable {
  /// Language code ('en', 'hi', 'ml')
  final String language;

  /// Total tokens consumed in this language
  final int tokenCount;

  const LanguageBreakdown({
    required this.language,
    required this.tokenCount,
  });

  /// Returns user-friendly display name for the language
  String get displayName {
    switch (language) {
      case 'en':
        return 'English';
      case 'hi':
        return 'Hindi';
      case 'ml':
        return 'Malayalam';
      default:
        return language.toUpperCase();
    }
  }

  /// Returns short language code for display
  String get shortCode => language.toUpperCase();

  @override
  List<Object?> get props => [language, tokenCount];
}

/// Breakdown of token usage by study mode
class StudyModeBreakdown extends Equatable {
  /// Study mode ('quick', 'standard', 'deep', 'lectio', 'sermon')
  final String studyMode;

  /// Total tokens consumed in this mode
  final int tokenCount;

  const StudyModeBreakdown({
    required this.studyMode,
    required this.tokenCount,
  });

  /// Returns user-friendly display name for the study mode
  String get displayName {
    switch (studyMode) {
      case 'quick':
        return 'Quick';
      case 'standard':
        return 'Standard';
      case 'deep':
        return 'Deep Dive';
      case 'lectio':
        return 'Lectio Divina';
      case 'sermon':
        return 'Sermon Outline';
      default:
        return studyMode;
    }
  }

  @override
  List<Object?> get props => [studyMode, tokenCount];
}

/// Aggregated statistics for token usage
///
/// Provides comprehensive analytics including total consumption,
/// breakdowns by feature/language/mode, and usage patterns.
class UsageStatistics extends Equatable {
  /// Total tokens consumed across all operations
  final int totalTokens;

  /// Total number of operations performed
  final int totalOperations;

  /// Tokens consumed from daily allocation
  final int dailyTokensConsumed;

  /// Tokens consumed from purchased balance
  final int purchasedTokensConsumed;

  /// Most frequently used feature (null if no usage)
  final String? mostUsedFeature;

  /// Most frequently used language (null if no usage)
  final String? mostUsedLanguage;

  /// Most frequently used study mode (null if no usage)
  final String? mostUsedMode;

  /// Breakdown of usage by feature
  final List<FeatureBreakdown> featureBreakdown;

  /// Breakdown of usage by language
  final List<LanguageBreakdown> languageBreakdown;

  /// Breakdown of usage by study mode
  final List<StudyModeBreakdown> studyModeBreakdown;

  /// Date of first token usage (null if no usage)
  final DateTime? firstUsageDate;

  /// Date of most recent token usage (null if no usage)
  final DateTime? lastUsageDate;

  const UsageStatistics({
    required this.totalTokens,
    required this.totalOperations,
    required this.dailyTokensConsumed,
    required this.purchasedTokensConsumed,
    this.mostUsedFeature,
    this.mostUsedLanguage,
    this.mostUsedMode,
    required this.featureBreakdown,
    required this.languageBreakdown,
    required this.studyModeBreakdown,
    this.firstUsageDate,
    this.lastUsageDate,
  });

  /// Returns whether user has any usage history
  bool get hasUsageHistory => totalOperations > 0;

  /// Returns average tokens consumed per operation
  double get averageTokensPerOperation {
    if (totalOperations == 0) return 0.0;
    return totalTokens / totalOperations;
  }

  /// Returns percentage of tokens from daily allocation
  double get dailyTokensPercentage {
    if (totalTokens == 0) return 0.0;
    return (dailyTokensConsumed / totalTokens) * 100;
  }

  /// Returns percentage of tokens from purchased balance
  double get purchasedTokensPercentage {
    if (totalTokens == 0) return 0.0;
    return (purchasedTokensConsumed / totalTokens) * 100;
  }

  /// Returns display name for most used feature
  String get mostUsedFeatureDisplay {
    if (mostUsedFeature == null) return 'N/A';

    switch (mostUsedFeature) {
      case 'study_generate':
        return 'Study Generation';
      case 'study_followup':
        return 'Follow-up Questions';
      case 'continue_learning':
        return 'Continue Learning';
      default:
        return mostUsedFeature!
            .split('_')
            .where((word) => word.isNotEmpty)
            .map((word) => word[0].toUpperCase() + word.substring(1))
            .join(' ');
    }
  }

  /// Returns display name for most used language
  String get mostUsedLanguageDisplay {
    if (mostUsedLanguage == null) return 'N/A';

    switch (mostUsedLanguage) {
      case 'en':
        return 'English';
      case 'hi':
        return 'Hindi';
      case 'ml':
        return 'Malayalam';
      default:
        return mostUsedLanguage!.toUpperCase();
    }
  }

  /// Returns display name for most used study mode
  String get mostUsedModeDisplay {
    if (mostUsedMode == null) return 'N/A';

    switch (mostUsedMode) {
      case 'quick':
        return 'Quick';
      case 'standard':
        return 'Standard';
      case 'deep':
        return 'Deep Dive';
      case 'lectio':
        return 'Lectio Divina';
      case 'sermon':
        return 'Sermon Outline';
      default:
        return mostUsedMode!;
    }
  }

  /// Returns whether feature breakdown is available
  bool get hasFeatureBreakdown => featureBreakdown.isNotEmpty;

  /// Returns whether language breakdown is available
  bool get hasLanguageBreakdown => languageBreakdown.isNotEmpty;

  /// Returns whether study mode breakdown is available
  bool get hasStudyModeBreakdown => studyModeBreakdown.isNotEmpty;

  /// Returns top N features by token consumption
  List<FeatureBreakdown> getTopFeatures(int n) {
    final sorted = List<FeatureBreakdown>.from(featureBreakdown)
      ..sort((a, b) => b.tokenCount.compareTo(a.tokenCount));
    return sorted.take(n).toList();
  }

  @override
  List<Object?> get props => [
        totalTokens,
        totalOperations,
        dailyTokensConsumed,
        purchasedTokensConsumed,
        mostUsedFeature,
        mostUsedLanguage,
        mostUsedMode,
        featureBreakdown,
        languageBreakdown,
        studyModeBreakdown,
        firstUsageDate,
        lastUsageDate,
      ];
}
