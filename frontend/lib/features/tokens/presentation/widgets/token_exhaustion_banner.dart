import 'package:flutter/material.dart';
import '../../domain/entities/token_status.dart';

/// Token Exhaustion Banner Widget
///
/// Displays informative banners when users are running low or out of tokens:
/// - Warning banner when tokens are below 20% of daily limit
/// - Critical banner when tokens are exhausted
/// - Upgrade prompts for free users
/// - Purchase prompts for standard users
/// - Congratulatory message for premium users
class TokenExhaustionBanner extends StatelessWidget {
  final TokenStatus tokenStatus;
  final VoidCallback? onPurchaseTokens;
  final VoidCallback? onUpgradePlan;
  final VoidCallback? onDismiss;
  final bool showDismissButton;

  const TokenExhaustionBanner({
    super.key,
    required this.tokenStatus,
    this.onPurchaseTokens,
    this.onUpgradePlan,
    this.onDismiss,
    this.showDismissButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bannerInfo = _getBannerInfo(theme);

    if (bannerInfo == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(16),
      child: Material(
        borderRadius: BorderRadius.circular(12),
        elevation: 2,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [
                bannerInfo.color.withOpacity(0.1),
                bannerInfo.color.withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: bannerInfo.color.withOpacity(0.3),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(bannerInfo, theme),
                const SizedBox(height: 12),
                _buildContent(bannerInfo, theme),
                if (bannerInfo.hasActions) ...[
                  const SizedBox(height: 16),
                  _buildActions(bannerInfo),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BannerInfo bannerInfo, ThemeData theme) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: bannerInfo.color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            bannerInfo.icon,
            color: bannerInfo.color,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            bannerInfo.title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: bannerInfo.color,
            ),
          ),
        ),
        if (showDismissButton && onDismiss != null)
          IconButton(
            onPressed: onDismiss,
            icon: Icon(
              Icons.close,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
      ],
    );
  }

  Widget _buildContent(BannerInfo bannerInfo, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          bannerInfo.message,
          style: TextStyle(
            fontSize: 14,
            color: theme.colorScheme.onSurface,
            height: 1.4,
          ),
        ),
        if (bannerInfo.details != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withOpacity(0.8),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.colorScheme.outline.withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: bannerInfo.details!,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActions(BannerInfo bannerInfo) {
    return Row(
      children: [
        if (bannerInfo.primaryAction != null) ...[
          Expanded(
            child: ElevatedButton(
              onPressed: bannerInfo.primaryAction!.onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: bannerInfo.color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(bannerInfo.primaryAction!.icon, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    bannerInfo.primaryAction!.text,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (bannerInfo.secondaryAction != null) ...[
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton(
              onPressed: bannerInfo.secondaryAction!.onPressed,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: bannerInfo.color),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    bannerInfo.secondaryAction!.icon,
                    size: 18,
                    color: bannerInfo.color,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    bannerInfo.secondaryAction!.text,
                    style: TextStyle(
                      color: bannerInfo.color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  BannerInfo? _getBannerInfo(ThemeData theme) {
    // Premium users don't see token exhaustion banners
    if (tokenStatus.isPremium) {
      return null;
    }

    // Check if tokens are exhausted
    if (tokenStatus.totalTokens <= 0) {
      return _buildExhaustedBanner(theme);
    }

    // Check if tokens are running low (less than 20% of daily limit)
    final lowThreshold = (tokenStatus.dailyLimit * 0.2).round();
    if (tokenStatus.totalTokens <= lowThreshold &&
        tokenStatus.totalTokens > 0) {
      return _buildLowTokensBanner(theme);
    }

    return null;
  }

  BannerInfo? _buildExhaustedBanner(ThemeData theme) {
    switch (tokenStatus.userPlan) {
      case UserPlan.free:
        return BannerInfo(
          color: theme.colorScheme.error,
          icon: Icons.warning,
          title: 'Daily Tokens Exhausted',
          message:
              'You\'ve used all your daily free tokens! Upgrade to Standard or Premium for more tokens.',
          details: [
            _buildDetailRow(
                Icons.schedule, 'Resets in: ${_getResetTimeString()}', theme),
            _buildDetailRow(Icons.star,
                'Standard: 100 tokens daily + purchase more', theme),
            _buildDetailRow(
                Icons.auto_awesome, 'Premium: Unlimited tokens', theme),
          ],
          primaryAction: BannerAction(
            text: 'Upgrade Plan',
            icon: Icons.upgrade,
            onPressed: onUpgradePlan,
          ),
          secondaryAction: BannerAction(
            text: 'Wait for Reset',
            icon: Icons.schedule,
            onPressed: onDismiss,
          ),
        );

      case UserPlan.standard:
        return BannerInfo(
          color: theme.colorScheme.errorContainer,
          icon: Icons.shopping_cart,
          title: 'Tokens Exhausted',
          message:
              'You\'ve used all available tokens. Purchase more tokens or wait for tomorrow\'s reset.',
          details: [
            _buildDetailRow(Icons.schedule,
                'Daily reset in: ${_getResetTimeString()}', theme),
            _buildDetailRow(Icons.account_balance_wallet,
                'Current: ${tokenStatus.totalTokens} tokens', theme),
            _buildDetailRow(Icons.add_shopping_cart,
                'Buy tokens starting from ₹5 for 50 tokens', theme),
          ],
          primaryAction: BannerAction(
            text: 'Purchase Tokens',
            icon: Icons.payment,
            onPressed: onPurchaseTokens,
          ),
          secondaryAction: BannerAction(
            text: 'Wait for Reset',
            icon: Icons.schedule,
            onPressed: onDismiss,
          ),
        );

      case UserPlan.premium:
        // Premium users shouldn't see this banner
        return null;
    }
  }

  BannerInfo? _buildLowTokensBanner(ThemeData theme) {
    switch (tokenStatus.userPlan) {
      case UserPlan.free:
        return BannerInfo(
          color: theme.colorScheme.errorContainer,
          icon: Icons.warning_amber,
          title: 'Running Low on Tokens',
          message:
              'You have ${tokenStatus.totalTokens} tokens remaining. Consider upgrading for more tokens.',
          details: [
            _buildDetailRow(
                Icons.account_balance_wallet,
                '${tokenStatus.totalTokens} of ${tokenStatus.dailyLimit} tokens left',
                theme),
            _buildDetailRow(Icons.schedule,
                'Daily reset in: ${_getResetTimeString()}', theme),
          ],
          primaryAction: BannerAction(
            text: 'Upgrade Plan',
            icon: Icons.upgrade,
            onPressed: onUpgradePlan,
          ),
        );

      case UserPlan.standard:
        return BannerInfo(
          color: theme.colorScheme.errorContainer,
          icon: Icons.warning_amber,
          title: 'Running Low on Tokens',
          message:
              'You have ${tokenStatus.totalTokens} tokens remaining. Purchase more or wait for reset.',
          details: [
            _buildDetailRow(Icons.account_balance_wallet,
                '${tokenStatus.totalTokens} tokens remaining', theme),
            _buildDetailRow(Icons.schedule,
                'Daily reset in: ${_getResetTimeString()}', theme),
          ],
          primaryAction: BannerAction(
            text: 'Purchase Tokens',
            icon: Icons.payment,
            onPressed: onPurchaseTokens,
          ),
        );

      case UserPlan.premium:
        // Premium users shouldn't see this banner
        return null;
    }
  }

  Widget _buildDetailRow(IconData icon, String text, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getResetTimeString() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final difference = tomorrow.difference(now);

    if (difference.inHours > 0) {
      return '${difference.inHours}h ${difference.inMinutes % 60}m';
    } else {
      return '${difference.inMinutes}m';
    }
  }
}

/// Banner Information Model
///
/// Contains all the data needed to display a token exhaustion banner
class BannerInfo {
  final Color color;
  final IconData icon;
  final String title;
  final String message;
  final List<Widget>? details;
  final BannerAction? primaryAction;
  final BannerAction? secondaryAction;

  const BannerInfo({
    required this.color,
    required this.icon,
    required this.title,
    required this.message,
    this.details,
    this.primaryAction,
    this.secondaryAction,
  });

  bool get hasActions => primaryAction != null || secondaryAction != null;
}

/// Banner Action Model
///
/// Represents a button action in the token exhaustion banner
class BannerAction {
  final String text;
  final IconData icon;
  final VoidCallback? onPressed;

  const BannerAction({
    required this.text,
    required this.icon,
    this.onPressed,
  });
}
