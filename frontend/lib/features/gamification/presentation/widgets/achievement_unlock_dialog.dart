import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/shared/widgets/gold_marks.dart';
import 'package:disciplefy_bible_study/shared/widgets/popup.dart';
import 'package:disciplefy_bible_study/features/gamification/domain/entities/achievement.dart';

/// Dialog shown when user unlocks an achievement.
///
/// Popup: gold "ACHIEVEMENT UNLOCKED" eyebrow, the badge in a soft gold
/// circle, the achievement name and one primary pill. No XP wording: this
/// pops up on a new user's first lessons.
class AchievementUnlockDialog extends StatelessWidget {
  final AchievementUnlockResult achievement;

  /// Called by the primary button. The caller pops the dialog.
  final VoidCallback onDismiss;

  const AchievementUnlockDialog({
    super.key,
    required this.achievement,
    required this.onDismiss,
  });

  /// Show achievement unlock dialog
  static Future<void> show(
    BuildContext context, {
    required AchievementUnlockResult achievement,
    required VoidCallback onDismiss,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Achievement',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return AchievementUnlockDialog(
          achievement: achievement,
          onDismiss: onDismiss,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved =
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopupDialog(
      children: [
        PopupHeader(
          // One short settle-in of the badge; no looping animation.
          icon: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.8, end: 1),
            duration: const Duration(milliseconds: 360),
            curve: Curves.easeOutBack,
            builder: (context, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: const PopupIconCircle(
              icon: Icons.emoji_events_outlined,
              tone: PopupTone.gold,
              size: 72,
            ),
          ),
          eyebrow: context.tr(TranslationKeys.popupAchievementEyebrow),
          title: achievement.achievementName,
        ),
        const SizedBox(height: 24),
        PopupPrimaryButton(
          key: const Key('achievement_unlock_dismiss'),
          label: context.tr(TranslationKeys.popupAchievementCta),
          // Just call onDismiss - the caller is responsible for popping.
          onPressed: onDismiss,
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
