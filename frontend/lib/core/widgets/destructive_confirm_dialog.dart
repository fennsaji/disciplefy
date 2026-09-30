import 'package:flutter/material.dart';

import '../../features/settings/presentation/widgets/settings_group.dart';
import '../../shared/widgets/popup.dart';
import '../constants/app_fonts.dart';
import '../extensions/translation_extension.dart';
import '../i18n/translation_keys.dart';
import '../theme/reader_palette.dart';

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
    final palette = ReaderPalette.of(context);
    final red = SettingsToneColors.of(context, SettingsTone.red);
    final bodyStyle = AppFonts.inter(
      fontSize: 14,
      color: palette.muted,
      height: 1.45,
    );

    return PopupDialog(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration:
                  BoxDecoration(color: red.fill, shape: BoxShape.circle),
              child: Icon(
                Icons.warning_amber_rounded,
                color: red.foreground,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.title,
                style: AppFonts.poppins(
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                  color: palette.text,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        for (final consequence in widget.consequences)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('•  ', style: bodyStyle),
                Expanded(child: Text(consequence, style: bodyStyle)),
              ],
            ),
          ),
        const SizedBox(height: 4),
        Text(
          context.tr(TranslationKeys.resetProgressIrreversible),
          style: AppFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: red.foreground,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _controller,
          autofocus: true,
          autocorrect: false,
          enableSuggestions: false,
          style: AppFonts.inter(fontSize: 15, color: palette.text),
          decoration: InputDecoration(
            filled: true,
            fillColor: palette.raised,
            labelText: context
                .tr(TranslationKeys.resetProgressTypeToConfirm)
                .replaceAll('{word}', widget.confirmWord),
            labelStyle: AppFonts.inter(fontSize: 14, color: palette.muted),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: palette.outline),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: palette.outline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: red.foreground, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 20),
        SettingsButtonRow(
          buttons: [
            SettingsButton(
              label: context.tr(TranslationKeys.resetProgressCancel),
              kind: SettingsButtonKind.neutral,
              onPressed: () => Navigator.of(context).pop(false),
            ),
            SettingsButton(
              label: widget.confirmLabel,
              kind: SettingsButtonKind.destructive,
              onPressed:
                  _canConfirm ? () => Navigator.of(context).pop(true) : null,
            ),
          ],
        ),
      ],
    );
  }
}
