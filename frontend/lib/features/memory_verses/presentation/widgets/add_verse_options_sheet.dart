import 'package:flutter/material.dart';

/// Bottom sheet for selecting how to add a new memory verse.
///
/// Provides two options:
/// - Add from Daily Verse
/// - Add Custom Verse
class AddVerseOptionsSheet extends StatelessWidget {
  final VoidCallback onAddFromDaily;
  final VoidCallback onAddManually;

  const AddVerseOptionsSheet({
    super.key,
    required this.onAddFromDaily,
    required this.onAddManually,
  });

  /// Shows the add verse options bottom sheet.
  static void show(
    BuildContext context, {
    required VoidCallback onAddFromDaily,
    required VoidCallback onAddManually,
  }) {
    showModalBottomSheet(
      context: context,
      builder: (bottomSheetContext) => AddVerseOptionsSheet(
        onAddFromDaily: () {
          Navigator.pop(bottomSheetContext);
          onAddFromDaily();
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
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.today),
            title: const Text('Add from Daily Verse'),
            subtitle: const Text("Add today's verse to your memory deck"),
            onTap: onAddFromDaily,
          ),
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Add Custom Verse'),
            subtitle: const Text('Enter any Bible verse manually'),
            onTap: onAddManually,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
