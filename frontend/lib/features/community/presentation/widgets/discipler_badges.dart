import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/reader_palette.dart';

/// Small "AI" chip appended next to the Discipler display name to signal
/// AI-generated content.
class DisciplerAiChip extends StatelessWidget {
  const DisciplerAiChip({super.key});

  @override
  Widget build(BuildContext context) {
    // The primary is the theme's gold: bright on dark, where the label has to
    // be ink, and deep on light, where white clears AA.
    final fill = context.appPrimary;
    final onFill = ThemeData.estimateBrightnessForColor(fill) == Brightness.dark
        ? Colors.white
        : ReaderPalette.ink;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        AppLocalizations.of(context)!.disciplerAiChip,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: onFill,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// Avatar used for the Discipler AI helper wherever a post/comment author
/// avatar would normally appear.
/// The Discipler mark as a flat white glyph on a transparent background.
///
/// For placing directly on a coloured surface — a filled button, a coloured
/// header — where [DisciplerAvatar]'s ink disc would read as a sticker pasted
/// onto the button rather than as an icon belonging to it.
class DisciplerGlyph extends StatelessWidget {
  final double size;

  /// Which flat colourway to draw. White for ink/dark fills, ink for white
  /// fills (e.g. the dark-theme "Ask Discipler" pill).
  final DisciplerGlyphVariant variant;

  const DisciplerGlyph({
    this.size = 22,
    this.variant = DisciplerGlyphVariant.white,
    super.key,
  });

  /// The glyph that reads on the reader's primary call-to-action: ink on the
  /// white dark-theme pill, white on the ink light-theme pill.
  const DisciplerGlyph.onCta({
    this.size = 22,
    required bool isDark,
    super.key,
  }) : variant =
            isDark ? DisciplerGlyphVariant.ink : DisciplerGlyphVariant.white;

  @override
  Widget build(BuildContext context) {
    // One flat white asset, tinted to ink where the fill is white.
    return Image.asset(
      'assets/brand/discipler-glyph-white.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      color: switch (variant) {
        DisciplerGlyphVariant.white => null,
        DisciplerGlyphVariant.ink => ReaderPalette.ink,
      },
      colorBlendMode: BlendMode.srcIn,
    );
  }
}

/// Colourways of [DisciplerGlyph].
enum DisciplerGlyphVariant { white, ink }

class DisciplerAvatar extends StatelessWidget {
  final double radius;

  const DisciplerAvatar({this.radius = 20, super.key});

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;

    // The Discipler mark is a fixed brand asset — the Disciplefy symbol in gold
    // on ink, with the AI spark and its glow held inside the disc — so it is
    // rendered as-is rather than recoloured per theme.
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: Image.asset(
          'assets/brand/discipler-avatar.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

/// Small disclosure note shown under Discipler-authored content.
class DisciplerFooterNote extends StatelessWidget {
  const DisciplerFooterNote({super.key});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(Icons.info_outline_rounded,
              size: 12, color: context.appTextTertiary),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              AppLocalizations.of(context)!.disciplerFooter,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10,
                color: context.appTextTertiary,
              ),
            ),
          ),
        ],
      );
}
