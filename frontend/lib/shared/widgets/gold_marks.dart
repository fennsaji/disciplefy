import 'package:flutter/material.dart';

import '../../core/extensions/translation_extension.dart';
import '../../core/i18n/translation_keys.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_fonts.dart';

/// Shared gold "earned" marks.
///
/// Both of these were hand-copied across features — the XP pill three times
/// (achievement badge, unlock dialog, stats dashboard) and the milestone badge
/// twice (learning path detail, fellowship lessons). Every copy used a slightly
/// different Material amber and every one failed contrast, so a fix had to be
/// made in each place separately.
///
/// Gold marks the earning; the number or label stays in body colour, because
/// gold on a gold wash tops out at ~4.1:1 on the light page and cannot reach
/// AA for normal text.
class XpRewardPill extends StatelessWidget {
  const XpRewardPill({
    super.key,
    required this.xp,
    this.compact = false,
    this.showPlus = true,
  });

  final int xp;
  final bool compact;
  final bool showPlus;

  @override
  Widget build(BuildContext context) {
    final gold = context.appStreakAccent;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 16,
        vertical: compact ? 4 : 8,
      ),
      decoration: BoxDecoration(
        color: gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(compact ? 8 : 20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star, size: compact ? 14 : 18, color: gold),
          SizedBox(width: compact ? 4 : 6),
          Text(
            '${showPlus ? '+' : ''}$xp XP',
            style: AppFonts.inter(
              fontSize: compact ? 11 : 14,
              fontWeight: FontWeight.w600,
              color: context.appTextPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// The "Milestone" flag shown on a learning-path topic.
class MilestoneBadge extends StatelessWidget {
  const MilestoneBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final gold = context.appStreakAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.flag, size: 10, color: gold),
          const SizedBox(width: 2),
          Text(
            context.tr(TranslationKeys.learningPathsMilestone),
            style: AppFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: gold,
            ),
          ),
        ],
      ),
    );
  }
}
