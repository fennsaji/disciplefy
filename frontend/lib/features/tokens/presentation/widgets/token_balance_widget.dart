import 'package:flutter/material.dart';

import '../../domain/entities/token_status.dart';

/// Widget that displays current token balance with visual indicators.
class TokenBalanceWidget extends StatelessWidget {
  /// Current token status to display
  final TokenStatus tokenStatus;

  /// Whether to show detailed information
  final bool showDetails;

  /// Whether to show refresh button
  final bool showRefreshButton;

  /// Callback when refresh is tapped
  final VoidCallback? onRefresh;

  /// Callback when widget is tapped
  final VoidCallback? onTap;

  const TokenBalanceWidget({
    super.key,
    required this.tokenStatus,
    this.showDetails = false,
    this.showRefreshButton = false,
    this.onRefresh,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(context, theme, textTheme),
              const SizedBox(height: 12),
              _buildTokenDisplay(context, theme, textTheme),
              if (showDetails) ...[
                const SizedBox(height: 12),
                _buildProgressBar(context, theme),
                const SizedBox(height: 8),
                _buildDetails(context, textTheme),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
      BuildContext context, ThemeData theme, TextTheme textTheme) {
    return Row(
      children: [
        Icon(
          Icons.token,
          color: _getStatusColor(),
          size: 20,
        ),
        const SizedBox(width: 8),
        Text(
          'Tokens',
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        if (showRefreshButton && onRefresh != null)
          IconButton(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh token balance',
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }

  Widget _buildTokenDisplay(
      BuildContext context, ThemeData theme, TextTheme textTheme) {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${tokenStatus.totalTokens}',
              style: textTheme.headlineMedium?.copyWith(
                color: _getStatusColor(),
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              _getStatusText(),
              style: textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const Spacer(),
        _buildPlanChip(context, theme),
      ],
    );
  }

  Widget _buildPlanChip(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getPlanColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getPlanColor().withOpacity(0.3),
        ),
      ),
      child: Text(
        tokenStatus.userPlan.displayName,
        style: theme.textTheme.bodySmall?.copyWith(
          color: _getPlanColor(),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildProgressBar(BuildContext context, ThemeData theme) {
    if (tokenStatus.isPremium) {
      return Container(
        height: 6,
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.3),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.amber,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      );
    }

    return Container(
      height: 6,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(3),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor:
            (tokenStatus.totalTokens / tokenStatus.dailyLimit).clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: _getStatusColor(),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }

  Widget _buildDetails(BuildContext context, TextTheme textTheme) {
    return Column(
      children: [
        if (!tokenStatus.isPremium) ...[
          Row(
            children: [
              Text(
                'Daily: ${tokenStatus.availableTokens}',
                style: textTheme.bodySmall,
              ),
              const Spacer(),
              Text(
                'Limit: ${tokenStatus.dailyLimit}',
                style: textTheme.bodySmall,
              ),
            ],
          ),
          if (tokenStatus.purchasedTokens > 0) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  'Purchased: ${tokenStatus.purchasedTokens}',
                  style: textTheme.bodySmall?.copyWith(
                    color: Colors.purple[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                'Used today: ${tokenStatus.totalConsumedToday}',
                style: textTheme.bodySmall,
              ),
              const Spacer(),
              Text(
                'Resets: ${tokenStatus.formattedTimeUntilReset}',
                style: textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ] else ...[
          Row(
            children: [
              Icon(
                Icons.all_inclusive,
                size: 16,
                color: Colors.amber[700],
              ),
              const SizedBox(width: 4),
              Text(
                'Unlimited tokens',
                style: textTheme.bodySmall?.copyWith(
                  color: Colors.amber[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Color _getStatusColor() {
    if (tokenStatus.isPremium) {
      return Colors.amber[700]!;
    }

    if (tokenStatus.totalTokens == 0) {
      return Colors.red[600]!;
    } else if (tokenStatus.isRunningLow) {
      return Colors.orange[600]!;
    } else {
      return Colors.green[600]!;
    }
  }

  Color _getPlanColor() {
    switch (tokenStatus.userPlan) {
      case UserPlan.free:
        return Colors.grey[600]!;
      case UserPlan.standard:
        return Colors.blue[600]!;
      case UserPlan.premium:
        return Colors.amber[700]!;
    }
  }

  String _getStatusText() {
    if (tokenStatus.isPremium) {
      return 'Unlimited';
    }

    if (tokenStatus.totalTokens == 0) {
      return 'No tokens remaining';
    } else if (tokenStatus.isRunningLow) {
      return 'Running low';
    } else {
      return 'Available tokens';
    }
  }
}
