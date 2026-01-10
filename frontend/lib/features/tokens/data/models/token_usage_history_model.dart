import '../../domain/entities/token_usage_history.dart';

/// Data model for TokenUsageHistory with JSON serialization
class TokenUsageHistoryModel extends TokenUsageHistory {
  const TokenUsageHistoryModel({
    required super.id,
    required super.tokenCost,
    required super.featureName,
    required super.operationType,
    super.studyMode,
    required super.language,
    super.contentTitle,
    super.contentReference,
    super.inputType,
    required super.userPlan,
    required super.dailyTokensUsed,
    required super.purchasedTokensUsed,
    required super.createdAt,
  });

  /// Creates a TokenUsageHistoryModel from JSON response
  factory TokenUsageHistoryModel.fromJson(Map<String, dynamic> json) {
    return TokenUsageHistoryModel(
      id: json['id'] as String,
      tokenCost: json['token_cost'] as int,
      featureName: json['feature_name'] as String,
      operationType: json['operation_type'] as String,
      studyMode: json['study_mode'] as String?,
      language: json['language'] as String,
      contentTitle: json['content_title'] as String?,
      contentReference: json['content_reference'] as String?,
      inputType: json['input_type'] as String?,
      userPlan: json['user_plan'] as String,
      dailyTokensUsed: json['daily_tokens_used'] as int,
      purchasedTokensUsed: json['purchased_tokens_used'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Converts the model to JSON for API requests
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'token_cost': tokenCost,
      'feature_name': featureName,
      'operation_type': operationType,
      'study_mode': studyMode,
      'language': language,
      'content_title': contentTitle,
      'content_reference': contentReference,
      'input_type': inputType,
      'user_plan': userPlan,
      'daily_tokens_used': dailyTokensUsed,
      'purchased_tokens_used': purchasedTokensUsed,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Creates a copy with modified fields
  TokenUsageHistoryModel copyWith({
    String? id,
    int? tokenCost,
    String? featureName,
    String? operationType,
    String? studyMode,
    String? language,
    String? contentTitle,
    String? contentReference,
    String? inputType,
    String? userPlan,
    int? dailyTokensUsed,
    int? purchasedTokensUsed,
    DateTime? createdAt,
  }) {
    return TokenUsageHistoryModel(
      id: id ?? this.id,
      tokenCost: tokenCost ?? this.tokenCost,
      featureName: featureName ?? this.featureName,
      operationType: operationType ?? this.operationType,
      studyMode: studyMode ?? this.studyMode,
      language: language ?? this.language,
      contentTitle: contentTitle ?? this.contentTitle,
      contentReference: contentReference ?? this.contentReference,
      inputType: inputType ?? this.inputType,
      userPlan: userPlan ?? this.userPlan,
      dailyTokensUsed: dailyTokensUsed ?? this.dailyTokensUsed,
      purchasedTokensUsed: purchasedTokensUsed ?? this.purchasedTokensUsed,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
