import 'package:flutter/material.dart';

import '../../../../core/i18n/translation_keys.dart';
import '../../../../core/extensions/translation_extension.dart';

/// Bottom sheet for memory verse options menu.
///
/// Provides options for:
/// - Champions leaderboard
/// - Statistics
/// - Syncing with server
class OptionsMenuSheet extends StatelessWidget {
  final VoidCallback onSync;
  final VoidCallback onViewStatistics;
  final VoidCallback? onViewChampions;

  const OptionsMenuSheet({
    super.key,
    required this.onSync,
    required this.onViewStatistics,
    this.onViewChampions,
  });

  /// Shows the options menu bottom sheet.
  static void show(
    BuildContext context, {
    required VoidCallback onSync,
    required VoidCallback onViewStatistics,
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
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
