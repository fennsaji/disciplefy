import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/widgets/settings_group.dart';
import 'package:disciplefy_bible_study/shared/widgets/app_snackbar.dart';
import 'package:disciplefy_bible_study/shared/widgets/popup.dart';
import 'package:disciplefy_bible_study/shared/widgets/sheet_scroll_view.dart';

/// Opens a modal bottom sheet in the settings style. [builder] usually
/// returns a [SettingsSheetFrame].
Future<T?> showSettingsSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) =>
    showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: builder,
    );

/// Sheet chrome: card fill, 26 top radius, drag handle, Poppins title and
/// optional muted description. Content scrolls when taller than the screen
/// while keeping pull-to-dismiss (see [SheetScrollView]).
class SettingsSheetFrame extends StatelessWidget {
  final String? title;
  final String? description;
  final List<Widget> children;
  final CrossAxisAlignment crossAxisAlignment;

  /// Adds the keyboard inset to the bottom padding (sheets with a field).
  final bool avoidKeyboard;

  const SettingsSheetFrame({
    super.key,
    this.title,
    this.description,
    required this.children,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
    this.avoidKeyboard = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final keyboard =
        avoidKeyboard ? MediaQuery.viewInsetsOf(context).bottom : 0.0;
    return Container(
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      ),
      padding: EdgeInsets.only(bottom: keyboard),
      child: SafeArea(
        top: false,
        child: SheetScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: crossAxisAlignment,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (title != null)
                Text(
                  title!,
                  style: AppFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: palette.text,
                  ),
                ),
              if (description != null) ...[
                const SizedBox(height: 6),
                Text(
                  description!,
                  style: AppFonts.inter(
                    fontSize: 13,
                    color: palette.muted,
                    height: 1.45,
                  ),
                ),
              ],
              if (title != null || description != null)
                const SizedBox(height: 18),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

/// A group card for use inside a sheet: sheets share the card fill, so the
/// group sits on the raised fill instead to stay visible.
class SettingsSheetGroup extends StatelessWidget {
  final List<Widget> children;

  const SettingsSheetGroup({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Material(
      color: palette.isDark ? palette.raised : palette.page,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: palette.hairline),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SettingsHairline(),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Dialog in the settings style on the shared [PopupDialog] shell: card fill,
/// hairline border, left-aligned Poppins title, muted body and pill actions.
class SettingsDialog extends StatelessWidget {
  final String title;
  final Color? titleColor;
  final Widget content;
  final List<Widget> actions;

  const SettingsDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return PopupDialog(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      maxWidth: 420,
      children: [
        Text(
          title,
          style: AppFonts.poppins(
            fontSize: 19,
            fontWeight: FontWeight.w600,
            color: titleColor ?? palette.text,
          ),
        ),
        const SizedBox(height: 12),
        DefaultTextStyle.merge(
          style: AppFonts.inter(
            fontSize: 14.5,
            color: palette.muted,
            height: 1.5,
          ),
          child: content,
        ),
        const SizedBox(height: 22),
        // Pill actions stack when a label would not fit side by side.
        if (actions.every((a) => a is SettingsButton))
          SettingsButtonRow(
            buttons: actions.cast<SettingsButton>(),
          )
        else
          Row(
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(child: actions[i]),
              ],
            ],
          ),
      ],
    );
  }
}

/// Floating snackbar used across the settings screens. Delegates to the
/// app-wide [showAppSnackBar]; [backgroundColor] picks the tone (success
/// green, error/red, warning amber, anything else neutral).
void showSettingsSnackBar(
  BuildContext context,
  String message,
  Color backgroundColor,
) {
  final errorColors = <Color>{
    Theme.of(context).colorScheme.error,
    AppColors.error,
    AppColors.errorDark,
    Colors.red,
  };
  final tone = backgroundColor == AppColors.success
      ? AppSnackTone.success
      : errorColors.contains(backgroundColor)
          ? AppSnackTone.error
          : backgroundColor == AppColors.warning
              ? AppSnackTone.warning
              : AppSnackTone.neutral;
  showAppSnackBar(context, message, tone: tone);
}

/// Opens a non-dismissible, palette-styled busy indicator over the current
/// screen. Close it with `Navigator.of(context, rootNavigator: true).pop()`.
Future<void> showSettingsLoader(BuildContext context) => showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const SettingsLoaderCard(),
    );

/// Small card with a gold spinner, shown while a settings action runs.
class SettingsLoaderCard extends StatelessWidget {
  const SettingsLoaderCard({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Center(
      child: Container(
        width: 84,
        height: 84,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: palette.hairline),
        ),
        child: SizedBox(
          width: 30,
          height: 30,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: palette.gold,
            backgroundColor: palette.raised,
          ),
        ),
      ),
    );
  }
}
