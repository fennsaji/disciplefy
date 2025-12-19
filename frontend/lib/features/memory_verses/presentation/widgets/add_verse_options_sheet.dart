import 'package:flutter/material.dart';

import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';

/// Bottom sheet for selecting how to add a new memory verse.
///
/// Provides three options:
/// - Add from Daily Verse
/// - Add Suggested Verse (curated popular verses)
/// - Add Custom Verse
class AddVerseOptionsSheet extends StatelessWidget {
  final VoidCallback onAddFromDaily;
  final VoidCallback onAddSuggested;
  final VoidCallback onAddManually;

  const AddVerseOptionsSheet({
    super.key,
    required this.onAddFromDaily,
    required this.onAddSuggested,
    required this.onAddManually,
  });

  /// Shows the add verse options bottom sheet.
  static void show(
    BuildContext context, {
    required VoidCallback onAddFromDaily,
    required VoidCallback onAddSuggested,
    required VoidCallback onAddManually,
  }) {
    showModalBottomSheet(
      context: context,
      builder: (bottomSheetContext) => AddVerseOptionsSheet(
        onAddFromDaily: () {
          Navigator.pop(bottomSheetContext);
          onAddFromDaily();
        },
        onAddSuggested: () {
          Navigator.pop(bottomSheetContext);
          onAddSuggested();
        },
        onAddManually: () {
          Navigator.pop(bottomSheetContext);
          onAddManually();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              context.tr(TranslationKeys.addMemoryVerseTitle),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Divider(height: 1),

          // Option 1: Add from Daily Verse
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.today,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            title: Text(context.tr(TranslationKeys.addFromDailyVerse)),
            subtitle: Text(context.tr(TranslationKeys.addFromDailyVerseDesc)),
            onTap: onAddFromDaily,
          ),

          // Option 2: Add Suggested Verse (NEW)
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.lightbulb_outline,
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
            title: Text(context.tr(TranslationKeys.addSuggestedVerse)),
            subtitle: Text(context.tr(TranslationKeys.addSuggestedVerseDesc)),
            onTap: onAddSuggested,
          ),

          // Option 3: Add Custom Verse
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.edit,
                color: theme.colorScheme.onTertiaryContainer,
              ),
            ),
            title: Text(context.tr(TranslationKeys.addCustomVerse)),
            subtitle: Text(context.tr(TranslationKeys.addCustomVerseDesc)),
            onTap: onAddManually,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
