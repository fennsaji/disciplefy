import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';

/// Meaning of an [showAppSnackBar] message, shown as a small leading icon.
enum AppSnackTone { neutral, success, error, warning }

/// Shows the app-wide floating snackbar.
///
/// The surface is always dark so the message reads the same everywhere: the
/// raised card fill on dark, the dark ink on light. The [tone] only changes
/// the leading icon. Any snackbar already on screen is cleared first so
/// messages never queue up behind each other.
///
/// Floating snackbars are laid out by the root [Scaffold], which already sits
/// them above its bottom navigation bar, so on tab screens they clear the
/// floating dock without extra margin.
void showAppSnackBar(
  BuildContext context,
  String message, {
  AppSnackTone tone = AppSnackTone.neutral,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  final palette = ReaderPalette.of(context);
  final surface = palette.isDark ? palette.raised : palette.text;
  const ink = Color(0xFFF2F2F4);
  final (icon, iconColor) = _toneIcon(tone);

  messenger
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        // A SnackBar with an action defaults to persist:true, which never
        // times out and blocks every later snackbar behind it.
        persist: false,
        backgroundColor: surface,
        elevation: 0,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: palette.isDark
              ? BorderSide(color: palette.outline)
              : BorderSide.none,
        ),
        content: Row(
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: AppFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: ink,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
        action: actionLabel == null
            ? null
            : SnackBarAction(
                label: actionLabel,
                textColor: AppColors.brandGold,
                onPressed: onAction ?? () {},
              ),
      ),
    );
}

(IconData, Color) _toneIcon(AppSnackTone tone) => switch (tone) {
      AppSnackTone.neutral => (
          Icons.info_outline_rounded,
          AppColors.brandGold,
        ),
      AppSnackTone.success => (
          Icons.check_circle_rounded,
          AppColors.success,
        ),
      AppSnackTone.error => (Icons.error_rounded, AppColors.error),
      AppSnackTone.warning => (
          Icons.warning_amber_rounded,
          AppColors.warning,
        ),
    };
