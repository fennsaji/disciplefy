import 'package:flutter/material.dart';

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
            title: const Text('Sync with Server'),
            subtitle: const Text('Upload pending offline changes'),
            onTap: onSync,
          ),
          ListTile(
            leading: const Icon(Icons.bar_chart),
            title: const Text('View Statistics'),
            subtitle: const Text('See your progress details'),
            onTap: onViewStatistics,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
