import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/entities/practice_mode_entity.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/widgets/memory_ui/memory_ui.dart';

/// One practice mode in the mode picker: a plain icon tile, the mode name
/// with a one-line description, the difficulty word (Easy green / Medium
/// gold / Hard red) and a chevron, or a lock when the mode is not
/// available today. Locked rows are dimmed and route taps to [onLockedTap].
class PracticeModeRow extends StatelessWidget {
  final PracticeModeEntity mode;
  final bool isRecommended;
  final bool isFirstRecommended;
  final bool isTierLocked;
  final bool isUnlockLimitReached;
  final VoidCallback onTap;
  final VoidCallback? onLockedTap;

  /// Opens the "how it works" sheet (info button on unlocked rows).
  final VoidCallback? onInfoTap;

  const PracticeModeRow({
    super.key,
    required this.mode,
    required this.onTap,
    this.isRecommended = false,
    this.isFirstRecommended = false,
    this.isTierLocked = false,
    this.isUnlockLimitReached = false,
    this.onLockedTap,
    this.onInfoTap,
  });

  bool get _isLocked => isTierLocked || isUnlockLimitReached;

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final locked = _isLocked;
    final name = _modeName(context);
    final meta = _metaLine(context);
    // The recommended mode is the highlighted row: a gold wash with a soft
    // gold glow on dark.
    final highlight = isRecommended && !locked;
    final lockReason = isTierLocked
        ? context.tr(TranslationKeys.memoryScreensModeLockedUpgrade)
        : context.tr(TranslationKeys.memoryScreensDailyLimitReached);

    return Semantics(
      button: true,
      label: locked ? '$name, $lockReason' : null,
      child: InkWell(
        onTap: locked ? onLockedTap : onTap,
        onLongPress: onInfoTap,
        borderRadius: highlight ? BorderRadius.circular(12) : null,
        child: Container(
          constraints: const BoxConstraints(minHeight: 58),
          padding: EdgeInsets.symmetric(
              vertical: 10, horizontal: highlight ? 12 : 0),
          margin: highlight
              ? const EdgeInsets.symmetric(vertical: 4)
              : EdgeInsets.zero,
          decoration: highlight
              ? BoxDecoration(
                  color: Color.alphaBlend(
                    palette.gold
                        .withValues(alpha: palette.isDark ? 0.08 : 0.07),
                    palette.page,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: palette.isDark
                      ? null
                      : Border.all(color: palette.gold.withValues(alpha: 0.35)),
                  boxShadow: palette.isDark
                      ? [
                          BoxShadow(
                            color: palette.gold.withValues(alpha: 0.8),
                            blurRadius: 16,
                          ),
                        ]
                      : null,
                )
              : BoxDecoration(
                  border: Border(bottom: BorderSide(color: palette.hairline)),
                ),
          child: Opacity(
            opacity: locked ? 0.55 : 1,
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: palette.isDark
                        ? palette.gold.withValues(alpha: 0.15)
                        : AppColors.brandHighlight,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  alignment: Alignment.center,
                  child: Icon(mode.icon, size: 16, color: palette.goldOnTint),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: AppFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: palette.text,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        _modeDescription(context),
                        style: AppFonts.inter(
                          fontSize: 12,
                          color: palette.muted,
                          height: 1.3,
                        ),
                      ),
                      if (meta != null) ...[
                        const SizedBox(height: 4),
                        meta,
                      ],
                      if (locked) ...[
                        const SizedBox(height: 4),
                        Text(
                          '$lockReason · ${context.tr(isTierLocked ? TranslationKeys.memoryScreensTapToSeePlans : TranslationKeys.memoryScreensChooseUnlockedModes)}',
                          style: AppFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: palette.gold,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                MemoryDifficultyLabel(
                  label: _difficultyLabel(context),
                  difficulty: _difficulty,
                ),
                if (!locked && onInfoTap != null)
                  IconButton(
                    tooltip:
                        context.tr(TranslationKeys.memoryScreensHowItWorks),
                    visualDensity: VisualDensity.compact,
                    onPressed: onInfoTap,
                    icon: Icon(Icons.info_outline_rounded,
                        size: 18, color: palette.dim),
                  )
                else
                  const SizedBox(width: 8),
                Icon(
                  locked
                      ? (isTierLocked
                          ? Icons.lock_outline_rounded
                          : Icons.lock_clock_outlined)
                      : Icons.chevron_right_rounded,
                  size: locked ? 18 : 18,
                  color: palette.dim,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// "Master this next" (gold) and the practice record, when there is one.
  Widget? _metaLine(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final parts = <InlineSpan>[];
    if (isRecommended) {
      parts.add(TextSpan(
        text: context.tr(isFirstRecommended
            ? TranslationKeys.practiceSelectionMasterThisFirst
            : TranslationKeys.practiceSelectionMasterThisNext),
        style: TextStyle(color: palette.gold, fontWeight: FontWeight.w600),
      ));
    }
    if (mode.timesPracticed > 0) {
      if (parts.isNotEmpty) parts.add(const TextSpan(text: '  ·  '));
      final String record;
      if (mode.isMastered) {
        record = context.tr(TranslationKeys.practiceBadgeMastered);
      } else if (mode.isProficient) {
        record = context.tr(TranslationKeys.practiceBadgeProficient);
      } else {
        record = '${mode.successRate.toStringAsFixed(0)}%';
      }
      parts.add(TextSpan(
        text: record,
        style: TextStyle(
          color: mode.isMastered
              ? palette.gold
              : mode.isProficient
                  ? context.appSuccess
                  : palette.muted,
          fontWeight: FontWeight.w600,
        ),
      ));
    }
    if (parts.isEmpty) return null;
    return Text.rich(
      TextSpan(children: parts),
      style: AppFonts.inter(fontSize: 12, color: palette.dim),
    );
  }

  MemoryDifficulty get _difficulty {
    switch (mode.difficulty) {
      case Difficulty.easy:
        return MemoryDifficulty.easy;
      case Difficulty.medium:
        return MemoryDifficulty.medium;
      case Difficulty.hard:
        return MemoryDifficulty.hard;
    }
  }

  String _difficultyLabel(BuildContext context) {
    switch (mode.difficulty) {
      case Difficulty.easy:
        return context.tr(TranslationKeys.difficultyEasy);
      case Difficulty.medium:
        return context.tr(TranslationKeys.difficultyMedium);
      case Difficulty.hard:
        return context.tr(TranslationKeys.difficultyHard);
    }
  }

  String _modeName(BuildContext context) {
    switch (mode.modeType) {
      case PracticeModeType.flipCard:
        return context.tr(TranslationKeys.practiceModeFlipCard);
      case PracticeModeType.wordBank:
        return context.tr(TranslationKeys.practiceModeWordBank);
      case PracticeModeType.cloze:
        return context.tr(TranslationKeys.practiceModeCloze);
      case PracticeModeType.firstLetter:
        return context.tr(TranslationKeys.practiceModeFirstLetter);
      case PracticeModeType.progressive:
        return context.tr(TranslationKeys.practiceModeProgressive);
      case PracticeModeType.wordScramble:
        return context.tr(TranslationKeys.practiceModeWordScramble);
      case PracticeModeType.audio:
        return context.tr(TranslationKeys.practiceModeAudio);
      case PracticeModeType.typeItOut:
        return context.tr(TranslationKeys.practiceModeTypeItOut);
    }
  }

  String _modeDescription(BuildContext context) {
    switch (mode.modeType) {
      case PracticeModeType.flipCard:
        return context.tr(TranslationKeys.practiceModeFlipCardDesc);
      case PracticeModeType.wordBank:
        return context.tr(TranslationKeys.practiceModeWordBankDesc);
      case PracticeModeType.cloze:
        return context.tr(TranslationKeys.practiceModeClozeDesc);
      case PracticeModeType.firstLetter:
        return context.tr(TranslationKeys.practiceModeFirstLetterDesc);
      case PracticeModeType.progressive:
        return context.tr(TranslationKeys.practiceModeProgressiveDesc);
      case PracticeModeType.wordScramble:
        return context.tr(TranslationKeys.practiceModeWordScrambleDesc);
      case PracticeModeType.audio:
        return context.tr(TranslationKeys.practiceModeAudioDesc);
      case PracticeModeType.typeItOut:
        return context.tr(TranslationKeys.practiceModeTypeItOutDesc);
    }
  }
}
