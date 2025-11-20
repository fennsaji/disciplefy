import 'package:flutter/material.dart';

import '../../../daily_verse/domain/entities/daily_verse_entity.dart';

/// Dialog for manually adding a custom Bible verse to memory deck.
///
/// Allows user to input:
/// - Verse reference (e.g., John 3:16)
/// - Verse text
/// - Language selection (English, Hindi, Malayalam)
///
/// Validates inputs and triggers the provided callback on submit.
class AddManualVerseDialog extends StatefulWidget {
  final Function({
    required String verseReference,
    required String verseText,
    required String language,
  }) onSubmit;

  /// Optional default language to pre-select
  final VerseLanguage defaultLanguage;

  const AddManualVerseDialog({
    super.key,
    required this.onSubmit,
    this.defaultLanguage = VerseLanguage.english,
  });

  /// Shows the add manual verse dialog.
  static void show(
    BuildContext context, {
    required Function({
      required String verseReference,
      required String verseText,
      required String language,
    }) onSubmit,
    VerseLanguage defaultLanguage = VerseLanguage.english,
  }) {
    showDialog(
      context: context,
      builder: (dialogContext) => AddManualVerseDialog(
        onSubmit: onSubmit,
        defaultLanguage: defaultLanguage,
      ),
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
  late VerseLanguage _selectedLanguage;

  @override
  void initState() {
    super.initState();
    _selectedLanguage = widget.defaultLanguage;
  }

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
        language: _selectedLanguage.code,
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
            const SizedBox(height: 16),
            DropdownButtonFormField<VerseLanguage>(
              value: _selectedLanguage,
              decoration: const InputDecoration(
                labelText: 'Language',
                border: OutlineInputBorder(),
              ),
              items: VerseLanguage.values.map((language) {
                return DropdownMenuItem(
                  value: language,
                  child: Text(language.displayName),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedLanguage = value);
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
