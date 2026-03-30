import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/practice_mode_entity.dart';

/// Bottom sheet showing step-by-step "How it works" instructions
/// for a specific practice mode.
///
/// Triggered by the (i) button on each PracticeModeCard.
class PracticeModeInfoSheet extends StatelessWidget {
  final PracticeModeType modeType;

  const PracticeModeInfoSheet._({required this.modeType});

  /// Shows the info bottom sheet for the given [modeType].
  static void show(BuildContext context, PracticeModeType modeType) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => PracticeModeInfoSheet._(modeType: modeType),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final entity = PracticeModeEntity(
      modeType: modeType,
      timesPracticed: 0,
      successRate: 0,
      isFavorite: false,
    );
    final difficultyColor = entity.difficultyColor;
    final steps = _getSteps(l10n);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant
                      .withAlpha((0.3 * 255).round()),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header: icon + name + difficulty badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: difficultyColor.withAlpha((0.1 * 255).round()),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(entity.icon, color: difficultyColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    entity.displayName,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _DifficultyPill(
                  label: entity.difficultyLabel,
                  color: difficultyColor,
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // "How it works" section
            Text(
              l10n.practiceModeInfoHowItWorks,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),

            // Steps list
            ...steps.asMap().entries.map((entry) {
              final idx = entry.key;
              final step = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: difficultyColor.withAlpha((0.15 * 255).round()),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${idx + 1}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: difficultyColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        step,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 20),

            // Got it button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  l10n.practiceModeInfoGotIt,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
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
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha((0.12 * 255).round()),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha((0.4 * 255).round())),
      ),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
