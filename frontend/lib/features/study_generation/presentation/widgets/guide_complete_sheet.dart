import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/shared/widgets/popup.dart';

/// One "what next" row of [GuideCompleteSheet].
class GuideCompleteAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Replaces [icon] inside the tinted circle (e.g. the Discipler glyph).
  final Widget? leading;

  const GuideCompleteAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.leading,
  });
}

/// Bottom sheet shown once a study guide is completed: "GUIDE COMPLETE"
/// eyebrow, the guide's title, next-step rows, a primary pill ("Done" or
/// "Continue learning path") and "Not now".
///
/// Show it with a transparent sheet background.
class GuideCompleteSheet extends StatelessWidget {
  final String guideTitle;
  final bool isFromLearningPath;
  final List<GuideCompleteAction> actions;
  final VoidCallback onPrimary;
  final VoidCallback onNotNow;

  const GuideCompleteSheet({
    super.key,
    required this.guideTitle,
    required this.isFromLearningPath,
    required this.actions,
    required this.onPrimary,
    required this.onNotNow,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return PopupSheet(
      children: [
        PopupHeader(
          centered: false,
          icon: const PopupIconCircle(
            icon: Icons.check_rounded,
            tone: PopupTone.gold,
            size: 48,
          ),
          eyebrow: context.tr(TranslationKeys.popupGuideCompleteEyebrow),
          title: guideTitle,
          body: context.tr(isFromLearningPath
              ? TranslationKeys.popupGuideCompleteNextPath
              : TranslationKeys.popupGuideCompleteNext),
        ),
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 14),
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0) Container(height: 1, color: palette.hairline),
            _ActionRow(action: actions[i]),
          ],
        ],
        const SizedBox(height: 18),
        PopupPrimaryButton(
          key: const Key('guide_complete_primary'),
          label: context.tr(isFromLearningPath
              ? TranslationKeys.popupContinuePath
              : TranslationKeys.popupDone),
          icon: isFromLearningPath ? Icons.arrow_forward_rounded : null,
          onPressed: onPrimary,
        ),
        const SizedBox(height: 4),
        PopupTextButton(
          key: const Key('guide_complete_not_now'),
          label: context.tr(TranslationKeys.popupNotNow),
          onPressed: onNotNow,
        ),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  final GuideCompleteAction action;

  const _ActionRow({required this.action});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return InkWell(
      onTap: action.onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            PopupIconCircle(
              icon: action.leading == null ? action.icon : null,
              size: 40,
              child: action.leading,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                action.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: palette.text,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 20, color: palette.dim),
          ],
        ),
      ),
    );
  }
}
