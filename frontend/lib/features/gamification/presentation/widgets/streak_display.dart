import 'package:flutter/material.dart';

import '../../../../core/constants/app_fonts.dart';
import '../../../../core/localization/app_localizations.dart';

/// Widget to display study and verse streaks
class StreakDisplay extends StatelessWidget {
  final int studyStreak;
  final int verseStreak;
  final int? longestStreak;
  final bool compact;

  const StreakDisplay({
    super.key,
    required this.studyStreak,
    required this.verseStreak,
    this.longestStreak,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (compact) {
      return _buildCompactView(theme);
    }

    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.progressStreaks,
            style: AppFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StreakItem(
                  icon: '🔥',
                  label: l10n.progressStudyStreak,
                  value: studyStreak,
                  suffix: l10n.progressDays,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _StreakItem(
                  icon: '📖',
                  label: l10n.progressVerseStreak,
                  value: verseStreak,
                  suffix: l10n.progressDays,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          if (longestStreak != null && longestStreak! > 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.emoji_events,
                  size: 16,
                  color: Colors.amber,
                ),
                const SizedBox(width: 6),
                Text(
                  '${l10n.progressPersonalBest}: $longestStreak ${l10n.progressDays}',
                  style: AppFonts.inter(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactView(ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CompactStreakBadge(
          icon: '🔥',
          value: studyStreak,
        ),
        const SizedBox(width: 12),
        _CompactStreakBadge(
          icon: '📖',
          value: verseStreak,
        ),
      ],
    );
  }
}

class _StreakItem extends StatelessWidget {
  final String icon;
  final String label;
  final int value;
  final String suffix;
  final Color color;

  const _StreakItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.suffix,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$value',
                style: AppFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                suffix,
                style: AppFonts.inter(
                  fontSize: 13,
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompactStreakBadge extends StatelessWidget {
  final String icon;
  final int value;

  const _CompactStreakBadge({
    required this.icon,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text(
            '$value',
            style: AppFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
