import 'package:flutter/material.dart';

import '../extensions/translation_extension.dart';
import '../i18n/translation_keys.dart';

/// Confirmation dialog for irreversible destructive actions.
///
/// The confirm button stays disabled until the user types [confirmWord],
/// which makes an accidental tap impossible. [consequences] is rendered as a
/// bulleted list so the user sees exactly what is about to be deleted.
///
/// The comparison is case-insensitive and trims surrounding whitespace —
/// the friction should come from having to read and type, not from matching
/// capitalisation.
///
/// Returns `true` only when the user typed the word and pressed confirm.
class DestructiveConfirmDialog extends StatefulWidget {
  /// Dialog headline, e.g. "Reset memory verses?".
  final String title;

  /// Bulleted list of what will be deleted.
  final List<String> consequences;

  /// Word the user must type. Pass a localized value.
  final String confirmWord;

  /// Label for the destructive confirm button.
  final String confirmLabel;

  const DestructiveConfirmDialog({
    super.key,
    required this.title,
    required this.consequences,
    required this.confirmWord,
    required this.confirmLabel,
  });

  /// Shows the dialog and resolves to the user's decision.
  ///
  /// Resolves to `false` if the dialog is dismissed by tapping outside.
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required List<String> consequences,
    required String confirmWord,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => DestructiveConfirmDialog(
        title: title,
        consequences: consequences,
        confirmWord: confirmWord,
        confirmLabel: confirmLabel,
      ),
    );
    return result ?? false;
  }

  @override
  State<DestructiveConfirmDialog> createState() =>
      _DestructiveConfirmDialogState();
}

class _DestructiveConfirmDialogState extends State<DestructiveConfirmDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _canConfirm = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  /// English fallback accepted in every locale, in addition to the localized
  /// [DestructiveConfirmDialog.confirmWord]. A hi/ml user running the app
  /// without an Indic keyboard installed cannot type 'रीसेट' / 'റീസെറ്റ്',
  /// which would otherwise permanently lock them out of this feature. This
  /// is strictly more permissive than requiring only the localized word —
  /// the user still has to read and type a specific word, so the
  /// confirmation friction is unchanged. The hint text still shows only the
  /// localized word.
  static const _englishFallbackWord = 'RESET';

  void _onTextChanged() {
    final input = _controller.text.trim().toLowerCase();
    final matches = input == widget.confirmWord.trim().toLowerCase() ||
        input == _englishFallbackWord.toLowerCase();
    if (matches != _canConfirm) {
      setState(() => _canConfirm = matches);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final errorColor = theme.colorScheme.error;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: errorColor),
          const SizedBox(width: 12),
          Expanded(child: Text(widget.title)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final consequence in widget.consequences)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  '),
                    Expanded(child: Text(consequence)),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Text(
              context.tr(TranslationKeys.resetProgressIrreversible),
              style: theme.textTheme.bodySmall?.copyWith(
                color: errorColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: context
                    .tr(TranslationKeys.resetProgressTypeToConfirm)
                    .replaceAll('{word}', widget.confirmWord),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(context.tr(TranslationKeys.resetProgressCancel)),
        ),
        FilledButton(
          onPressed: _canConfirm ? () => Navigator.of(context).pop(true) : null,
          style: FilledButton.styleFrom(
            backgroundColor: errorColor,
            foregroundColor: theme.colorScheme.onError,
          ),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
