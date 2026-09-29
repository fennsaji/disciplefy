import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/services/language_preference_service.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/shared/widgets/sheet_scroll_view.dart';

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

  final changed = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) {
      Future<void> choose(AppLanguage? language) async {
        final isSame =
            language == null ? isDefault : !isDefault && language == current;
        if (!isSame) {
          await languageService.saveStudyContentLanguage(language);
        }
        if (sheetContext.mounted) Navigator.of(sheetContext).pop(!isSame);
      }

      final theme = Theme.of(sheetContext);
      return Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: SheetScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: sheetContext.appBrandAccent.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                sheetContext.tr(TranslationKeys.studyTopicsContentLanguage),
                style: AppFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                sheetContext
                    .tr(TranslationKeys.studyTopicsContentLanguageDescription),
                style: AppFonts.inter(
                  fontSize: 13,
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
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
                  isSelected: !isDefault && language == current,
                  onTap: () => choose(language),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    },
  );
  return changed ?? false;
}

/// One choice in a language picker: the app-language and content-language
/// sheets both use it.
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
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: [
                      AppTheme.primaryColor.withOpacity(0.1),
                      AppTheme.secondaryPurple.withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? context.appBrandAccent : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: isSelected ? AppTheme.primaryGradient : null,
                  color: isSelected ? null : onSurface.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.language,
                  size: 18,
                  color: isSelected ? Colors.white : onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppFonts.inter(
                        fontSize: 15,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected ? context.appBrandAccent : onSurface,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: AppFonts.inter(
                          fontSize: 12,
                          color: onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: context.appBrandAccent,
                  size: 24,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
