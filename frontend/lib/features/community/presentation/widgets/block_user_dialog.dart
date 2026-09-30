import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/community_confirm_dialog.dart';

/// Shows the block confirmation dialog.
///
/// Returns true when the user confirms. The copy states that the block is
/// mutual and global, which is what App Review looks for.
Future<bool> showBlockUserConfirmation(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return showCommunityConfirmDialog(
    context,
    icon: Icons.block,
    title: l10n.blockUserConfirmTitle,
    body: l10n.blockUserConfirmBody,
    confirmLabel: l10n.blockUserConfirmAction,
    cancelLabel: l10n.blockUserCancel,
    destructive: true,
  );
}
