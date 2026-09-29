import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';

/// Shared tokens of the memory verses design.
///
/// Every colour resolves from [ReaderPalette] or the theme-aware semantic
/// accents on [BuildContext], so these widgets never branch on brightness at the
/// call site. No shadows, gradients, blur or continuous animation.

/// Tabular figures so timers and counts do not jitter.
const List<FontFeature> kMemoryTabular = [FontFeature.tabularFigures()];

/// Horizontal page gutter used by every memory verses page.
const double kMemoryGutter = 16;

/// Semantic colour family of a tag, card or label.
enum MemoryTone { neutral, accent, success, gold, warning, error }

/// Resolved foreground, soft fill and border for an [MemoryTone].
@immutable
class MemoryToneColors {
  final Color foreground;
  final Color fill;
  final Color border;

  const MemoryToneColors(this.foreground, this.fill, this.border);

  factory MemoryToneColors.of(BuildContext context, MemoryTone tone) {
    final palette = ReaderPalette.of(context);
    final alpha = palette.isDark ? 0.14 : 0.10;
    switch (tone) {
      case MemoryTone.neutral:
        return MemoryToneColors(
            palette.muted, palette.raised, palette.hairline);
      case MemoryTone.accent:
        return MemoryToneColors(
          palette.accentIcon,
          AppColors.brandPrimary.withValues(alpha: palette.isDark ? 0.2 : 0.08),
          palette.accentIcon.withValues(alpha: 0.35),
        );
      case MemoryTone.success:
        return MemoryToneColors(
          context.appSuccess,
          AppColors.success.withValues(alpha: alpha),
          context.appSuccess,
        );
      case MemoryTone.gold:
        return MemoryToneColors(
          palette.gold,
          palette.gold.withValues(alpha: alpha),
          palette.gold.withValues(alpha: 0.5),
        );
      case MemoryTone.warning:
        return MemoryToneColors(
          context.appWarning,
          AppColors.warning.withValues(alpha: alpha),
          context.appWarning,
        );
      case MemoryTone.error:
        return MemoryToneColors(
          context.appError,
          AppColors.error.withValues(alpha: alpha),
          context.appError,
        );
    }
  }
}

/// Difficulty tier colours used by the mode picker and practice subtitles:
/// Easy green, Medium gold, Hard red.
enum MemoryDifficulty { easy, medium, hard }

extension MemoryDifficultyTone on MemoryDifficulty {
  MemoryTone get tone {
    switch (this) {
      case MemoryDifficulty.easy:
        return MemoryTone.success;
      case MemoryDifficulty.medium:
        return MemoryTone.gold;
      case MemoryDifficulty.hard:
        return MemoryTone.error;
    }
  }
}

/// Formats a timer as `m:ss` ("0:42", "12:05") like the practice timer pill.
String formatPracticeDuration(int totalSeconds) {
  final safe = totalSeconds < 0 ? 0 : totalSeconds;
  final minutes = safe ~/ 60;
  final seconds = (safe % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
