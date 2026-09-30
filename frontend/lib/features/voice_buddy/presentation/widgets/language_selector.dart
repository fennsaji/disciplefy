import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/widgets/settings_group.dart';
import 'package:disciplefy_bible_study/shared/widgets/popup.dart';

/// Supported languages for voice conversations.
enum VoiceLanguage {
  /// Default option - uses the app's preferred language
  defaultLang('default', 'Default', '\u{1F310}'),
  english('en-US', 'English', '\u{1F1FA}\u{1F1F8}'),
  hindi('hi-IN', '\u0939\u093F\u0928\u094D\u0926\u0940', '\u{1F1EE}\u{1F1F3}'),
  malayalam(
      'ml-IN', '\u0D2E\u0D32\u0D2F\u0D3E\u0D33\u0D02', '\u{1F1EE}\u{1F1F3}');

  final String code;
  final String displayName;
  final String flag;

  const VoiceLanguage(this.code, this.displayName, this.flag);

  /// Get display string with flag.
  String get displayWithFlag => '$flag $displayName';

  /// Get short language code (e.g., 'en' from 'en-US').
  String get shortCode => code.split('-').first;

  /// Whether this is the default (app language) option.
  bool get isDefault => this == VoiceLanguage.defaultLang;

  /// Latin-script name shown under a native-script [displayName], or null
  /// when the display name is already in Latin script.
  String? get latinName => switch (this) {
        VoiceLanguage.hindi => 'Hindi',
        VoiceLanguage.malayalam => 'Malayalam',
        _ => null,
      };

  /// Find VoiceLanguage from code (supports both 'en-US' and 'en' formats).
  static VoiceLanguage fromCode(String code) {
    // Try exact match first
    for (final lang in VoiceLanguage.values) {
      if (lang.code == code) return lang;
    }
    // Try short code match (skip default since it doesn't have a short code)
    for (final lang in VoiceLanguage.values) {
      if (!lang.isDefault && lang.shortCode == code) return lang;
    }
    // Default to the default option
    return VoiceLanguage.defaultLang;
  }
}

/// A dropdown widget for selecting the voice conversation language.
class LanguageSelector extends StatelessWidget {
  /// Currently selected language.
  final VoiceLanguage selectedLanguage;

  /// Callback when language is changed.
  final ValueChanged<VoiceLanguage> onLanguageChanged;

  /// Whether to show just the icon (compact mode).
  final bool compact;

  const LanguageSelector({
    super.key,
    required this.selectedLanguage,
    required this.onLanguageChanged,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (compact) {
      return PopupMenuButton<VoiceLanguage>(
        icon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              selectedLanguage.flag,
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              color: theme.colorScheme.onSurface,
            ),
          ],
        ),
        onSelected: onLanguageChanged,
        itemBuilder: (context) => VoiceLanguage.values.map((language) {
          return PopupMenuItem<VoiceLanguage>(
            value: language,
            child: Row(
              children: [
                Text(
                  language.flag,
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(width: 8),
                Text(
                  language.displayName,
                  style: theme.textTheme.bodyMedium,
                ),
                if (language == selectedLanguage) ...[
                  const Spacer(),
                  Icon(
                    Icons.check,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      );
    }

    return DropdownButtonHideUnderline(
      child: DropdownButton<VoiceLanguage>(
        value: selectedLanguage,
        icon: Icon(
          Icons.language,
          color: theme.colorScheme.onSurface,
        ),
        items: VoiceLanguage.values.map((language) {
          return DropdownMenuItem<VoiceLanguage>(
            value: language,
            child: Text(language.displayWithFlag),
          );
        }).toList(),
        onChanged: (value) {
          if (value != null) {
            onLanguageChanged(value);
          }
        },
      ),
    );
  }
}

/// A segmented button version of the language selector for inline display.
class LanguageSegmentedSelector extends StatelessWidget {
  /// Currently selected language.
  final VoiceLanguage selectedLanguage;

  /// Callback when language is changed.
  final ValueChanged<VoiceLanguage> onLanguageChanged;

  const LanguageSegmentedSelector({
    super.key,
    required this.selectedLanguage,
    required this.onLanguageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SegmentedButton<VoiceLanguage>(
      segments: VoiceLanguage.values.map((language) {
        return ButtonSegment<VoiceLanguage>(
          value: language,
          label: Text(
            language.flag,
            style: const TextStyle(fontSize: 16),
          ),
          tooltip: language.displayName,
        );
      }).toList(),
      selected: {selectedLanguage},
      onSelectionChanged: (Set<VoiceLanguage> selection) {
        if (selection.isNotEmpty) {
          onLanguageChanged(selection.first);
        }
      },
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) {
            return theme.colorScheme.primary.withAlpha((0.1 * 255).round());
          }
          return null;
        }),
      ),
    );
  }
}

/// A chip-based language selector for horizontal scrollable display.
class LanguageChipSelector extends StatelessWidget {
  /// Currently selected language.
  final VoiceLanguage selectedLanguage;

  /// Callback when language is changed.
  final ValueChanged<VoiceLanguage> onLanguageChanged;

  const LanguageChipSelector({
    super.key,
    required this.selectedLanguage,
    required this.onLanguageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: VoiceLanguage.values.map((language) {
          final isSelected = language == selectedLanguage;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    language.flag,
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(width: 4),
                  Text(language.displayName),
                ],
              ),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  onLanguageChanged(language);
                }
              },
              selectedColor:
                  theme.colorScheme.secondary.withAlpha((0.3 * 255).round()),
              checkmarkColor: theme.colorScheme.primary,
              labelStyle: TextStyle(
                color: isSelected
                    ? theme.colorScheme.onSecondary
                    : theme.colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Bottom sheet for choosing the language Discipler speaks in: one radio
/// card per [VoiceLanguage], the selected one outlined in indigo.
///
/// Open it with [VoiceLanguageSheet.show], which resolves to the tapped
/// language, or null when the sheet is dismissed.
class VoiceLanguageSheet extends StatelessWidget {
  /// Language shown as selected.
  final VoiceLanguage selectedLanguage;

  /// Called with the tapped language.
  final ValueChanged<VoiceLanguage> onSelected;

  const VoiceLanguageSheet({
    super.key,
    required this.selectedLanguage,
    required this.onSelected,
  });

  /// Shows the sheet and returns the chosen language (null if dismissed).
  static Future<VoiceLanguage?> show(
    BuildContext context, {
    required VoiceLanguage selectedLanguage,
  }) {
    return showModalBottomSheet<VoiceLanguage>(
      // Above the floating dock, not under it.
      useRootNavigator: true,
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => VoiceLanguageSheet(
        selectedLanguage: selectedLanguage,
        onSelected: (language) => Navigator.of(sheetContext).pop(language),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return PopupSheet(
      children: [
        Semantics(
          header: true,
          child: Text(
            context.tr(TranslationKeys.voiceLanguageSheetTitle),
            style: AppFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: palette.text,
              height: 1.3,
            ),
          ),
        ),
        const SizedBox(height: 16),
        for (final language in VoiceLanguage.values) ...[
          VoiceLanguageOptionCard(
            language: language,
            selected: language == selectedLanguage,
            onTap: () => onSelected(language),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

/// One radio card of the [VoiceLanguageSheet]: native name, a second line
/// (app language for Default, Latin name for Hindi/Malayalam) and a radio.
class VoiceLanguageOptionCard extends StatelessWidget {
  final VoiceLanguage language;
  final bool selected;
  final VoidCallback onTap;

  const VoiceLanguageOptionCard({
    super.key,
    required this.language,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final title = language.isDefault
        ? context.tr('voice_buddy.settings.default_language')
        : language.displayName;
    final subtitle = language.isDefault
        ? context.tr(
            TranslationKeys.voiceLanguageSheetDefaultSubtitle,
            {
              'language': context.translationService.currentLanguage.displayName
            },
          )
        : language.latinName;

    final fill = selected
        ? ReaderPalette.selectedFill
            .withValues(alpha: palette.isDark ? 0.16 : 0.07)
        : (palette.isDark ? palette.raised : palette.page);
    final border = selected
        ? const BorderSide(color: ReaderPalette.selectedFill, width: 1.5)
        : BorderSide(color: palette.hairline);

    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      child: Material(
        color: fill,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: border,
        ),
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: palette.text,
                            height: 1.3,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: AppFonts.inter(
                              fontSize: 13,
                              color: palette.muted,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SettingsRadioMark(selected: selected),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
