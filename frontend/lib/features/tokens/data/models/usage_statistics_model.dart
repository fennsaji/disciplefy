import '../../../../core/utils/logger.dart';
import '../../domain/entities/usage_statistics.dart';

/// Helper function to safely parse integer values from JSON.
///
/// Accepts [num] or [String], returns parsed [int] or [defaultValue].
/// Logs warnings when parsing fails or type is invalid.
///
/// Parameters:
/// - [value]: The dynamic value to parse (can be int, num, String, or null)
/// - [defaultValue]: Fallback value when parsing fails (default: 0)
/// - [fieldName]: Optional field name for logging context
///
/// Returns:
/// - Parsed integer value, or [defaultValue] if parsing fails
int _safeParseInt(dynamic value, {int defaultValue = 0, String? fieldName}) {
  if (value == null) return defaultValue;

  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) {
    final parsed = int.tryParse(value);
    if (parsed != null) return parsed;

    Logger.warning(
        '⚠️ [USAGE_STATISTICS_MODEL] Failed to parse int from string: "$value" for field: ${fieldName ?? "unknown"}');
    return defaultValue;
  }

  Logger.warning(
      '⚠️ [USAGE_STATISTICS_MODEL] Invalid type for int field: ${value.runtimeType} (value: $value) for field: ${fieldName ?? "unknown"}');
  return defaultValue;
}

/// Helper function to safely parse string values from JSON.
///
/// Validates non-empty strings, returns null or [defaultValue] for invalid values.
/// Logs warnings when value is invalid or empty.
///
/// Parameters:
/// - [value]: The dynamic value to parse (expected to be String or null)
/// - [defaultValue]: Optional fallback value for invalid/empty strings
/// - [fieldName]: Optional field name for logging context
///
/// Returns:
/// - Valid non-empty string, [defaultValue], or null if no default provided
String? _safeParseString(dynamic value,
    {String? defaultValue, String? fieldName}) {
  if (value == null) return defaultValue;

  if (value is String) {
    if (value.trim().isEmpty) {
      if (defaultValue != null) {
        Logger.warning(
            '⚠️ [USAGE_STATISTICS_MODEL] Empty string for field: ${fieldName ?? "unknown"}, using default');
      }
      return defaultValue;
    }
    return value;
  }

  Logger.warning(
      '⚠️ [USAGE_STATISTICS_MODEL] Invalid type for string field: ${value.runtimeType} (value: $value) for field: ${fieldName ?? "unknown"}');
  return defaultValue;
}

/// Data model for FeatureBreakdown with JSON serialization.
///
/// Represents token usage statistics grouped by feature (e.g., study_generate, study_followup).
class FeatureBreakdownModel extends FeatureBreakdown {
  /// Creates a [FeatureBreakdownModel] instance.
  ///
  /// All parameters are required:
  /// - [featureName]: Name of the feature (e.g., 'study_generate')
  /// - [tokenCount]: Total tokens consumed by this feature
  /// - [operationCount]: Number of times this feature was used
  const FeatureBreakdownModel({
    required super.featureName,
    required super.tokenCount,
    required super.operationCount,
  });

  /// Creates a [FeatureBreakdownModel] from a JSON map.
  ///
  /// Uses safe parsing to handle type drift and invalid data.
  /// Missing or invalid fields use default values (0 for numbers, '' for strings).
  ///
  /// Parameters:
  /// - [json]: Map containing 'feature_name', 'token_count', 'operation_count'
  ///
  /// Returns:
  /// - A new [FeatureBreakdownModel] instance with parsed data
  factory FeatureBreakdownModel.fromJson(Map<String, dynamic> json) {
    final featureName =
        _safeParseString(json['feature_name'], fieldName: 'feature_name') ?? '';
    final tokenCount =
        _safeParseInt(json['token_count'], fieldName: 'token_count');
    final operationCount =
        _safeParseInt(json['operation_count'], fieldName: 'operation_count');

    return FeatureBreakdownModel(
      featureName: featureName,
      tokenCount: tokenCount,
      operationCount: operationCount,
    );
  }

  /// Converts this model to a JSON map.
  ///
  /// Returns:
  /// - A map with keys: 'feature_name', 'token_count', 'operation_count'
  Map<String, dynamic> toJson() {
    return {
      'feature_name': featureName,
      'token_count': tokenCount,
      'operation_count': operationCount,
    };
  }
}

/// Data model for LanguageBreakdown with JSON serialization.
///
/// Represents token usage statistics grouped by language (e.g., 'en', 'hi', 'ml').
class LanguageBreakdownModel extends LanguageBreakdown {
  /// Creates a [LanguageBreakdownModel] instance.
  ///
  /// Parameters:
  /// - [language]: Language code (e.g., 'en', 'hi', 'ml')
  /// - [tokenCount]: Total tokens consumed for this language
  const LanguageBreakdownModel({
    required super.language,
    required super.tokenCount,
  });

  /// Creates a [LanguageBreakdownModel] from a JSON map.
  ///
  /// Uses safe parsing to handle type drift and invalid data.
  /// Missing or invalid fields use default values.
  ///
  /// Parameters:
  /// - [json]: Map containing 'language', 'token_count'
  ///
  /// Returns:
  /// - A new [LanguageBreakdownModel] instance with parsed data
  factory LanguageBreakdownModel.fromJson(Map<String, dynamic> json) {
    final language =
        _safeParseString(json['language'], fieldName: 'language') ?? '';
    final tokenCount =
        _safeParseInt(json['token_count'], fieldName: 'token_count');

    return LanguageBreakdownModel(
      language: language,
      tokenCount: tokenCount,
    );
  }

  /// Converts this model to a JSON map.
  ///
  /// Returns:
  /// - A map with keys: 'language', 'token_count'
  Map<String, dynamic> toJson() {
    return {
      'language': language,
      'token_count': tokenCount,
    };
  }
}

/// Data model for StudyModeBreakdown with JSON serialization.
///
/// Represents token usage statistics grouped by study mode (e.g., 'quick', 'standard', 'deep').
class StudyModeBreakdownModel extends StudyModeBreakdown {
  /// Creates a [StudyModeBreakdownModel] instance.
  ///
  /// Parameters:
  /// - [studyMode]: Study mode name (e.g., 'quick', 'standard', 'deep', 'lectio', 'sermon')
  /// - [tokenCount]: Total tokens consumed for this study mode
  const StudyModeBreakdownModel({
    required super.studyMode,
    required super.tokenCount,
  });

  /// Creates a [StudyModeBreakdownModel] from a JSON map.
  ///
  /// Uses safe parsing to handle type drift and invalid data.
  /// Missing or invalid fields use default values.
  ///
  /// Parameters:
  /// - [json]: Map containing 'study_mode', 'token_count'
  ///
  /// Returns:
  /// - A new [StudyModeBreakdownModel] instance with parsed data
  factory StudyModeBreakdownModel.fromJson(Map<String, dynamic> json) {
    final studyMode =
        _safeParseString(json['study_mode'], fieldName: 'study_mode') ?? '';
    final tokenCount =
        _safeParseInt(json['token_count'], fieldName: 'token_count');

    return StudyModeBreakdownModel(
      studyMode: studyMode,
      tokenCount: tokenCount,
    );
  }

  /// Converts this model to a JSON map.
  ///
  /// Returns:
  /// - A map with keys: 'study_mode', 'token_count'
  Map<String, dynamic> toJson() {
    return {
      'study_mode': studyMode,
      'token_count': tokenCount,
    };
  }
}

/// Data model for UsageStatistics with JSON serialization.
///
/// Aggregates comprehensive token usage statistics including totals, breakdowns by feature/language/mode,
/// and consumption tracking for daily vs purchased tokens.
class UsageStatisticsModel extends UsageStatistics {
  /// Creates a [UsageStatisticsModel] instance.
  ///
  /// Required parameters:
  /// - [totalTokens]: Total tokens consumed across all operations
  /// - [totalOperations]: Total number of operations performed
  /// - [dailyTokensConsumed]: Tokens from daily free allowance
  /// - [purchasedTokensConsumed]: Tokens from purchased packages
  /// - [featureBreakdown]: Token usage grouped by feature
  /// - [languageBreakdown]: Token usage grouped by language
  /// - [studyModeBreakdown]: Token usage grouped by study mode
  ///
  /// Optional parameters:
  /// - [mostUsedFeature]: Feature with highest usage count
  /// - [mostUsedLanguage]: Language with highest usage count
  /// - [mostUsedMode]: Study mode with highest usage count
  /// - [firstUsageDate]: Timestamp of first token usage
  /// - [lastUsageDate]: Timestamp of most recent token usage
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

  /// Creates a [UsageStatisticsModel] from a JSON response.
  ///
  /// Robustly parses all fields with comprehensive error handling:
  /// - Uses safe parsing for all numeric and string fields
  /// - Gracefully handles malformed breakdown items (skips invalid entries)
  /// - Logs warnings for type drift or parsing failures
  /// - Returns default values for missing/invalid data
  ///
  /// Parameters:
  /// - [json]: Map containing statistics data from API response
  ///
  /// Returns:
  /// - A new [UsageStatisticsModel] instance with validated data
  ///
  /// Expected JSON structure:
  /// ```json
  /// {
  ///   "total_tokens": 1500,
  ///   "total_operations": 45,
  ///   "daily_tokens_consumed": 1000,
  ///   "purchased_tokens_consumed": 500,
  ///   "most_used_feature": "study_generate",
  ///   "most_used_language": "en",
  ///   "most_used_mode": "standard",
  ///   "feature_breakdown": [{...}],
  ///   "language_breakdown": [{...}],
  ///   "study_mode_breakdown": [{...}],
  ///   "first_usage_date": "2024-01-01T00:00:00Z",
  ///   "last_usage_date": "2024-01-10T12:30:00Z"
  /// }
  /// ```
  factory UsageStatisticsModel.fromJson(Map<String, dynamic> json) {
    // Parse feature breakdown with error handling
    List<FeatureBreakdown> featureBreakdown = [];
    if (json['feature_breakdown'] != null) {
      final breakdownData = json['feature_breakdown'];
      if (breakdownData is List) {
        featureBreakdown = breakdownData
            .map((item) {
              try {
                if (item is Map<String, dynamic>) {
                  return FeatureBreakdownModel.fromJson(item);
                } else {
                  Logger.warning(
                      '⚠️ [USAGE_STATISTICS_MODEL] Skipping malformed feature breakdown item: invalid type ${item.runtimeType}');
                  return null;
                }
              } catch (e) {
                Logger.warning(
                    '⚠️ [USAGE_STATISTICS_MODEL] Error parsing feature breakdown item: $e');
                return null;
              }
            })
            .whereType<FeatureBreakdown>()
            .toList();
      }
    }

    // Parse language breakdown with error handling
    List<LanguageBreakdown> languageBreakdown = [];
    if (json['language_breakdown'] != null) {
      final breakdownData = json['language_breakdown'];
      if (breakdownData is List) {
        languageBreakdown = breakdownData
            .map((item) {
              try {
                if (item is Map<String, dynamic>) {
                  return LanguageBreakdownModel.fromJson(item);
                } else {
                  Logger.warning(
                      '⚠️ [USAGE_STATISTICS_MODEL] Skipping malformed language breakdown item: invalid type ${item.runtimeType}');
                  return null;
                }
              } catch (e) {
                Logger.warning(
                    '⚠️ [USAGE_STATISTICS_MODEL] Error parsing language breakdown item: $e');
                return null;
              }
            })
            .whereType<LanguageBreakdown>()
            .toList();
      }
    }

    // Parse study mode breakdown with error handling
    List<StudyModeBreakdown> studyModeBreakdown = [];
    if (json['study_mode_breakdown'] != null) {
      final breakdownData = json['study_mode_breakdown'];
      if (breakdownData is List) {
        studyModeBreakdown = breakdownData
            .map((item) {
              try {
                if (item is Map<String, dynamic>) {
                  return StudyModeBreakdownModel.fromJson(item);
                } else {
                  Logger.warning(
                      '⚠️ [USAGE_STATISTICS_MODEL] Skipping malformed study mode breakdown item: invalid type ${item.runtimeType}');
                  return null;
                }
              } catch (e) {
                Logger.warning(
                    '⚠️ [USAGE_STATISTICS_MODEL] Error parsing study mode breakdown item: $e');
                return null;
              }
            })
            .whereType<StudyModeBreakdown>()
            .toList();
      }
    }

    // Parse dates with error handling
    DateTime? firstUsageDate;
    if (json['first_usage_date'] != null) {
      try {
        final dateValue = json['first_usage_date'];
        if (dateValue is String) {
          firstUsageDate = DateTime.parse(dateValue);
        } else {
          Logger.warning(
              '⚠️ [USAGE_STATISTICS_MODEL] Invalid type for first_usage_date: ${dateValue.runtimeType}');
        }
      } catch (e) {
        Logger.warning(
            '⚠️ [USAGE_STATISTICS_MODEL] Error parsing first_usage_date: $e');
      }
    }

    DateTime? lastUsageDate;
    if (json['last_usage_date'] != null) {
      try {
        final dateValue = json['last_usage_date'];
        if (dateValue is String) {
          lastUsageDate = DateTime.parse(dateValue);
        } else {
          Logger.warning(
              '⚠️ [USAGE_STATISTICS_MODEL] Invalid type for last_usage_date: ${dateValue.runtimeType}');
        }
      } catch (e) {
        Logger.warning(
            '⚠️ [USAGE_STATISTICS_MODEL] Error parsing last_usage_date: $e');
      }
    }

    return UsageStatisticsModel(
      totalTokens:
          _safeParseInt(json['total_tokens'], fieldName: 'total_tokens'),
      totalOperations: _safeParseInt(json['total_operations'],
          fieldName: 'total_operations'),
      dailyTokensConsumed: _safeParseInt(json['daily_tokens_consumed'],
          fieldName: 'daily_tokens_consumed'),
      purchasedTokensConsumed: _safeParseInt(json['purchased_tokens_consumed'],
          fieldName: 'purchased_tokens_consumed'),
      mostUsedFeature: _safeParseString(json['most_used_feature'],
          fieldName: 'most_used_feature'),
      mostUsedLanguage: _safeParseString(json['most_used_language'],
          fieldName: 'most_used_language'),
      mostUsedMode:
          _safeParseString(json['most_used_mode'], fieldName: 'most_used_mode'),
      featureBreakdown: featureBreakdown,
      languageBreakdown: languageBreakdown,
      studyModeBreakdown: studyModeBreakdown,
      firstUsageDate: firstUsageDate,
      lastUsageDate: lastUsageDate,
    );
  }

  /// Converts this model to a JSON map.
  ///
  /// Serializes all fields including nested breakdown lists.
  /// Handles both model instances and domain entities in breakdown arrays.
  ///
  /// Returns:
  /// - A map with all statistics fields in snake_case format
  Map<String, dynamic> toJson() {
    return {
      'total_tokens': totalTokens,
      'total_operations': totalOperations,
      'daily_tokens_consumed': dailyTokensConsumed,
      'purchased_tokens_consumed': purchasedTokensConsumed,
      'most_used_feature': mostUsedFeature,
      'most_used_language': mostUsedLanguage,
      'most_used_mode': mostUsedMode,
      'feature_breakdown': featureBreakdown.map((fb) {
        if (fb is FeatureBreakdownModel) {
          return fb.toJson();
        }
        // Build map from entity's public fields
        return {
          'feature_name': fb.featureName,
          'token_count': fb.tokenCount,
          'operation_count': fb.operationCount,
        };
      }).toList(),
      'language_breakdown': languageBreakdown.map((lb) {
        if (lb is LanguageBreakdownModel) {
          return lb.toJson();
        }
        // Build map from entity's public fields
        return {
          'language': lb.language,
          'token_count': lb.tokenCount,
        };
      }).toList(),
      'study_mode_breakdown': studyModeBreakdown.map((smb) {
        if (smb is StudyModeBreakdownModel) {
          return smb.toJson();
        }
        // Build map from entity's public fields
        return {
          'study_mode': smb.studyMode,
          'token_count': smb.tokenCount,
        };
      }).toList(),
      'first_usage_date': firstUsageDate?.toIso8601String(),
      'last_usage_date': lastUsageDate?.toIso8601String(),
    };
  }

  /// Creates an empty statistics model with all values initialized to zero.
  ///
  /// Useful for initial state, loading placeholders, or when no usage data exists.
  ///
  /// Returns:
  /// - A [UsageStatisticsModel] with all numeric fields set to 0,
  ///   all breakdowns set to empty lists, and optional fields null
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
