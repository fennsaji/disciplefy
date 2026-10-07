import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/widgets/settings_group.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/widgets/settings_sheet.dart';
import 'package:disciplefy_bible_study/shared/widgets/popup.dart';

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

  /// Invoked after the sheet closes when the destructive "reset" option is
  /// selected.
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
      // Above the floating tab dock.
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
    return PopupSheet(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        SettingsSheetGroup(
          children: [
            if (onViewChampions != null)
              SettingsRow(
                key: const Key('memory_options_champions'),
                icon: Icons.emoji_events_outlined,
                title: context.tr(TranslationKeys.optionsMenuChampionsTitle),
                subtitle:
                    context.tr(TranslationKeys.optionsMenuChampionsSubtitle),
                onTap: onViewChampions,
              ),
            SettingsRow(
              key: const Key('memory_options_statistics'),
              icon: Icons.bar_chart_rounded,
              title: context.tr(TranslationKeys.optionsMenuStatsTitle),
              subtitle: context.tr(TranslationKeys.optionsMenuStatsSubtitle),
              onTap: onViewStatistics,
            ),
            SettingsRow(
              key: const Key('memory_options_sync'),
              icon: Icons.sync_rounded,
              tone: SettingsTone.sky,
              title: context.tr(TranslationKeys.optionsMenuSyncTitle),
              subtitle: context.tr(TranslationKeys.optionsMenuSyncSubtitle),
              onTap: onSync,
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Reset — destructive, kept visually separate from the rest
        SettingsSheetGroup(
          children: [
            SettingsRow(
              key: const Key('memory_options_reset'),
              icon: Icons.delete_forever_outlined,
              destructive: true,
              title: context.tr(TranslationKeys.optionsMenuResetTitle),
              subtitle: context.tr(TranslationKeys.optionsMenuResetSubtitle),
              onTap: onReset,
            ),
          ],
        ),
      ],
    );
  }
}
