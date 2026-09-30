import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/community_form_parts.dart';
import 'package:disciplefy_bible_study/shared/widgets/popup.dart';

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

    return PopupDialog(
      maxWidth: 520,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The hint sits under the title rather than as field helper text, where
        // the character counter squeezed it until it cut off on small phones.
        PopupHeader(
          title: l10n.disciplerEditTitle,
          body: l10n.disciplerEditHint,
          centered: false,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _controller,
          autofocus: true,
          minLines: 4,
          maxLines: 12,
          maxLength: widget.maxLength,
          keyboardType: TextInputType.multiline,
          textCapitalization: TextCapitalization.sentences,
          style: communityInputStyle(context),
          decoration: communityInputDecoration(context),
        ),
        const SizedBox(height: 20),
        PopupPrimaryButton(
          label: l10n.editFellowshipSave,
          onPressed: canSave ? () => Navigator.of(context).pop(text) : null,
        ),
        const SizedBox(height: 4),
        PopupTextButton(
          label: l10n.cancel,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
