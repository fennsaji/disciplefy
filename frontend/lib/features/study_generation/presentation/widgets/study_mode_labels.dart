import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/constants/study_mode_preferences.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_mode.dart';

/// Localised labels, icons and feature-flag keys for [StudyMode], shared by
/// the Generate tab's inline depth cards and the full-height depth chooser.
extension StudyModePresentation on StudyMode {
  /// Full name, e.g. "Standard Study".
  String localizedName(BuildContext context) => context.tr(switch (this) {
        StudyMode.quick => TranslationKeys.studyModeQuickName,
        StudyMode.standard => TranslationKeys.studyModeStandardName,
        StudyMode.deep => TranslationKeys.studyModeDeepName,
        StudyMode.lectio => TranslationKeys.studyModeLectioName,
        StudyMode.sermon => TranslationKeys.studyModeSermonName,
      });

  /// Compact name for the small depth cards, e.g. "Standard".
  String localizedShortName(BuildContext context) => context.tr(switch (this) {
        StudyMode.quick => TranslationKeys.studyModeQuickShortName,
        StudyMode.standard => TranslationKeys.studyModeStandardShortName,
        StudyMode.deep => TranslationKeys.studyModeDeepShortName,
        StudyMode.lectio => TranslationKeys.studyModeLectioShortName,
        StudyMode.sermon => TranslationKeys.studyModeSermonShortName,
      });

  String localizedDescription(BuildContext context) =>
      context.tr(switch (this) {
        StudyMode.quick => TranslationKeys.studyModeQuickDescription,
        StudyMode.standard => TranslationKeys.studyModeStandardDescription,
        StudyMode.deep => TranslationKeys.studyModeDeepDescription,
        StudyMode.lectio => TranslationKeys.studyModeLectioDescription,
        StudyMode.sermon => TranslationKeys.studyModeSermonDescription,
      });

  /// "8 min"; the sermon outline shows its real range ("50–60 min") rather
  /// than the averaged [StudyModeExtension.durationMinutes].
  String localizedDuration(BuildContext context) => context.tr(
        TranslationKeys.studyModeMinutes,
        {
          'count': this == StudyMode.sermon ? '50–60' : '$durationMinutes',
        },
      );

  /// Compact duration for one-line controls, e.g. "8 min" / "8 മി".
  String localizedShortDuration(BuildContext context) => context.tr(
        TranslationKeys.studyModeMinutesShort,
        {
          'count': this == StudyMode.sermon ? '50–60' : '$durationMinutes',
        },
      );

  /// Outline icon used by the depth cards and rows.
  IconData get outlineIcon => switch (this) {
        StudyMode.quick => Icons.bolt_outlined,
        StudyMode.standard => Icons.menu_book_outlined,
        StudyMode.deep => Icons.layers_outlined,
        StudyMode.lectio => Icons.spa_outlined,
        StudyMode.sermon => Icons.mic_none_rounded,
      };

  /// System-config feature key that gates this mode per plan.
  String get featureKey => switch (this) {
        StudyMode.quick => 'quick_read_mode',
        StudyMode.standard => 'standard_study_mode',
        StudyMode.deep => 'deep_dive_mode',
        StudyMode.lectio => 'lectio_divina_mode',
        StudyMode.sermon => 'sermon_outline_mode',
      };
}

/// Mode recommended for every input type on the Generate tab.
const StudyMode recommendedStudyMode = StudyMode.standard;

/// Depth the Generate tab pre-selects for a saved preference [raw]:
/// a concrete saved mode wins; "recommended", "ask" or no preference use the
/// recommended mode. Modes the user cannot use (hidden or locked for their
/// plan) fall back to the recommended mode, then to the first usable one.
StudyMode resolveInitialStudyMode(
  String? raw, {
  required List<StudyMode> available,
  Set<StudyMode> locked = const {},
}) {
  bool usable(StudyMode m) => available.contains(m) && !locked.contains(m);

  final saved =
      StudyModePreferences.isRecommended(raw) ? null : studyModeFromString(raw);
  if (saved != null && usable(saved)) return saved;
  if (usable(recommendedStudyMode)) return recommendedStudyMode;
  return available.firstWhere(usable,
      orElse: () =>
          available.isNotEmpty ? available.first : recommendedStudyMode);
}
