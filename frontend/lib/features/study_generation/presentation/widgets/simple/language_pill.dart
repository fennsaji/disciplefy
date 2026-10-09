import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/pages/generate_study_screen.dart';

/// The Generate search field is white in both themes (design), so its
/// contents use fixed light-surface colours rather than the theme's.
abstract final class SearchFieldColors {
  static const Color ink = Color(0xFF1A1917);
  static const Color muted = Color(0xFF6F6B61);

  /// Placeholder: the design's warm grey, darkened to 4.5:1 on the white
  /// field (was #8A8F9C, 3.2:1).
  static const Color hint = Color(0xFF7B766D);
  static const Color pillFill = Color(0xFFF0EEEA);
}

/// Language pill inside the Generate search field (EN / हिं / മ).
///
/// Its menu offers "Default" (follow the app language) and the three study
/// languages. When the study language follows the default, the pill still
/// shows the default's code so the user sees which language the guide will
/// be in. [onSelected] receives `null` for "Default".
class LanguagePill extends StatelessWidget {
  final StudyLanguage selected;
  final bool isDefault;
  final ValueChanged<StudyLanguage?> onSelected;

  const LanguagePill({
    super.key = const Key('generate_language_pill'),
    required this.selected,
    required this.isDefault,
    required this.onSelected,
  });

  /// Short code for a study language, as shown on the pill.
  static String code(StudyLanguage language) => switch (language) {
        StudyLanguage.english => 'EN',
        StudyLanguage.hindi => 'हिं',
        StudyLanguage.malayalam => 'മ',
      };

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    // Menu values are wrapped in a record: a bare `null` ("Default") would be
    // reported by PopupMenuButton as a cancel and never reach [onSelected].
    return PopupMenuButton<(StudyLanguage?,)>(
      initialValue: (isDefault ? null : selected,),
      onSelected: (choice) => onSelected(choice.$1),
      offset: const Offset(0, 44),
      color: palette.card,
      surfaceTintColor: Colors.transparent,
      elevation: 6,
      tooltip: context.tr(TranslationKeys.generateStudyLanguage),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: palette.hairline),
      ),
      itemBuilder: (context) => [
        _item(context, null,
            '${context.tr(TranslationKeys.generateStudyDefaultLanguage)} (${code(selected)})'),
        PopupMenuDivider(color: palette.hairline),
        _item(context, StudyLanguage.english, 'English'),
        _item(context, StudyLanguage.hindi, 'हिन्दी'),
        _item(context, StudyLanguage.malayalam, 'മലയാളം'),
      ],
      child: Container(
        constraints: const BoxConstraints(maxWidth: 96),
        padding: const EdgeInsets.fromLTRB(12, 7, 8, 7),
        decoration: BoxDecoration(
          color: SearchFieldColors.pillFill,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // "Default" in Hindi/Malayalam shrinks to fit the pill.
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  code(selected),
                  maxLines: 1,
                  style: AppFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: SearchFieldColors.ink,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 2),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: SearchFieldColors.muted,
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<(StudyLanguage?,)> _item(
    BuildContext context,
    StudyLanguage? language,
    String label,
  ) {
    final isSelected =
        language == null ? isDefault : (!isDefault && selected == language);
    final palette = ReaderPalette.of(context);
    return PopupMenuItem<(StudyLanguage?,)>(
      value: (language,),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppFonts.inter(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? palette.accentIcon : palette.text,
              ),
            ),
          ),
          if (isSelected)
            Icon(Icons.check_rounded, color: palette.accentIcon, size: 18),
        ],
      ),
    );
  }
}
