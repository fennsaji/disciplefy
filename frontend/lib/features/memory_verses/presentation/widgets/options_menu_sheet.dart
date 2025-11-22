import 'package:flutter/material.dart';

import '../../../../core/i18n/translation_keys.dart';
import '../../../../core/extensions/translation_extension.dart';

/// Bottom sheet for memory verse options menu.
///
/// Provides options for:
/// - Syncing with server
/// - Viewing statistics
class OptionsMenuSheet extends StatelessWidget {
  final VoidCallback onSync;
  final VoidCallback onViewStatistics;

  const OptionsMenuSheet({
    super.key,
    required this.onSync,
    required this.onViewStatistics,
  });

  /// Shows the options menu bottom sheet.
  static void show(
    BuildContext context, {
    required VoidCallback onSync,
    required VoidCallback onViewStatistics,
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.sync),
            title: Text(context.tr(TranslationKeys.optionsMenuSyncTitle)),
            subtitle: Text(context.tr(TranslationKeys.optionsMenuSyncSubtitle)),
            onTap: onSync,
          ),
          ListTile(
            leading: const Icon(Icons.bar_chart),
            title: Text(context.tr(TranslationKeys.optionsMenuStatsTitle)),
            subtitle:
                Text(context.tr(TranslationKeys.optionsMenuStatsSubtitle)),
            onTap: onViewStatistics,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
