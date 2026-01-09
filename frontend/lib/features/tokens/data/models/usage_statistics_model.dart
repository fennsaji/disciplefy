import '../../domain/entities/usage_statistics.dart';

/// Data model for FeatureBreakdown with JSON serialization
class FeatureBreakdownModel extends FeatureBreakdown {
  const FeatureBreakdownModel({
    required super.featureName,
    required super.tokenCount,
    required super.operationCount,
  });

  factory FeatureBreakdownModel.fromJson(Map<String, dynamic> json) {
    return FeatureBreakdownModel(
      featureName: json['feature_name'] as String,
      tokenCount: json['token_count'] as int,
      operationCount: json['operation_count'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'feature_name': featureName,
      'token_count': tokenCount,
      'operation_count': operationCount,
    };
  }
}

/// Data model for LanguageBreakdown with JSON serialization
class LanguageBreakdownModel extends LanguageBreakdown {
  const LanguageBreakdownModel({
    required super.language,
    required super.tokenCount,
  });

  factory LanguageBreakdownModel.fromJson(Map<String, dynamic> json) {
    return LanguageBreakdownModel(
      language: json['language'] as String,
      tokenCount: json['token_count'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'language': language,
      'token_count': tokenCount,
    };
  }
}

/// Data model for StudyModeBreakdown with JSON serialization
class StudyModeBreakdownModel extends StudyModeBreakdown {
  const StudyModeBreakdownModel({
    required super.studyMode,
    required super.tokenCount,
  });

  factory StudyModeBreakdownModel.fromJson(Map<String, dynamic> json) {
    return StudyModeBreakdownModel(
      studyMode: json['study_mode'] as String,
      tokenCount: json['token_count'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'study_mode': studyMode,
      'token_count': tokenCount,
    };
  }
}

/// Data model for UsageStatistics with JSON serialization
class UsageStatisticsModel extends UsageStatistics {
  const UsageStatisticsModel({
    required super.totalTokens,
    required super.totalOperations,
    required super.dailyTokensConsumed,
    required super.purchasedTokensConsumed,
    super.mostUsedFeature,
    super.mostUsedLanguage,
    super.mostUsedMode,
    required super.featureBreakdown,
    required super.languageBreakdown,
    required super.studyModeBreakdown,
    super.firstUsageDate,
    super.lastUsageDate,
  });

  /// Creates a UsageStatisticsModel from JSON response
  factory UsageStatisticsModel.fromJson(Map<String, dynamic> json) {
    // Parse feature breakdown
    List<FeatureBreakdown> featureBreakdown = [];
    if (json['feature_breakdown'] != null) {
      final breakdownData = json['feature_breakdown'];
      if (breakdownData is List) {
        featureBreakdown = breakdownData
            .map((item) => FeatureBreakdownModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    }

    // Parse language breakdown
    List<LanguageBreakdown> languageBreakdown = [];
    if (json['language_breakdown'] != null) {
      final breakdownData = json['language_breakdown'];
      if (breakdownData is List) {
        languageBreakdown = breakdownData
            .map((item) => LanguageBreakdownModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    }

    // Parse study mode breakdown
    List<StudyModeBreakdown> studyModeBreakdown = [];
    if (json['study_mode_breakdown'] != null) {
      final breakdownData = json['study_mode_breakdown'];
      if (breakdownData is List) {
        studyModeBreakdown = breakdownData
            .map((item) => StudyModeBreakdownModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    }

    return UsageStatisticsModel(
      totalTokens: json['total_tokens'] as int? ?? 0,
      totalOperations: json['total_operations'] as int? ?? 0,
      dailyTokensConsumed: json['daily_tokens_consumed'] as int? ?? 0,
      purchasedTokensConsumed: json['purchased_tokens_consumed'] as int? ?? 0,
      mostUsedFeature: json['most_used_feature'] as String?,
      mostUsedLanguage: json['most_used_language'] as String?,
      mostUsedMode: json['most_used_mode'] as String?,
      featureBreakdown: featureBreakdown,
      languageBreakdown: languageBreakdown,
      studyModeBreakdown: studyModeBreakdown,
      firstUsageDate: json['first_usage_date'] != null
          ? DateTime.parse(json['first_usage_date'] as String)
          : null,
      lastUsageDate: json['last_usage_date'] != null
          ? DateTime.parse(json['last_usage_date'] as String)
          : null,
    );
  }

  /// Converts the model to JSON for API requests
  Map<String, dynamic> toJson() {
    return {
      'total_tokens': totalTokens,
      'total_operations': totalOperations,
      'daily_tokens_consumed': dailyTokensConsumed,
      'purchased_tokens_consumed': purchasedTokensConsumed,
      'most_used_feature': mostUsedFeature,
      'most_used_language': mostUsedLanguage,
      'most_used_mode': mostUsedMode,
      'feature_breakdown': featureBreakdown
          .map((fb) => (fb as FeatureBreakdownModel).toJson())
          .toList(),
      'language_breakdown': languageBreakdown
          .map((lb) => (lb as LanguageBreakdownModel).toJson())
          .toList(),
      'study_mode_breakdown': studyModeBreakdown
          .map((smb) => (smb as StudyModeBreakdownModel).toJson())
          .toList(),
      'first_usage_date': firstUsageDate?.toIso8601String(),
      'last_usage_date': lastUsageDate?.toIso8601String(),
    };
  }

  /// Creates an empty statistics model
  factory UsageStatisticsModel.empty() {
    return const UsageStatisticsModel(
      totalTokens: 0,
      totalOperations: 0,
      dailyTokensConsumed: 0,
      purchasedTokensConsumed: 0,
      featureBreakdown: [],
      languageBreakdown: [],
      studyModeBreakdown: [],
    );
  }
}
