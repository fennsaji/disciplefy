import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/shared/widgets/gold_marks.dart';
import 'package:disciplefy_bible_study/shared/widgets/popup.dart';

/// Milestone celebration dialog.
///
/// Shown when the user reaches a streak milestone (10, 30, 100, 365 days):
/// gold "STREAK MILESTONE" eyebrow, a per-milestone icon in a soft gold
/// circle, the milestone title, a motivational line, the XP reward and one
/// primary pill. Same popup style as the achievement unlock dialog.
class MilestoneCelebrationDialog extends StatelessWidget {
  final int milestoneDays;
  final int xpEarned;

  const MilestoneCelebrationDialog({
    super.key,
    required this.milestoneDays,
    required this.xpEarned,
  });

  /// Shows the milestone celebration dialog.
  static Future<void> show(
    BuildContext context, {
    required int milestoneDays,
    required int xpEarned,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => MilestoneCelebrationDialog(
        milestoneDays: milestoneDays,
        xpEarned: xpEarned,
      ),
    );
  }

  String _getMilestoneTitle(BuildContext context) {
    if (milestoneDays == 365) {
      return context.tr(TranslationKeys.streakMilestoneTitleYear);
    }
    return context.tr(
      TranslationKeys.streakMilestoneTitleDays,
      {'count': '$milestoneDays'},
    );
  }

  String _getMotivationalMessage(BuildContext context) {
    final key = switch (milestoneDays) {
      10 => TranslationKeys.streakMilestoneMessage10,
      30 => TranslationKeys.streakMilestoneMessage30,
      100 => TranslationKeys.streakMilestoneMessage100,
      365 => TranslationKeys.streakMilestoneMessage365,
      _ => TranslationKeys.streakMilestoneMessageDefault,
    };
    return context.tr(key);
  }

  IconData _getMilestoneIcon() {
    switch (milestoneDays) {
      case 10:
        return Icons.stars_rounded;
      case 30:
        return Icons.emoji_events_outlined;
      case 100:
        return Icons.military_tech_outlined;
      case 365:
        return Icons.workspace_premium_outlined;
      default:
        return Icons.celebration_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupDialog(
      children: [
        PopupHeader(
          // One short settle-in of the icon; no looping animation.
          icon: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.8, end: 1),
            duration: const Duration(milliseconds: 360),
            curve: Curves.easeOutBack,
            builder: (context, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: PopupIconCircle(
              icon: _getMilestoneIcon(),
              tone: PopupTone.gold,
              size: 72,
            ),
          ),
          eyebrow: context.tr(TranslationKeys.streakMilestoneEyebrow),
          title: _getMilestoneTitle(context),
          body: _getMotivationalMessage(context),
        ),
        const SizedBox(height: 16),
        XpRewardPill(xp: xpEarned),
        const SizedBox(height: 24),
        PopupPrimaryButton(
          key: const Key('milestone_celebration_continue'),
          label: context.tr(TranslationKeys.streakMilestoneContinue),
          onPressed: () => Navigator.of(context).pop(),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
