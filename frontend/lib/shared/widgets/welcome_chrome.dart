import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';

/// Shared chrome for the pre-auth screens (onboarding, login, email auth,
/// language selection) in the "V1 Photo Story" design.

/// Photos used by the pre-auth screens.
class WelcomePhotos {
  WelcomePhotos._();

  static const String wheatDawn = 'assets/images/hero/wheat_dawn.jpg';
  static const String greenHills = 'assets/images/hero/green_hills.jpg';
  static const String valleyMist = 'assets/images/hero/valley_mist.jpg';
}

/// Decode width for a 2000px-wide 3:2 photo covering a [width] x [height]
/// box: only the pixels shown, never the full source.
int welcomePhotoCacheWidth(BuildContext context, double width, double height) {
  final dpr = MediaQuery.devicePixelRatioOf(context);
  final coverWidth = math.max(width, height * 1.5);
  return math.max(1, math.min(2000, (coverWidth * dpr).round()));
}

/// Logo + tracked gold "DISCIPLEFY" wordmark.
class WelcomeBrandRow extends StatelessWidget {
  const WelcomeBrandRow({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Semantics(
      label: 'Disciplefy',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/images/logo_transparent.png',
            width: 26,
            height: 26,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const SizedBox(width: 26),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              'DISCIPLEFY',
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: AppFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 3.6,
                color: palette.gold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small tracked gold label above a title ("DAILY VERSE", "WELCOME BACK").
class WelcomeEyebrow extends StatelessWidget {
  final String text;
  final Color? color;

  const WelcomeEyebrow(this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Text(
      text.toUpperCase(),
      style: AppFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 2.2,
        color: color ?? palette.gold,
      ),
    );
  }
}

/// Large Poppins title used across the pre-auth screens.
class WelcomeTitle extends StatelessWidget {
  final String text;
  final double fontSize;

  const WelcomeTitle(this.text, {super.key, this.fontSize = 30});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Text(
      text,
      style: AppFonts.poppins(
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: palette.text,
      ),
    );
  }
}

/// A scenery photo that fades into the page background at its bottom edge.
///
/// Dark: a black shade over the photo deepening into the page. Light: a wash
/// of the page colour so dark ink reads on it.
class WelcomePhotoBackdrop extends StatelessWidget {
  final String asset;

  /// Where the photo is anchored inside the box.
  final Alignment alignment;

  const WelcomePhotoBackdrop({
    super.key,
    required this.asset,
    this.alignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final page = palette.page;
    final shade = palette.isDark
        ? [
            Colors.black.withValues(alpha: 0.38),
            Colors.black.withValues(alpha: 0.34),
            page.withValues(alpha: 0.74),
            page,
          ]
        : [
            page.withValues(alpha: 0.34),
            page.withValues(alpha: 0.42),
            page.withValues(alpha: 0.82),
            page,
          ];

    return ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, box) => Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              asset,
              fit: BoxFit.cover,
              alignment: alignment,
              cacheWidth:
                  welcomePhotoCacheWidth(context, box.maxWidth, box.maxHeight),
              errorBuilder: (_, __, ___) => ColoredBox(color: page),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: shade,
                  stops: const [0, 0.35, 0.62, 1],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-width primary pill: white with indigo ink on dark, indigo with white
/// ink on light. Shows a spinner instead of the label while [isLoading].
class WelcomePrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  /// When false the pill hugs its label (onboarding's Continue).
  final bool expand;

  const WelcomePrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final button = FilledButton(
      onPressed: isLoading ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: palette.ctaFill,
        foregroundColor: palette.ctaInk,
        disabledBackgroundColor: palette.ctaFill.withValues(alpha: 0.5),
        disabledForegroundColor: palette.ctaInk.withValues(alpha: 0.7),
        minimumSize: Size(expand ? double.infinity : 136, 54),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
        shape: const StadiumBorder(),
        elevation: 0,
      ),
      child: isLoading
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(palette.ctaInk),
              ),
            )
          : Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: AppFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: palette.ctaInk,
              ),
            ),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Soft indigo glow behind the onboarding previews (a static gradient, no
/// blur).
class WelcomeGlow extends StatelessWidget {
  final Alignment center;

  const WelcomeGlow({super.key, this.center = const Alignment(0, -0.35)});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final glow = palette.isDark
        ? const Color(0xFF3730A3).withValues(alpha: 0.38)
        : const Color(0xFF6366F1).withValues(alpha: 0.10);
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: center,
            radius: 0.9,
            colors: [glow, glow.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}
