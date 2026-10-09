import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';

/// Primary pill button of the community screens: white with ink text on
/// dark, ink with white text on light ([ReaderPalette.ctaFill]/`ctaInk`).
///
/// The design draws card actions ("Join", "Start study", "Post now") as
/// 32px pills (13/700) and floating or full-width actions ("Join a
/// fellowship", "New post", "Advance to next lesson") as 40px pills
/// (14/600). Either way the tap area is at least 40px tall; the label wraps
/// instead of truncating.
class CommunityCtaPill extends StatelessWidget {
  final String label;
  final IconData? icon;

  /// Null disables the pill.
  final VoidCallback? onPressed;

  /// Shows a spinner in place of the icon and ignores taps.
  final bool loading;

  /// A floating 40px action with a drop shadow ("Join a fellowship").
  final bool large;

  /// A 40px pill without the shadow (full-width or standalone actions).
  final bool tall;

  /// Tighter padding for a pill sharing a row with other actions.
  final bool compact;

  const CommunityCtaPill({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.large = false,
    this.tall = false,
    this.compact = false,
  });

  /// Visible height of a card-action pill and of a large/tall one.
  static const double smallHeight = 32;
  static const double largeHeight = 40;

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final enabled = onPressed != null && !loading;
    final fill = enabled || loading
        ? palette.ctaFill
        : palette.ctaFill.withValues(alpha: 0.5);
    final ink = palette.ctaInk;
    final big = large || tall;
    final height = big ? largeHeight : smallHeight;
    final radius = BorderRadius.circular(height / 2);

    // Its own semantics node, so a screen reader reaches the pill on its own
    // instead of folding it into the surrounding card, and it carries the
    // tap action itself (the InkWell's is excluded with the label).
    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      focusable: enabled,
      label: label,
      onTap: enabled ? onPressed : null,
      excludeSemantics: true,
      // The small pill keeps a 40px tap area: the 4px above and below it
      // still press it.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onPressed : null,
        child: Padding(
          padding: EdgeInsets.symmetric(
              vertical: big ? 0 : (largeHeight - smallHeight) / 2),
          child: Material(
            color: fill,
            borderRadius: radius,
            elevation: large ? 6 : 0,
            shadowColor: Colors.black.withValues(alpha: 0.35),
            child: InkWell(
              onTap: enabled ? onPressed : null,
              borderRadius: radius,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: height),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: big ? 18 : (compact ? 12 : 14),
                    vertical: 6,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    // Keeps the label centred when the pill is stretched full
                    // width (e.g. the mentor's advance button).
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (loading)
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(ink),
                          ),
                        )
                      else if (icon != null)
                        Icon(icon, size: big ? 16 : 14, color: ink),
                      if (loading || icon != null) SizedBox(width: big ? 8 : 6),
                      Flexible(
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: AppFonts.inter(
                            fontSize: big ? 14 : 13,
                            fontWeight: big ? FontWeight.w600 : FontWeight.w700,
                            color: ink,
                            height: 1.25,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Quiet raised pill (e.g. "Message mentor", filter chips when unselected).
/// When [selected] it takes the primary CTA colours instead.
class CommunityRaisedPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool selected;

  const CommunityRaisedPill({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final fill = selected
        ? palette.ctaFill
        : (palette.isDark
            ? (icon != null
                ? Colors.white.withValues(alpha: 0.12)
                : palette.card)
            : palette.raised);
    // Unselected labels are muted on dark (7:1 on the card); on light the
    // muted tone would miss the 5.5:1 label floor on the raised fill, so
    // they take the text colour there.
    final ink = selected
        ? palette.ctaInk
        : (palette.isDark && icon == null ? palette.muted : palette.text);
    final radius = BorderRadius.circular(16);

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      // A 32px pill with a 40px tap area (the 4px above and below count).
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Material(
            color: fill,
            borderRadius: radius,
            child: InkWell(
              onTap: onPressed,
              borderRadius: radius,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 32),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 14, color: ink),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: Text(
                          label,
                          style: AppFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: ink,
                            height: 1.25,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
