import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';

/// Primary pill button of the community screens: white with indigo ink on
/// dark, indigo with white ink on light ([ReaderPalette.ctaFill]/`ctaInk`).
///
/// Used for "Join", "Start study", "Join a fellowship". At least 44px tall;
/// the label wraps instead of truncating.
class CommunityCtaPill extends StatelessWidget {
  final String label;
  final IconData? icon;

  /// Null disables the pill.
  final VoidCallback? onPressed;

  /// Shows a spinner in place of the icon and ignores taps.
  final bool loading;

  /// Larger padding/text for a floating action ("Join a fellowship").
  final bool large;

  const CommunityCtaPill({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final enabled = onPressed != null && !loading;
    final fill = enabled || loading
        ? palette.ctaFill
        : palette.ctaFill.withValues(alpha: 0.5);
    final ink = palette.ctaInk;
    final radius = BorderRadius.circular(large ? 30 : 24);

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
      child: Material(
        color: fill,
        borderRadius: radius,
        elevation: large ? 6 : 0,
        shadowColor: Colors.black.withValues(alpha: 0.35),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: radius,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: large ? 56 : 44),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: large ? 24 : 18,
                vertical: 8,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                // Keeps the label centred when the pill is stretched full
                // width (e.g. the mentor's advance button).
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (loading)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(ink),
                      ),
                    )
                  else if (icon != null)
                    Icon(icon, size: large ? 22 : 18, color: ink),
                  if (loading || icon != null) const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: AppFonts.inter(
                        fontSize: large ? 16 : 15,
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
            ? Colors.white.withValues(alpha: 0.10)
            : palette.raised);
    final ink = selected ? palette.ctaInk : palette.text;
    final radius = BorderRadius.circular(24);

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: fill,
        borderRadius: radius,
        child: InkWell(
          onTap: onPressed,
          borderRadius: radius,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: ink),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      style: AppFonts.inter(
                        fontSize: 15,
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
    );
  }
}
