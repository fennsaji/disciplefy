import 'package:flutter/material.dart';

/// Dialog for manually adding a custom Bible verse to memory deck.
///
/// Allows user to input:
/// - Verse reference (e.g., John 3:16)
/// - Verse text
///
/// Validates inputs and triggers the provided callback on submit.
class AddManualVerseDialog extends StatefulWidget {
  final Function({
    required String verseReference,
    required String verseText,
  }) onSubmit;

  const AddManualVerseDialog({
    super.key,
    required this.onSubmit,
  });

  /// Shows the add manual verse dialog.
  static void show(
    BuildContext context, {
    required Function({
      required String verseReference,
      required String verseText,
    }) onSubmit,
  }) {
    showDialog(
      context: context,
      builder: (dialogContext) => AddManualVerseDialog(onSubmit: onSubmit),
    );
  }

  @override
  State<AddManualVerseDialog> createState() => _AddManualVerseDialogState();
}

class _AddManualVerseDialogState extends State<AddManualVerseDialog> {
  final _referenceController = TextEditingController();
  final _textController = TextEditingController();
  String? _referenceError;
  String? _textError;

  @override
  void dispose() {
    _referenceController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    final trimmedReference = _referenceController.text.trim();
    final trimmedText = _textController.text.trim();

    bool hasError = false;

    if (trimmedReference.isEmpty) {
      setState(() => _referenceError = 'Verse reference is required');
      hasError = true;
    }

    if (trimmedText.isEmpty) {
      setState(() => _textError = 'Verse text is required');
      hasError = true;
    }

    if (!hasError) {
      widget.onSubmit(
        verseReference: trimmedReference,
        verseText: trimmedText,
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Custom Verse'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _referenceController,
              decoration: InputDecoration(
                labelText: 'Verse Reference',
                hintText: 'e.g., John 3:16',
                border: const OutlineInputBorder(),
                errorText: _referenceError,
              ),
              onChanged: (_) {
                if (_referenceError != null) {
                  setState(() => _referenceError = null);
                }
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _textController,
              decoration: InputDecoration(
                labelText: 'Verse Text',
                hintText: 'Enter the full verse...',
                border: const OutlineInputBorder(),
                errorText: _textError,
              ),
              maxLines: 4,
              onChanged: (_) {
                if (_textError != null) {
                  setState(() => _textError = null);
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _handleSubmit,
          child: const Text('Add'),
        ),
      ],
    );
  }
}
