import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/shared/widgets/v2_popup.dart';

/// V2 popup asking a guest (or signed-out) user to sign in before an action
/// that needs an account, e.g. saving a study guide.
class SignInRequiredDialog extends StatelessWidget {
  final String title;
  final String message;
  final String signInLabel;
  final String cancelLabel;

  /// Runs after the dialog has closed.
  final VoidCallback onSignIn;

  const SignInRequiredDialog({
    super.key,
    required this.title,
    required this.message,
    required this.signInLabel,
    required this.cancelLabel,
    required this.onSignIn,
  });

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String message,
    required String signInLabel,
    required String cancelLabel,
    required VoidCallback onSignIn,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => SignInRequiredDialog(
        title: title,
        message: message,
        signInLabel: signInLabel,
        cancelLabel: cancelLabel,
        onSignIn: onSignIn,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopupDialog(
      children: [
        PopupHeader(
          icon: const PopupIconCircle(icon: Icons.person_outline_rounded),
          eyebrow: context.tr(TranslationKeys.popupSignInEyebrow),
          title: title,
          body: message,
        ),
        const SizedBox(height: 24),
        PopupPrimaryButton(
          key: const Key('sign_in_required_sign_in'),
          label: signInLabel,
          onPressed: () {
            Navigator.of(context).pop();
            onSignIn();
          },
        ),
        const SizedBox(height: 4),
        PopupTextButton(
          key: const Key('sign_in_required_cancel'),
          label: cancelLabel,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
