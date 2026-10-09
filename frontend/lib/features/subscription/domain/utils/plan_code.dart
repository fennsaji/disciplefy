/// Plan codes the app knows, lowest tier first.
const _knownPlanCodes = {'free', 'standard', 'plus', 'premium'};

/// Maps a stored plan type to its plan code.
///
/// Subscriptions store the billing variant ('standard_monthly',
/// 'plus_yearly', 'standard_trial'), while plans and features are keyed by the
/// bare code ('standard'). Anything unknown reads as 'free' so a surprise value
/// never shows a paid plan's features.
String normalizePlanCode(String raw) {
  final base = raw
      .trim()
      .toLowerCase()
      .replaceFirst(RegExp(r'_(monthly|yearly|trial)$'), '');
  return _knownPlanCodes.contains(base) ? base : 'free';
}

/// The store a subscription is billed through, or null when nothing is billed
/// (a trial or a system-granted plan) so the page shows no provider at all.
String? providerLabelOrNull(String provider) {
  switch (provider) {
    case 'google_play':
      return 'Google Play';
    case 'apple_appstore':
    case 'app_store':
    case 'apple':
      return 'App Store';
    case 'razorpay':
      return 'Razorpay';
    default:
      return null;
  }
}
