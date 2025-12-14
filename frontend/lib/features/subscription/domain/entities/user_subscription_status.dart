import 'package:equatable/equatable.dart';

/// Entity representing the user's current subscription status
/// including trial period and grace period information for Standard plan,
/// as well as Premium trial information for new users.
///
/// This is used to determine:
/// - Current plan (free, standard, premium)
/// - Whether the Standard trial is active (before March 31, 2025)
/// - Whether user is in grace period (April 1-7, 2025)
/// - Whether user was eligible for trial (signed up before March 31)
/// - Days remaining until trial/grace period ends
/// - Whether user needs to subscribe
/// - Premium trial status (7-day trial for new users after April 1st)
class UserSubscriptionStatus extends Equatable {
  /// Current effective plan: 'free', 'standard', or 'premium'
  final String currentPlan;

  /// Whether the Standard plan trial period is still active (before March 31)
  final bool isTrialActive;

  /// Number of days until the trial ends (0 if trial ended)
  final int daysUntilTrialEnd;

  /// Whether user has an active subscription
  final bool hasSubscription;

  /// The plan type of the active subscription ('standard' or 'premium')
  final String? subscriptionPlanType;

  /// The status of the active subscription
  final String? subscriptionStatus;

  /// The date when the Standard trial ends (March 31, 2025)
  final DateTime? trialEndDate;

  /// Whether user is in the grace period (April 1-7, 2025)
  final bool isInGracePeriod;

  /// Days remaining in grace period (0 if not in grace period)
  final int graceDaysRemaining;

  /// Whether user was eligible for trial (signed up before March 31, 2025)
  final bool wasEligibleForTrial;

  /// User's account creation date
  final DateTime? userCreatedAt;

  /// The date when the grace period ends (April 7, 2025)
  final DateTime? gracePeriodEndDate;

  /// Whether user is currently in Premium trial (7-day trial for new users)
  final bool isInPremiumTrial;

  /// Days remaining in Premium trial (0 if not in trial)
  final int premiumTrialDaysRemaining;

  /// Whether user has already used their Premium trial
  final bool hasUsedPremiumTrial;

  /// Whether user can start a Premium trial (new user after April 1st, hasn't used trial)
  final bool canStartPremiumTrial;

  /// The date when Premium trial started
  final DateTime? premiumTrialStartedAt;

  /// The date when Premium trial ends
  final DateTime? premiumTrialEndAt;

  const UserSubscriptionStatus({
    required this.currentPlan,
    required this.isTrialActive,
    required this.daysUntilTrialEnd,
    required this.hasSubscription,
    this.subscriptionPlanType,
    this.subscriptionStatus,
    this.trialEndDate,
    this.isInGracePeriod = false,
    this.graceDaysRemaining = 0,
    this.wasEligibleForTrial = true,
    this.userCreatedAt,
    this.gracePeriodEndDate,
    this.isInPremiumTrial = false,
    this.premiumTrialDaysRemaining = 0,
    this.hasUsedPremiumTrial = false,
    this.canStartPremiumTrial = false,
    this.premiumTrialStartedAt,
    this.premiumTrialEndAt,
  });

  /// Whether the user is on the free plan
  bool get isFreePlan => currentPlan == 'free';

  /// Whether the user is on the standard plan
  bool get isStandardPlan => currentPlan == 'standard';

  /// Whether the user is on the premium plan
  bool get isPremiumPlan => currentPlan == 'premium';

  /// Whether the user needs to subscribe to continue using Standard features.
  /// True when:
  /// - User is on Standard plan
  /// - Trial period has ended
  /// - User doesn't have an active Standard subscription
  bool get needsSubscription =>
      currentPlan == 'standard' && !isTrialActive && !hasSubscription;

  /// Whether the user is currently in the trial period
  bool get isInTrialPeriod => currentPlan == 'standard' && isTrialActive;

  /// Whether the trial is ending soon (within 7 days)
  bool get isTrialEndingSoon =>
      isInTrialPeriod && daysUntilTrialEnd <= 7 && daysUntilTrialEnd > 0;

  /// Whether the user's trial has expired (was eligible but no longer has access)
  /// True when user was eligible for trial, but trial and grace period ended,
  /// and they don't have an active subscription
  bool get hasTrialExpired =>
      wasEligibleForTrial &&
      !isTrialActive &&
      !isInGracePeriod &&
      !hasSubscription &&
      isFreePlan;

  /// Whether user is a new user who never had trial access
  /// (signed up after March 31, 2025)
  bool get isNewUserWithoutTrial => !wasEligibleForTrial && isFreePlan;

  /// Whether user needs to subscribe urgently (grace period ending soon)
  bool get isGracePeriodUrgent =>
      isInGracePeriod && graceDaysRemaining <= 3 && graceDaysRemaining > 0;

  /// Whether to show the subscription banner.
  /// Shows when:
  /// - Trial is ending soon (< 7 days remaining)
  /// - In grace period
  /// - Trial has ended and user needs to subscribe
  /// - New user without trial (show promo)
  bool get shouldShowSubscriptionBanner =>
      needsSubscription ||
      isTrialEndingSoon ||
      isInGracePeriod ||
      hasTrialExpired ||
      isNewUserWithoutTrial;

  /// Whether to show the Premium trial banner
  /// Shows when user can start Premium trial or is in Premium trial
  bool get shouldShowPremiumTrialBanner =>
      canStartPremiumTrial || isInPremiumTrial;

  /// Get a user-friendly message about their subscription status
  String get statusMessage {
    if (isPremiumPlan) {
      if (isInPremiumTrial) {
        if (premiumTrialDaysRemaining <= 1) {
          return 'Premium trial ends today!';
        }
        return 'Premium trial: $premiumTrialDaysRemaining days left';
      }
      return 'You have Premium access';
    } else if (isStandardPlan) {
      if (hasSubscription) {
        return 'Standard subscription active';
      } else if (isInGracePeriod) {
        if (graceDaysRemaining <= 1) {
          return 'Grace period ends today!';
        } else {
          return 'Grace period: $graceDaysRemaining days to subscribe';
        }
      } else if (isTrialActive) {
        if (daysUntilTrialEnd <= 1) {
          return 'Free trial ends today!';
        } else if (daysUntilTrialEnd <= 7) {
          return 'Free trial ends in $daysUntilTrialEnd days';
        } else {
          return 'Enjoying Standard (free until March 31st)';
        }
      } else {
        return 'Subscribe to continue Standard features';
      }
    } else if (isFreePlan) {
      if (canStartPremiumTrial) {
        return 'Start your FREE 7-day Premium trial!';
      } else if (hasTrialExpired) {
        return 'Your trial has ended';
      } else if (isNewUserWithoutTrial) {
        return 'Upgrade to unlock Standard features';
      }
      return 'Free plan';
    } else {
      return 'Free plan';
    }
  }

  /// Get a formatted trial end date string
  String? get formattedTrialEndDate {
    if (trialEndDate == null) return null;

    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];

    return '${months[trialEndDate!.month - 1]} ${trialEndDate!.day}, ${trialEndDate!.year}';
  }

  /// Get a formatted grace period end date string
  String? get formattedGracePeriodEndDate {
    if (gracePeriodEndDate == null) return null;

    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];

    return '${months[gracePeriodEndDate!.month - 1]} ${gracePeriodEndDate!.day}, ${gracePeriodEndDate!.year}';
  }

  /// Creates a default status for unauthenticated or error states
  factory UserSubscriptionStatus.defaultStatus() {
    return const UserSubscriptionStatus(
      currentPlan: 'free',
      isTrialActive: false,
      daysUntilTrialEnd: 0,
      hasSubscription: false,
    );
  }

  /// Creates a status from JSON response
  factory UserSubscriptionStatus.fromJson(Map<String, dynamic> json) {
    return UserSubscriptionStatus(
      currentPlan: json['current_plan'] as String? ?? 'free',
      isTrialActive: json['is_trial_active'] as bool? ?? false,
      daysUntilTrialEnd: json['days_until_trial_end'] as int? ?? 0,
      hasSubscription: json['has_subscription'] as bool? ?? false,
      subscriptionPlanType: json['subscription_plan_type'] as String?,
      subscriptionStatus: json['subscription_status'] as String?,
      trialEndDate: json['trial_end_date'] != null
          ? DateTime.tryParse(json['trial_end_date'] as String)
          : null,
      isInGracePeriod: json['is_in_grace_period'] as bool? ?? false,
      graceDaysRemaining: json['grace_days_remaining'] as int? ?? 0,
      wasEligibleForTrial: json['was_eligible_for_trial'] as bool? ?? true,
      userCreatedAt: json['user_created_at'] != null
          ? DateTime.tryParse(json['user_created_at'] as String)
          : null,
      gracePeriodEndDate: json['grace_period_end_date'] != null
          ? DateTime.tryParse(json['grace_period_end_date'] as String)
          : null,
      isInPremiumTrial: json['is_in_premium_trial'] as bool? ?? false,
      premiumTrialDaysRemaining:
          json['premium_trial_days_remaining'] as int? ?? 0,
      hasUsedPremiumTrial: json['has_used_premium_trial'] as bool? ?? false,
      canStartPremiumTrial: json['can_start_premium_trial'] as bool? ?? false,
      premiumTrialStartedAt: json['premium_trial_started_at'] != null
          ? DateTime.tryParse(json['premium_trial_started_at'] as String)
          : null,
      premiumTrialEndAt: json['premium_trial_end_at'] != null
          ? DateTime.tryParse(json['premium_trial_end_at'] as String)
          : null,
    );
  }

  /// Converts to JSON
  Map<String, dynamic> toJson() {
    return {
      'current_plan': currentPlan,
      'is_trial_active': isTrialActive,
      'days_until_trial_end': daysUntilTrialEnd,
      'has_subscription': hasSubscription,
      'subscription_plan_type': subscriptionPlanType,
      'subscription_status': subscriptionStatus,
      'trial_end_date': trialEndDate?.toIso8601String(),
      'is_in_grace_period': isInGracePeriod,
      'grace_days_remaining': graceDaysRemaining,
      'was_eligible_for_trial': wasEligibleForTrial,
      'user_created_at': userCreatedAt?.toIso8601String(),
      'grace_period_end_date': gracePeriodEndDate?.toIso8601String(),
      'is_in_premium_trial': isInPremiumTrial,
      'premium_trial_days_remaining': premiumTrialDaysRemaining,
      'has_used_premium_trial': hasUsedPremiumTrial,
      'can_start_premium_trial': canStartPremiumTrial,
      'premium_trial_started_at': premiumTrialStartedAt?.toIso8601String(),
      'premium_trial_end_at': premiumTrialEndAt?.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
        currentPlan,
        isTrialActive,
        daysUntilTrialEnd,
        hasSubscription,
        subscriptionPlanType,
        subscriptionStatus,
        trialEndDate,
        isInGracePeriod,
        graceDaysRemaining,
        wasEligibleForTrial,
        userCreatedAt,
        gracePeriodEndDate,
        isInPremiumTrial,
        premiumTrialDaysRemaining,
        hasUsedPremiumTrial,
        canStartPremiumTrial,
        premiumTrialStartedAt,
        premiumTrialEndAt,
      ];

  @override
  String toString() => 'UserSubscriptionStatus('
      'currentPlan: $currentPlan, '
      'isTrialActive: $isTrialActive, '
      'daysUntilTrialEnd: $daysUntilTrialEnd, '
      'hasSubscription: $hasSubscription, '
      'isInGracePeriod: $isInGracePeriod, '
      'wasEligibleForTrial: $wasEligibleForTrial, '
      'needsSubscription: $needsSubscription, '
      'isInPremiumTrial: $isInPremiumTrial, '
      'canStartPremiumTrial: $canStartPremiumTrial'
      ')';
}
