import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/services/language_preference_service.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/widgets/settings_group.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/widgets/settings_sheet.dart';

/// Opens the content-language picker: the language study guides, learning
/// paths and daily verses are generated in. Leaves the app's own language
/// (menus, buttons) untouched.
///
/// Used by Settings and by the Topics screen's menu, so both show the same
/// choices and write the same preference. Returns true if the preference
/// changed. Screens that show content already listen to
/// [LanguagePreferenceService.studyContentLanguageChanges].
Future<bool> showContentLanguageSheet(BuildContext context) async {
  final languageService = sl<LanguagePreferenceService>();
  final isDefault = await languageService.isStudyContentLanguageDefault();
  final current = await languageService.getStudyContentLanguage();
  final appLanguage = await languageService.getSelectedLanguage();

  if (!context.mounted) return false;

  final changed = await showSettingsSheet<bool>(
    context: context,
    builder: (sheetContext) {
      Future<void> choose(AppLanguage? language) async {
        final isSame =
            language == null ? isDefault : !isDefault && language == current;
        if (!isSame) {
          await languageService.saveStudyContentLanguage(language);
        }
        if (sheetContext.mounted) Navigator.of(sheetContext).pop(!isSame);
      }

      return SettingsSheetFrame(
        title: sheetContext.tr(TranslationKeys.studyTopicsContentLanguage),
        description: sheetContext
            .tr(TranslationKeys.studyTopicsContentLanguageDescription),
        children: [
          SettingsSheetGroup(
            children: [
              LanguageOptionTile(
                label: sheetContext
                    .tr(TranslationKeys.studyTopicsContentLanguageDefault),
                subtitle:
                    '${sheetContext.tr(TranslationKeys.studyTopicsContentLanguageDefaultDescription)} (${appLanguage.displayName})',
                isSelected: isDefault,
                onTap: () => choose(null),
              ),
              for (final language in AppLanguage.values)
                LanguageOptionTile(
                  label: language.displayName,
                  // "Default" belongs to the app-language picker; here the
                  // first option already covers following the app.
                  subtitle: language == AppLanguage.english
                      ? null
                      : languageEnglishName(sheetContext, language),
                  isSelected: !isDefault && language == current,
                  onTap: () => choose(language),
                ),
            ],
          ),
        ],
      );
    },
  );
  return changed ?? false;
}

/// Second line under a language's native name: its English name, or
/// "Default" for English (the app's default language).
String languageEnglishName(BuildContext context, AppLanguage language) =>
    switch (language) {
      AppLanguage.english =>
        context.tr(TranslationKeys.settingsLanguageDefault),
      AppLanguage.hindi => 'Hindi',
      AppLanguage.malayalam => 'Malayalam',
    };

/// One choice in a language picker: the app-language and content-language
/// sheets both use it. A radio row meant to sit in a [SettingsSheetGroup].
class LanguageOptionTile extends StatelessWidget {
  final String label;
  final String? subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const LanguageOptionTile({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) => SettingsRadioRow(
        title: label,
        subtitle: subtitle,
        selected: isSelected,
        onTap: onTap,
      );
}
