import 'package:flutter/material.dart';

import '../../domain/entities/token_status.dart';
import '../extensions/duration_extensions.dart';
import '../../../../core/extensions/translation_extension.dart';

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
              _Header(
                tokenStatus: tokenStatus,
                showRefreshButton: showRefreshButton,
                onRefresh: onRefresh,
              ),
              const SizedBox(height: 12),
              _TokenDisplay(tokenStatus: tokenStatus),
              if (showDetails) ...[
                const SizedBox(height: 12),
                _ProgressBar(tokenStatus: tokenStatus),
                const SizedBox(height: 8),
                _Details(tokenStatus: tokenStatus),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Header section with title and optional refresh button
class _Header extends StatelessWidget {
  final TokenStatus tokenStatus;
  final bool showRefreshButton;
  final VoidCallback? onRefresh;

  const _Header({
    required this.tokenStatus,
    required this.showRefreshButton,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Row(
      children: [
        Icon(
          Icons.token,
          color: _getStatusColor(tokenStatus),
          size: 20,
        ),
        const SizedBox(width: 8),
        Text(
          context.tr('tokens.balance.title'),
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        if (showRefreshButton && onRefresh != null)
          IconButton(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
            tooltip: context.tr('tokens.balance.refresh'),
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }
}

/// Token count display with status text and plan chip
class _TokenDisplay extends StatelessWidget {
  final TokenStatus tokenStatus;

  const _TokenDisplay({
    required this.tokenStatus,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${tokenStatus.totalTokens}',
              style: textTheme.headlineMedium?.copyWith(
                color: _getStatusColor(tokenStatus),
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              _getStatusText(tokenStatus, context),
              style: textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const Spacer(),
        _PlanChip(tokenStatus: tokenStatus),
      ],
    );
  }
}

/// Plan chip showing user's current plan
class _PlanChip extends StatelessWidget {
  final TokenStatus tokenStatus;

  const _PlanChip({
    required this.tokenStatus,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final planColor = _getPlanColor(tokenStatus.userPlan);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: planColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: planColor.withOpacity(0.3),
        ),
      ),
      child: Text(
        tokenStatus.userPlan.displayName,
        style: theme.textTheme.bodySmall?.copyWith(
          color: planColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Progress bar showing token usage
class _ProgressBar extends StatelessWidget {
  final TokenStatus tokenStatus;

  const _ProgressBar({
    required this.tokenStatus,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
        widthFactor: tokenStatus.dailyLimit > 0
            ? (tokenStatus.totalTokens / tokenStatus.dailyLimit).clamp(0.0, 1.0)
            : 0.0,
        child: Container(
          decoration: BoxDecoration(
            color: _getStatusColor(tokenStatus),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }
}

/// Detailed information section
class _Details extends StatelessWidget {
  final TokenStatus tokenStatus;

  const _Details({
    required this.tokenStatus,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        if (!tokenStatus.isPremium) ...[
          Row(
            children: [
              Text(
                '${context.tr('tokens.balance.daily')}: ${tokenStatus.availableTokens}',
                style: textTheme.bodySmall,
              ),
              const Spacer(),
              Text(
                '${context.tr('tokens.balance.limit')}: ${tokenStatus.dailyLimit}',
                style: textTheme.bodySmall,
              ),
            ],
          ),
          if (tokenStatus.purchasedTokens > 0) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  '${context.tr('tokens.balance.purchased')}: ${tokenStatus.purchasedTokens}',
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
                '${context.tr('tokens.balance.used_today')}: ${tokenStatus.totalConsumedToday}',
                style: textTheme.bodySmall,
              ),
              const Spacer(),
              Text(
                '${context.tr('tokens.balance.resets')}: ${tokenStatus.timeUntilReset.toShortLabel()}',
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
                context.tr('tokens.balance.unlimited_tokens'),
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
}

// Utility functions moved to top-level to be shared
Color _getStatusColor(TokenStatus tokenStatus) {
  if (tokenStatus.isPremium) {
    return Colors.amber[700]!;
  }

  final percentage = tokenStatus.dailyLimit > 0
      ? tokenStatus.totalTokens / tokenStatus.dailyLimit
      : 0.0;

  if (percentage < 0.25) {
    return Colors.red[600]!;
  } else if (percentage < 0.5) {
    return Colors.orange[600]!;
  } else {
    return Colors.green[600]!;
  }
}

String _getStatusText(TokenStatus tokenStatus, BuildContext context) {
  if (tokenStatus.isPremium) {
    return context.tr('tokens.balance.unlimited');
  }

  final percentage = tokenStatus.dailyLimit > 0
      ? tokenStatus.totalTokens / tokenStatus.dailyLimit
      : 0.0;

  if (percentage < 0.25) {
    return context.tr('tokens.balance.running_low');
  } else if (percentage < 0.5) {
    return context.tr('tokens.balance.getting_low');
  } else {
    return context.tr('tokens.balance.available');
  }
}

Color _getPlanColor(UserPlan plan) {
  switch (plan) {
    case UserPlan.free:
      return Colors.grey[600]!;
    case UserPlan.standard:
      return Colors.blue[600]!;
    case UserPlan.premium:
      return Colors.amber[700]!;
  }
}
