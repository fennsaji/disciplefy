import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/shared/widgets/app_snackbar.dart';

/// Copies [text] to the system clipboard and confirms with the app's
/// standard "Copied to clipboard" snackbar. Works on web, Android and iOS.
Future<void> copyCommunityText(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  showAppSnackBar(
    context,
    context.tr(TranslationKeys.studyGuideCopiedToClipboard),
    tone: AppSnackTone.success,
  );
}

/// Gives its subtree a key for a [PopupMenuButton], so a long-press anywhere
/// on a post or reply can open the same menu as its ⋮ button.
class LongPressMenuScope extends StatefulWidget {
  final Widget Function(
    BuildContext context,
    GlobalKey<PopupMenuButtonState<String>> menuKey,
  ) builder;

  const LongPressMenuScope({required this.builder, super.key});

  @override
  State<LongPressMenuScope> createState() => _LongPressMenuScopeState();
}

class _LongPressMenuScopeState extends State<LongPressMenuScope> {
  final _menuKey = GlobalKey<PopupMenuButtonState<String>>();

  @override
  Widget build(BuildContext context) => widget.builder(context, _menuKey);
}

/// Opens the menu behind [menuKey], if one is mounted.
void openLongPressMenu(GlobalKey<PopupMenuButtonState<String>> menuKey) {
  final menu = menuKey.currentState;
  if (menu == null) return;
  HapticFeedback.selectionClick();
  menu.showButtonMenu();
}
