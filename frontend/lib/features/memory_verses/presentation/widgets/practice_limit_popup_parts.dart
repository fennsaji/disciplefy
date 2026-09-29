import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';

/// Pieces shared by the memory practice limit popups (daily review limit,
/// daily unlock limit, plan-locked mode): plan rows, check rows, a note and
/// localized labels for modes and limits.

/// Localized name of a practice mode slug ("flip_card" → "Flip Card").
String practiceModeLabel(BuildContext context, String slug) {
  switch (slug) {
    case 'flip_card':
      return context.tr(TranslationKeys.practiceModeFlipCard);
    case 'type_it_out':
      return context.tr(TranslationKeys.practiceModeTypeItOut);
    case 'cloze':
      return context.tr(TranslationKeys.practiceModeCloze);
    case 'first_letter':
      return context.tr(TranslationKeys.practiceModeFirstLetter);
    case 'progressive':
      return context.tr(TranslationKeys.practiceModeProgressive);
    case 'word_scramble':
      return context.tr(TranslationKeys.practiceModeWordScramble);
    case 'word_bank':
      return context.tr(TranslationKeys.practiceModeWordBank);
    case 'audio':
      return context.tr(TranslationKeys.practiceModeAudio);
    default:
      return slug;
  }
}

/// "2 modes per verse per day" / "All modes unlocked" for an unlock limit
/// (-1 means unlimited).
String unlockLimitLabel(BuildContext context, int limit) {
  if (limit < 0) return context.tr(TranslationKeys.practiceUnlockLimitAllModes);
  return context.tr(
    limit == 1
        ? TranslationKeys.practiceUnlockLimitModesPerDayOne
        : TranslationKeys.practiceUnlockLimitModesPerDayOther,
    {'count': '$limit'},
  );
}

/// "5 daily verse reviews" / "Unlimited daily verse reviews" for a daily
/// review limit (-1 means unlimited).
String dailyReviewLimitLabel(BuildContext context, int limit) {
  if (limit < 0) return context.tr(TranslationKeys.dailyReviewLimitUnlimited);
  return context.tr(TranslationKeys.dailyReviewLimitCount, {'count': '$limit'});
}

/// Semi-bold subheading above a list inside a popup.
class PracticePopupSubheading extends StatelessWidget {
  final String text;
  final Widget? trailing;

  const PracticePopupSubheading(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            text,
            style: AppFonts.inter(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: palette.text,
              height: 1.35,
            ),
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );
  }
}

/// A plan in an upgrade list: name, what it gives, and its monthly price.
///
/// [highlighted] plans (real upgrades over the current plan) get the accent
/// icon; the others a muted outline.
class PracticePlanRow extends StatelessWidget {
  final String name;
  final String description;
  final String price;
  final bool highlighted;

  const PracticePlanRow({
    super.key,
    required this.name,
    required this.description,
    required this.price,
    this.highlighted = true,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(
            highlighted
                ? Icons.arrow_circle_up_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 18,
            color: highlighted ? palette.accentIcon : palette.dim,
          ),
        ),
        const SizedBox(width: 10),
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
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                description,
                style: AppFonts.inter(
                  fontSize: 12.5,
                  color: palette.muted,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        if (price.isNotEmpty) ...[
          const SizedBox(width: 10),
          Text(
            price,
            style: AppFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: palette.gold,
              height: 1.3,
            ),
          ),
        ],
      ],
    );
  }
}

/// Green check and a label (modes included / unlocked today).
class PracticeCheckRow extends StatelessWidget {
  final String label;

  const PracticeCheckRow(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.check_circle_rounded, size: 16, color: context.appSuccess),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: AppFonts.inter(
              fontSize: 13.5,
              color: palette.text,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

/// Info icon and a short muted note.
class PracticePopupNote extends StatelessWidget {
  final String text;

  const PracticePopupNote(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(Icons.info_outline_rounded,
              size: 17, color: palette.accentIcon),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: AppFonts.inter(
              fontSize: 12.5,
              color: palette.muted,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

/// Stacks [children] with [gap] between them.
List<Widget> practicePopupSpaced(List<Widget> children, {double gap = 10}) => [
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) SizedBox(height: gap),
        children[i],
      ],
    ];
