import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/shared/widgets/popup.dart';

/// Confirmation dialog for community actions (leave, delete, remove a member,
/// block someone…), in the shared popup style.
///
/// Returns true only when the confirm action was tapped. A [destructive]
/// confirm is drawn in the error colour so it never reads as the safe choice.
Future<bool> showCommunityConfirmDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  required String cancelLabel,
  bool destructive = false,
  IconData? icon,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => PopupDialog(
      children: [
        PopupHeader(
          icon: icon == null ? null : PopupIconCircle(icon: icon),
          title: title,
          body: body,
        ),
        const SizedBox(height: 24),
        if (destructive)
          CommunityDestructiveButton(
            label: confirmLabel,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          )
        else
          PopupPrimaryButton(
            label: confirmLabel,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        const SizedBox(height: 4),
        PopupTextButton(
          label: cancelLabel,
          onPressed: () => Navigator.of(dialogContext).pop(false),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// Full-width pill in the error colour for irreversible actions.
class CommunityDestructiveButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const CommunityDestructiveButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    // Red-700 keeps white ink above 4.5:1 in both themes.
    const fill = AppColors.errorDark;
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: fill,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(50),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: const StadiumBorder(),
          elevation: 0,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
