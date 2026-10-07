import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';

/// Building blocks for dialogs and sheets in the "Scripture hero" style:
/// a flat card surface (#17171C dark / white light), a soft tinted icon
/// circle, a gold uppercase eyebrow, a Poppins title, muted Inter body, a
/// primary pill and a plain text secondary action.
///
/// No blur, glow or per-frame animation, so they stay cheap on low-end phones.

/// Colour of an icon circle: gold for rewards/achievements, indigo otherwise.
enum PopupTone { gold, indigo }

/// Corner radius shared by popups.
const double kPopupRadius = 24;

/// Card surface used as the body of a popup dialog.
///
/// Centred, at most [maxWidth] wide, scrolls when taller than the screen
/// (small phones, large text).
class PopupDialog extends StatelessWidget {
  final List<Widget> children;
  final CrossAxisAlignment crossAxisAlignment;
  final EdgeInsetsGeometry padding;
  final double maxWidth;

  const PopupDialog({
    super.key,
    required this.children,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.padding = const EdgeInsets.fromLTRB(24, 28, 24, 16),
    this.maxWidth = 380,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Dialog(
      backgroundColor: palette.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kPopupRadius),
        side: BorderSide(color: palette.hairline),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SingleChildScrollView(
          padding: padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: crossAxisAlignment,
            children: children,
          ),
        ),
      ),
    );
  }
}

/// Bottom-sheet body with a drag handle, rounded top corners and room for
/// the system navigation bar. Show it with a transparent sheet background.
class PopupSheet extends StatelessWidget {
  final List<Widget> children;
  final CrossAxisAlignment crossAxisAlignment;
  final EdgeInsets padding;

  const PopupSheet({
    super.key,
    required this.children,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
    this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 12),
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom +
        MediaQuery.viewInsetsOf(context).bottom;
    return Container(
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(kPopupRadius)),
        border: Border(top: BorderSide(color: palette.hairline)),
      ),
      child: SingleChildScrollView(
        padding: padding.copyWith(bottom: padding.bottom + bottom),
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
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Soft tinted circle holding an icon (or any small [child], e.g. a glyph).
class PopupIconCircle extends StatelessWidget {
  final IconData? icon;
  final Widget? child;
  final PopupTone tone;
  final double size;

  const PopupIconCircle({
    super.key,
    this.icon,
    this.child,
    this.tone = PopupTone.indigo,
    this.size = 56,
  }) : assert(icon != null || child != null);

  /// Tint and icon colour for [tone] in the current theme.
  static (Color fill, Color ink) colorsFor(
      BuildContext context, PopupTone tone) {
    final palette = ReaderPalette.of(context);
    return switch (tone) {
      PopupTone.gold => (
          palette.gold.withValues(alpha: palette.isDark ? 0.16 : 0.12),
          palette.gold,
        ),
      PopupTone.indigo => (
          AppColors.brandPrimary.withValues(alpha: palette.isDark ? 0.24 : 0.1),
          palette.accentIcon,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final (fill, ink) = colorsFor(context, tone);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: child ?? Icon(icon, size: size * 0.46, color: ink),
    );
  }
}

/// Gold, uppercase, tracked label above a popup title.
class PopupEyebrow extends StatelessWidget {
  final String text;
  final TextAlign textAlign;

  const PopupEyebrow(this.text, {super.key, this.textAlign = TextAlign.center});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Text(
      text.toUpperCase(),
      textAlign: textAlign,
      style: AppFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
        color: palette.gold,
      ),
    );
  }
}

/// Icon circle, eyebrow, Poppins title and muted body, stacked.
class PopupHeader extends StatelessWidget {
  final Widget? icon;
  final String? eyebrow;
  final String title;
  final String? body;
  final bool centered;

  const PopupHeader({
    super.key,
    this.icon,
    this.eyebrow,
    required this.title,
    this.body,
    this.centered = true,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final align = centered ? TextAlign.center : TextAlign.start;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[icon!, const SizedBox(height: 16)],
        if (eyebrow != null) ...[
          PopupEyebrow(eyebrow!, textAlign: align),
          const SizedBox(height: 8),
        ],
        Text(
          title,
          textAlign: align,
          style: AppFonts.poppins(
            fontSize: 21,
            fontWeight: FontWeight.w600,
            color: palette.text,
            height: 1.25,
          ),
        ),
        if (body != null) ...[
          const SizedBox(height: 8),
          Text(
            body!,
            textAlign: align,
            style: AppFonts.inter(
              fontSize: 14,
              color: palette.muted,
              height: 1.45,
            ),
          ),
        ],
      ],
    );
  }
}

/// Full-width primary pill: white with indigo ink on dark, indigo with white
/// ink on light.
class PopupPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  const PopupPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: palette.ctaFill,
          foregroundColor: palette.ctaInk,
          minimumSize: const Size.fromHeight(50),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: const StadiumBorder(),
          elevation: 0,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: AppFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: palette.ctaInk,
                ),
              ),
            ),
            if (icon != null) ...[
              const SizedBox(width: 8),
              Icon(icon, size: 18, color: palette.ctaInk),
            ],
          ],
        ),
      ),
    );
  }
}

/// Plain text secondary action ("Not now", "Maybe later").
class PopupTextButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const PopupTextButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: palette.muted,
          minimumSize: const Size.fromHeight(44),
          shape: const StadiumBorder(),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: palette.muted,
          ),
        ),
      ),
    );
  }
}

/// Raised, rounded panel for supporting details inside a popup (balances,
/// plan lists).
class PopupPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const PopupPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: palette.raised,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}
