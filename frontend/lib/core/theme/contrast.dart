import 'dart:math' as math;
import 'dart:ui';

/// Contrast helpers for keeping text legible on either theme.
///
/// Brand and semantic accents are picked to look right as *fills* — buttons,
/// chips, borders. Reused directly as a text colour they can fall well below a
/// readable ratio: the create-post sheet painted a selected type's label in
/// `brandPrimary` (#4F46E5) on a #1F1E2F card, which measures 2.6:1 against a
/// WCAG AA minimum of 4.5:1.
///
/// [ensureContrast] keeps the hue but moves the colour toward white or black
/// until it clears the required ratio, so an accent stays recognisable while
/// becoming readable.
extension ContrastMath on Color {
  /// WCAG relative luminance.
  double get relativeLuminance {
    double channel(double v) =>
        v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4) as double;
    return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b);
  }
}

/// WCAG contrast ratio between two opaque colours (1.0 – 21.0).
double contrastRatio(Color a, Color b) {
  final la = a.relativeLuminance;
  final lb = b.relativeLuminance;
  final lighter = math.max(la, lb);
  final darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

/// WCAG AA minimum for normal-sized body text.
const double kMinContrastNormalText = 4.5;

/// WCAG AA minimum for large text (>=18pt, or >=14pt bold) and for graphics.
const double kMinContrastLargeText = 3.0;

/// Returns [foreground] adjusted so it meets [minRatio] against [background].
///
/// The colour is blended toward white on dark backgrounds and toward black on
/// light ones, in small steps, stopping as soon as the ratio is met — so the
/// result is the closest readable version of the original rather than a flat
/// white or black. Returns the original when it already passes.
Color ensureContrast(
  Color foreground,
  Color background, {
  double minRatio = kMinContrastNormalText,
}) {
  if (contrastRatio(foreground, background) >= minRatio) return foreground;

  // Push away from the background: lighten on dark grounds, darken on light.
  final target = background.relativeLuminance < 0.5
      ? const Color(0xFFFFFFFF)
      : const Color(0xFF000000);

  var best = foreground;
  for (var step = 1; step <= 20; step++) {
    final blended = Color.lerp(foreground, target, step / 20)!;
    best = blended;
    if (contrastRatio(blended, background) >= minRatio) return blended;
  }
  // Fully blended still short (background is mid-grey): return the extreme.
  return best;
}
