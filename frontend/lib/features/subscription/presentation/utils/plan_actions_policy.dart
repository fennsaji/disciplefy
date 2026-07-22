import '../../../tokens/domain/entities/token_status.dart';

/// Decides which plan-change actions to offer on the My Plan page.
///
/// Tiers rank by enum order: free < standard < plus < premium.
class PlanActionsPolicy {
  const PlanActionsPolicy._();

  /// Whether a higher tier exists to move up to.
  ///
  /// [newSubscriptionsEnabled] is the system kill switch — when new
  /// subscriptions are disabled no upgrade path is offered at all.
  static bool canUpgrade(
    UserPlan plan, {
    bool newSubscriptionsEnabled = true,
  }) =>
      plan != UserPlan.premium && newSubscriptionsEnabled;

  /// Whether a lower *paid* tier exists to move down to.
  ///
  /// Dropping below Standard means cancelling, which [canCancel] covers.
  static bool canDowngrade(UserPlan plan) =>
      plan.index > UserPlan.standard.index;

  /// Whether there is a paid subscription to cancel. Free users have none,
  /// even when a Free subscription row exists and reports itself active.
  static bool canCancel(UserPlan plan) => plan != UserPlan.free;
}
