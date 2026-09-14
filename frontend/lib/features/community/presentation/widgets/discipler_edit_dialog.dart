import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';

/// Lets a mentor rewrite something the Discipler posted or replied.
///
/// Returns the trimmed new text, or `null` when cancelled or unchanged.
Future<String?> showDisciplerEditDialog(
  BuildContext context, {
  required String initialText,
  required int maxLength,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) =>
        _DisciplerEditDialog(initialText: initialText, maxLength: maxLength),
  );
}

class _DisciplerEditDialog extends StatefulWidget {
  final String initialText;
  final int maxLength;

  const _DisciplerEditDialog({
    required this.initialText,
    required this.maxLength,
  });

  @override
  State<_DisciplerEditDialog> createState() => _DisciplerEditDialogState();
}

class _DisciplerEditDialogState extends State<_DisciplerEditDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialText);

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final text = _controller.text.trim();
    final canSave = text.isNotEmpty && text != widget.initialText.trim();

    return AlertDialog(
      title: Text(l10n.disciplerEditTitle),
      content: SizedBox(
        width: 520,
        child: TextField(
          controller: _controller,
          autofocus: true,
          minLines: 4,
          maxLines: 12,
          maxLength: widget.maxLength,
          keyboardType: TextInputType.multiline,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            helperText: l10n.disciplerEditHint,
            helperMaxLines: 2,
            border: const OutlineInputBorder(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: canSave ? () => Navigator.of(context).pop(text) : null,
          child: Text(l10n.editFellowshipSave),
        ),
      ],
    );
  }
}
