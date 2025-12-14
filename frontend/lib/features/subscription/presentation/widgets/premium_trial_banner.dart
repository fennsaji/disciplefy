import 'package:flutter/material.dart';

import '../../domain/entities/user_subscription_status.dart';

/// Banner widget shown to promote Premium trial or display trial status.
/// Used for users who can start a 7-day free Premium trial
/// (new users who signed up after April 1st, 2025).
class PremiumTrialBanner extends StatelessWidget {
  /// The user's subscription status
  final UserSubscriptionStatus status;

  /// Callback when user taps to start trial or learn more
  final VoidCallback onStartTrial;

  /// Callback when user dismisses the banner (optional)
  final VoidCallback? onDismiss;

  const PremiumTrialBanner({
    super.key,
    required this.status,
    required this.onStartTrial,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Determine if user is in trial (show different style)
    final isInTrial = status.isInPremiumTrial;
    final isTrialEndingSoon =
        isInTrial && status.premiumTrialDaysRemaining <= 2;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isTrialEndingSoon
              ? [const Color(0xFFFF9800), const Color(0xFFFFC107)]
              : isInTrial
                  ? [const Color(0xFF43A047), const Color(0xFF66BB6A)]
                  : [const Color(0xFFE040FB), const Color(0xFF7C4DFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isTrialEndingSoon
                    ? const Color(0xFFFF9800)
                    : isInTrial
                        ? const Color(0xFF43A047)
                        : const Color(0xFF7C4DFF))
                .withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onStartTrial,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Icon
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isTrialEndingSoon
                            ? Icons.timer
                            : isInTrial
                                ? Icons.workspace_premium
                                : Icons.auto_awesome,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Title and subtitle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getTitle(),
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _getSubtitle(),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Dismiss button (only for trial promo, not when in trial)
                    if (onDismiss != null && !isInTrial)
                      IconButton(
                        onPressed: onDismiss,
                        icon: Icon(
                          Icons.close,
                          color: Colors.white.withValues(alpha: 0.7),
                          size: 20,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),

                const SizedBox(height: 16),

                // CTA button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onStartTrial,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: isTrialEndingSoon
                          ? const Color(0xFFFF9800)
                          : isInTrial
                              ? const Color(0xFF43A047)
                              : const Color(0xFF7C4DFF),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _getButtonText(),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isTrialEndingSoon
                                ? const Color(0xFFFF9800)
                                : isInTrial
                                    ? const Color(0xFF43A047)
                                    : const Color(0xFF7C4DFF),
                          ),
                        ),
                        if (!isInTrial) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7C4DFF)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'FREE',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF7C4DFF),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getTitle() {
    if (status.isInPremiumTrial) {
      if (status.premiumTrialDaysRemaining <= 1) {
        return 'Premium Trial Ends Today!';
      } else if (status.premiumTrialDaysRemaining <= 2) {
        return 'Trial Ending Soon';
      }
      return 'Premium Trial Active';
    }
    return 'Try Premium FREE';
  }

  String _getSubtitle() {
    if (status.isInPremiumTrial) {
      if (status.premiumTrialDaysRemaining <= 1) {
        return 'Upgrade now to keep Premium features';
      }
      return '${status.premiumTrialDaysRemaining} days remaining in your trial';
    }
    return 'Get 7 days of unlimited Premium features';
  }

  String _getButtonText() {
    if (status.isInPremiumTrial) {
      return 'Upgrade to Premium';
    }
    return 'Start 7-Day Trial';
  }
}

/// Compact version of the Premium trial banner for tighter spaces
class PremiumTrialBannerCompact extends StatelessWidget {
  final UserSubscriptionStatus status;
  final VoidCallback onStartTrial;

  const PremiumTrialBannerCompact({
    super.key,
    required this.status,
    required this.onStartTrial,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final isInTrial = status.isInPremiumTrial;
    final isTrialEndingSoon =
        isInTrial && status.premiumTrialDaysRemaining <= 2;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isTrialEndingSoon
            ? const Color(0xFFFFF8E1)
            : isInTrial
                ? const Color(0xFFE8F5E9)
                : const Color(0xFFF3E5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isTrialEndingSoon
              ? const Color(0xFFFFB74D)
              : isInTrial
                  ? const Color(0xFF81C784)
                  : const Color(0xFFCE93D8),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isTrialEndingSoon
                ? Icons.timer
                : isInTrial
                    ? Icons.workspace_premium
                    : Icons.auto_awesome,
            color: isTrialEndingSoon
                ? const Color(0xFFE65100)
                : isInTrial
                    ? const Color(0xFF388E3C)
                    : const Color(0xFF7B1FA2),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _getCompactMessage(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isTrialEndingSoon
                    ? const Color(0xFFE65100)
                    : isInTrial
                        ? const Color(0xFF388E3C)
                        : const Color(0xFF7B1FA2),
              ),
            ),
          ),
          TextButton(
            onPressed: onStartTrial,
            style: TextButton.styleFrom(
              foregroundColor: isTrialEndingSoon
                  ? const Color(0xFFE65100)
                  : isInTrial
                      ? const Color(0xFF388E3C)
                      : const Color(0xFF7B1FA2),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: Text(isInTrial ? 'Upgrade' : 'Try Free'),
          ),
        ],
      ),
    );
  }

  String _getCompactMessage() {
    if (status.isInPremiumTrial) {
      if (status.premiumTrialDaysRemaining <= 1) {
        return 'Premium trial ends today!';
      }
      return 'Premium trial: ${status.premiumTrialDaysRemaining} days left';
    }
    return 'Try Premium FREE for 7 days';
  }
}

/// Card version for use in settings or plan pages
class PremiumTrialCard extends StatelessWidget {
  final UserSubscriptionStatus status;
  final VoidCallback onStartTrial;

  const PremiumTrialCard({
    super.key,
    required this.status,
    required this.onStartTrial,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final isInTrial = status.isInPremiumTrial;
    final isTrialEndingSoon =
        isInTrial && status.premiumTrialDaysRemaining <= 2;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: isTrialEndingSoon
                ? [
                    const Color(0xFFFF9800).withValues(alpha: 0.1),
                    const Color(0xFFFFC107).withValues(alpha: 0.1)
                  ]
                : isInTrial
                    ? [
                        const Color(0xFF43A047).withValues(alpha: 0.1),
                        const Color(0xFF66BB6A).withValues(alpha: 0.1)
                      ]
                    : [
                        const Color(0xFFE040FB).withValues(alpha: 0.1),
                        const Color(0xFF7C4DFF).withValues(alpha: 0.1)
                      ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isTrialEndingSoon
                          ? const Color(0xFFFF9800).withValues(alpha: 0.2)
                          : isInTrial
                              ? const Color(0xFF43A047).withValues(alpha: 0.2)
                              : const Color(0xFF7C4DFF).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isTrialEndingSoon
                          ? Icons.timer
                          : isInTrial
                              ? Icons.workspace_premium
                              : Icons.auto_awesome,
                      color: isTrialEndingSoon
                          ? const Color(0xFFE65100)
                          : isInTrial
                              ? const Color(0xFF388E3C)
                              : const Color(0xFF7B1FA2),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isInTrial ? 'Premium Trial' : '7-Day Premium Trial',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getCardSubtitle(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Features list
              if (!isInTrial) ...[
                _buildFeatureRow(
                  context,
                  Icons.bolt,
                  'Unlimited AI generations',
                ),
                const SizedBox(height: 8),
                _buildFeatureRow(
                  context,
                  Icons.record_voice_over,
                  'Voice Buddy conversations',
                ),
                const SizedBox(height: 8),
                _buildFeatureRow(
                  context,
                  Icons.psychology,
                  'Memory Verses with spaced repetition',
                ),
                const SizedBox(height: 16),
              ],

              // CTA button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onStartTrial,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isTrialEndingSoon
                        ? const Color(0xFFFF9800)
                        : isInTrial
                            ? const Color(0xFF43A047)
                            : const Color(0xFF7C4DFF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    isInTrial ? 'Upgrade to Premium' : 'Start Free Trial',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              if (isInTrial) ...[
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    isTrialEndingSoon
                        ? 'Trial ends in ${status.premiumTrialDaysRemaining} day${status.premiumTrialDaysRemaining == 1 ? '' : 's'}'
                        : '${status.premiumTrialDaysRemaining} days remaining',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isTrialEndingSoon
                          ? const Color(0xFFE65100)
                          : const Color(0xFF388E3C),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow(BuildContext context, IconData icon, String text) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: const Color(0xFF7C4DFF),
        ),
        const SizedBox(width: 12),
        Text(
          text,
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }

  String _getCardSubtitle() {
    if (status.isInPremiumTrial) {
      if (status.premiumTrialDaysRemaining <= 1) {
        return 'Your trial ends today. Upgrade to continue.';
      }
      return 'Enjoying Premium features';
    }
    return 'Experience all Premium features free';
  }
}
