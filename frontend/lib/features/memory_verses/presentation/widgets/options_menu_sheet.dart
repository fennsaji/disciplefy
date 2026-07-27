import 'package:flutter/material.dart';

import '../../../../core/i18n/translation_keys.dart';
import '../../../../core/extensions/translation_extension.dart';

/// Bottom sheet for memory verse options menu.
///
/// Provides options for:
/// - Champions leaderboard
/// - Statistics
/// - Syncing with server
/// - Resetting all verses and progress (destructive)
class OptionsMenuSheet extends StatelessWidget {
  final VoidCallback onSync;
  final VoidCallback onViewStatistics;
  final VoidCallback? onViewChampions;
  final VoidCallback onReset;

  const OptionsMenuSheet({
    super.key,
    required this.onSync,
    required this.onViewStatistics,
    required this.onReset,
    this.onViewChampions,
  });

  /// Shows the options menu bottom sheet.
  static void show(
    BuildContext context, {
    required VoidCallback onSync,
    required VoidCallback onViewStatistics,
    required VoidCallback onReset,
    VoidCallback? onViewChampions,
  }) {
    showModalBottomSheet(
      context: context,
      builder: (bottomSheetContext) => OptionsMenuSheet(
        onSync: () {
          Navigator.pop(bottomSheetContext);
          onSync();
        },
        onViewStatistics: () {
          Navigator.pop(bottomSheetContext);
          onViewStatistics();
        },
        onReset: () {
          Navigator.pop(bottomSheetContext);
          onReset();
        },
        onViewChampions: onViewChampions != null
            ? () {
                Navigator.pop(bottomSheetContext);
                onViewChampions();
              }
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final errorColor = Theme.of(context).colorScheme.error;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Champions
          if (onViewChampions != null)
            ListTile(
              leading: const Icon(Icons.emoji_events_outlined),
              title:
                  Text(context.tr(TranslationKeys.optionsMenuChampionsTitle)),
              subtitle: Text(
                  context.tr(TranslationKeys.optionsMenuChampionsSubtitle)),
              onTap: onViewChampions,
            ),
          // Statistics
          ListTile(
            leading: const Icon(Icons.bar_chart),
            title: Text(context.tr(TranslationKeys.optionsMenuStatsTitle)),
            subtitle:
                Text(context.tr(TranslationKeys.optionsMenuStatsSubtitle)),
            onTap: onViewStatistics,
          ),
          const Divider(height: 1),
          // Sync
          ListTile(
            leading: const Icon(Icons.sync),
            title: Text(context.tr(TranslationKeys.optionsMenuSyncTitle)),
            subtitle: Text(context.tr(TranslationKeys.optionsMenuSyncSubtitle)),
            onTap: onSync,
          ),
          const Divider(height: 1),
          // Reset — destructive, kept visually separate from the rest
          ListTile(
            leading: Icon(Icons.delete_forever_outlined, color: errorColor),
            title: Text(
              context.tr(TranslationKeys.optionsMenuResetTitle),
              style: TextStyle(color: errorColor),
            ),
            subtitle:
                Text(context.tr(TranslationKeys.optionsMenuResetSubtitle)),
            onTap: onReset,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
