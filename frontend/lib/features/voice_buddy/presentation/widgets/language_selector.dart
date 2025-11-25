import 'package:flutter/material.dart';

/// Supported languages for voice conversations.
enum VoiceLanguage {
  english('en-US', 'English', '\u{1F1FA}\u{1F1F8}'),
  hindi('hi-IN', '\u0939\u093F\u0928\u094D\u0926\u0940', '\u{1F1EE}\u{1F1F3}'),
  malayalam('ml-IN', '\u0D2E\u0D32\u0D2F\u0D3E\u0D33\u0D02', '\u{1F1EE}\u{1F1F3}');

  final String code;
  final String displayName;
  final String flag;

  const VoiceLanguage(this.code, this.displayName, this.flag);

  /// Get display string with flag.
  String get displayWithFlag => '$flag $displayName';

  /// Get short language code (e.g., 'en' from 'en-US').
  String get shortCode => code.split('-').first;

  /// Find VoiceLanguage from code (supports both 'en-US' and 'en' formats).
  static VoiceLanguage fromCode(String code) {
    // Try exact match first
    for (final lang in VoiceLanguage.values) {
      if (lang.code == code) return lang;
    }
    // Try short code match
    for (final lang in VoiceLanguage.values) {
      if (lang.shortCode == code) return lang;
    }
    // Default to English
    return VoiceLanguage.english;
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
              selectedColor: theme.colorScheme.secondary.withAlpha((0.3 * 255).round()),
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
