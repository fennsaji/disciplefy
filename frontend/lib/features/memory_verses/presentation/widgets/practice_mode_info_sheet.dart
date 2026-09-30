import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/entities/practice_mode_entity.dart';
import 'package:disciplefy_bible_study/shared/widgets/popup.dart';

/// Bottom sheet showing step-by-step "How it works" instructions
/// for a specific practice mode.
///
/// Triggered by the (i) button on each PracticeModeRow.
class PracticeModeInfoSheet extends StatelessWidget {
  final PracticeModeType modeType;

  const PracticeModeInfoSheet._({required this.modeType});

  /// Shows the info bottom sheet for the given [modeType].
  static void show(BuildContext context, PracticeModeType modeType) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PracticeModeInfoSheet._(modeType: modeType),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final l10n = AppLocalizations.of(context)!;
    final entity = PracticeModeEntity(
      modeType: modeType,
      timesPracticed: 0,
      successRate: 0,
      isFavorite: false,
    );
    final steps = _getSteps(l10n);

    return PopupSheet(
      children: [
        // Header: icon + name + difficulty badge
        Row(
          children: [
            PopupIconCircle(icon: entity.icon, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                entity.displayName,
                style: AppFonts.poppins(
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                  color: palette.text,
                  height: 1.25,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _DifficultyPill(
              label: entity.difficultyLabel,
              color: entity.difficultyColor,
            ),
          ],
        ),
        const SizedBox(height: 18),
        Divider(height: 1, color: palette.hairline),
        const SizedBox(height: 18),

        // "How it works" section
        PopupEyebrow(l10n.practiceModeInfoHowItWorks,
            textAlign: TextAlign.start),
        const SizedBox(height: 12),

        // Steps list
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: palette.raised,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${i + 1}',
                    style: AppFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: palette.gold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    steps[i],
                    style: AppFonts.inter(
                      fontSize: 14.5,
                      color: palette.text,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 12),

        // Got it button
        PopupPrimaryButton(
          key: const Key('practice_mode_info_got_it'),
          label: l10n.practiceModeInfoGotIt,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  List<String> _getSteps(AppLocalizations l10n) {
    switch (modeType) {
      case PracticeModeType.flipCard:
        return [
          l10n.practiceModeInfoFlipCardStep1,
          l10n.practiceModeInfoFlipCardStep2,
          l10n.practiceModeInfoFlipCardStep3,
        ];
      case PracticeModeType.wordBank:
        return [
          l10n.practiceModeInfoWordBankStep1,
          l10n.practiceModeInfoWordBankStep2,
          l10n.practiceModeInfoWordBankStep3,
        ];
      case PracticeModeType.cloze:
        return [
          l10n.practiceModeInfoClozeStep1,
          l10n.practiceModeInfoClozeStep2,
          l10n.practiceModeInfoClozeStep3,
        ];
      case PracticeModeType.firstLetter:
        return [
          l10n.practiceModeInfoFirstLetterStep1,
          l10n.practiceModeInfoFirstLetterStep2,
          l10n.practiceModeInfoFirstLetterStep3,
        ];
      case PracticeModeType.progressive:
        return [
          l10n.practiceModeInfoProgressiveStep1,
          l10n.practiceModeInfoProgressiveStep2,
          l10n.practiceModeInfoProgressiveStep3,
        ];
      case PracticeModeType.wordScramble:
        return [
          l10n.practiceModeInfoWordScrambleStep1,
          l10n.practiceModeInfoWordScrambleStep2,
          l10n.practiceModeInfoWordScrambleStep3,
        ];
      case PracticeModeType.audio:
        return [
          l10n.practiceModeInfoAudioStep1,
          l10n.practiceModeInfoAudioStep2,
          l10n.practiceModeInfoAudioStep3,
        ];
      case PracticeModeType.typeItOut:
        return [
          l10n.practiceModeInfoTypeItOutStep1,
          l10n.practiceModeInfoTypeItOutStep2,
          l10n.practiceModeInfoTypeItOutStep3,
        ];
    }
  }
}

class _DifficultyPill extends StatelessWidget {
  final String label;
  final Color color;

  const _DifficultyPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha((0.12 * 255).round()),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppFonts.inter(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
