import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';

/// Shows the block confirmation dialog.
///
/// Returns true when the user confirms. The copy states that the block is
/// mutual and global, which is what App Review looks for.
Future<bool> showBlockUserConfirmation(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.blockUserConfirmTitle),
      content: Text(l10n.blockUserConfirmBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.blockUserCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(
            l10n.blockUserConfirmAction,
            style: const TextStyle(color: AppColors.error),
          ),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
