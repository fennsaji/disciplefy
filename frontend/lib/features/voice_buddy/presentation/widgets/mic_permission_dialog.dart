import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/shared/widgets/popup.dart';

/// Explains what a declined microphone blocks and offers the way back.
///
/// Deliberately not an error: typing still works. The primary action asks
/// again, or — when the OS will no longer prompt ([permanentlyDenied]) —
/// opens the app's settings. The secondary action switches to typing.
class MicPermissionDialog extends StatelessWidget {
  final bool permanentlyDenied;

  /// Ask again / open settings. The dialog is already closed when called.
  final VoidCallback onPrimary;

  /// Type instead. The dialog is already closed when called.
  final VoidCallback onTypeInstead;

  const MicPermissionDialog({
    super.key,
    required this.permanentlyDenied,
    required this.onPrimary,
    required this.onTypeInstead,
  });

  @override
  Widget build(BuildContext context) {
    return PopupDialog(
      children: [
        PopupHeader(
          icon: PopupIconCircle(
            icon: permanentlyDenied ? Icons.mic_off_rounded : Icons.mic_none,
            size: 64,
          ),
          title: context.tr(TranslationKeys.micPermissionTitle),
          body: context.tr(permanentlyDenied
              ? TranslationKeys.micPermissionBlockedMessage
              : TranslationKeys.micPermissionMessage),
        ),
        const SizedBox(height: 24),
        PopupPrimaryButton(
          label: context.tr(permanentlyDenied
              ? TranslationKeys.micPermissionOpenSettings
              : TranslationKeys.micPermissionAllow),
          icon: permanentlyDenied ? Icons.settings_outlined : Icons.mic_none,
          onPressed: () {
            Navigator.of(context).pop();
            onPrimary();
          },
        ),
        const SizedBox(height: 4),
        PopupTextButton(
          label: context.tr(TranslationKeys.micPermissionTypeInstead),
          onPressed: () {
            Navigator.of(context).pop();
            onTypeInstead();
          },
        ),
      ],
    );
  }
}
