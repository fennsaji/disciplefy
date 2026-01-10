import 'package:equatable/equatable.dart';

/// Represents a single token consumption record from usage history
///
/// Contains comprehensive details about when, where, and how tokens were used,
/// including feature context, study parameters, and content references.
class TokenUsageHistory extends Equatable {
  /// Unique identifier for this usage record
  final String id;

  /// Number of tokens consumed in this operation
  final int tokenCost;

  /// Feature that consumed the tokens (e.g., 'study_generate', 'study_followup')
  final String featureName;

  /// Type of operation performed (e.g., 'study_generation', 'follow_up_question')
  final String operationType;

  /// Study mode if applicable ('quick', 'standard', 'deep', 'lectio', 'sermon')
  final String? studyMode;

  /// Language of the generated content ('en', 'hi', 'ml')
  final String language;

  /// User-friendly title of the content (e.g., 'John 3:16 Study')
  final String? contentTitle;

  /// Scripture reference, topic name, or question text
  final String? contentReference;

  /// Type of input ('scripture', 'topic', 'question')
  final String? inputType;

  /// User's subscription plan at time of consumption
  final String userPlan;

  /// Number of tokens consumed from daily allocation
  final int dailyTokensUsed;

  /// Number of tokens consumed from purchased balance
  final int purchasedTokensUsed;

  /// Timestamp when tokens were consumed
  final DateTime createdAt;

  const TokenUsageHistory({
    required this.id,
    required this.tokenCost,
    required this.featureName,
    required this.operationType,
    this.studyMode,
    required this.language,
    this.contentTitle,
    this.contentReference,
    this.inputType,
    required this.userPlan,
    required this.dailyTokensUsed,
    required this.purchasedTokensUsed,
    required this.createdAt,
  });

  /// Returns user-friendly display name for the feature
  String get featureDisplayName {
    switch (featureName) {
      case 'study_generate':
        return 'Study Generation';
      case 'study_followup':
        return 'Follow-up Question';
      case 'continue_learning':
        return 'Continue Learning';
      default:
        return featureName
            .split('_')
            .map((word) => word[0].toUpperCase() + word.substring(1))
            .join(' ');
    }
  }

  /// Returns user-friendly display name for the operation type
  String get operationTypeDisplayName {
    switch (operationType) {
      case 'study_generation':
        return 'Study Generation';
      case 'follow_up_question':
        return 'Follow-up Question';
      case 'token_consumption':
        return 'Token Usage';
      default:
        return operationType
            .split('_')
            .map((word) => word[0].toUpperCase() + word.substring(1))
            .join(' ');
    }
  }

  /// Returns formatted study mode for display (or N/A if not applicable)
  String get studyModeDisplay {
    if (studyMode == null) return 'N/A';

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
        return studyMode!;
    }
  }

  /// Returns uppercase language code for display
  String get languageDisplay {
    switch (language) {
      case 'en':
        return 'EN';
      case 'hi':
        return 'HI';
      case 'ml':
        return 'ML';
      default:
        return language.toUpperCase();
    }
  }

  /// Returns full language name
  String get languageFullName {
    switch (language) {
      case 'en':
        return 'English';
      case 'hi':
        return 'Hindi';
      case 'ml':
        return 'Malayalam';
      default:
        return language;
    }
  }

  /// Returns the best available title for display
  String get displayTitle {
    if (contentTitle != null && contentTitle!.isNotEmpty) {
      return contentTitle!;
    }
    if (contentReference != null && contentReference!.isNotEmpty) {
      return contentReference!;
    }
    return 'Token Usage';
  }

  /// Returns formatted input type for display
  String get inputTypeDisplay {
    if (inputType == null) return 'N/A';

    switch (inputType) {
      case 'scripture':
        return 'Scripture';
      case 'topic':
        return 'Topic';
      case 'question':
        return 'Question';
      default:
        return inputType!;
    }
  }

  /// Returns whether this usage consumed daily tokens
  bool get usedDailyTokens => dailyTokensUsed > 0;

  /// Returns whether this usage consumed purchased tokens
  bool get usedPurchasedTokens => purchasedTokensUsed > 0;

  /// Returns percentage of tokens from daily allocation
  double get dailyTokensPercentage {
    if (tokenCost == 0) return 0.0;
    return (dailyTokensUsed / tokenCost) * 100;
  }

  /// Returns percentage of tokens from purchased balance
  double get purchasedTokensPercentage {
    if (tokenCost == 0) return 0.0;
    return (purchasedTokensUsed / tokenCost) * 100;
  }

  @override
  List<Object?> get props => [
        id,
        tokenCost,
        featureName,
        operationType,
        studyMode,
        language,
        contentTitle,
        contentReference,
        inputType,
        userPlan,
        dailyTokensUsed,
        purchasedTokensUsed,
        createdAt,
      ];
}
