import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/widgets/memory_ui/style.dart';

/// Height shared by action pills and the primary pill.
const double kMemoryPillHeight = 52;

/// Primary stadium call-to-action: white fill + indigo ink on dark, indigo
/// fill + white ink on light ("Check", "Submit", "Reveal next", "Done").
class MemoryPrimaryPill extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final double height;

  const MemoryPrimaryPill({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.height = kMemoryPillHeight,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return _MemoryPill(
      label: label,
      icon: icon,
      loading: loading,
      height: height,
      onPressed: onPressed,
      fill: palette.ctaFill,
      ink: palette.ctaInk,
      horizontalPadding: 18,
    );
  }
}

/// Secondary stadium pill: raised fill, icon + label ("Hint", "Clear",
/// "Reset", "Show answer", "Auto", "All", "Practice again").
///
/// When [iconOnly] is true (set automatically by [MemoryActionBar] on narrow
/// screens) only the icon is shown and [label] becomes the tooltip and
/// semantics label.
class MemoryActionPill extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Draws the label in the accent colour to show a toggled state
  /// (e.g. "Auto" while auto-reveal runs).
  final bool active;
  final bool iconOnly;
  final double height;

  /// Small count shown on the icon-only circle (e.g. hints used), so the
  /// number in [label] stays visible when the label collapses to an icon.
  final String? badge;

  const MemoryActionPill({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.active = false,
    this.iconOnly = false,
    this.height = kMemoryPillHeight,
    this.badge,
  });

  /// Copy with a different [iconOnly]; used by [MemoryActionBar].
  MemoryActionPill withIconOnly(bool value) => MemoryActionPill(
        key: key,
        label: label,
        onPressed: onPressed,
        icon: icon,
        active: active,
        iconOnly: value,
        height: height,
        badge: badge,
      );

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final ink = active ? palette.accentIcon : palette.text;
    if (iconOnly && icon != null) {
      return Tooltip(
        message: label,
        child: Semantics(
          button: true,
          label: label,
          excludeSemantics: true,
          child: SizedBox(
            width: height,
            height: height,
            child: TextButton(
              onPressed: onPressed,
              style: TextButton.styleFrom(
                backgroundColor: palette.raised,
                foregroundColor: ink,
                disabledBackgroundColor: palette.raised.withValues(alpha: 0.55),
                disabledForegroundColor: palette.dim,
                shape: const CircleBorder(),
                padding: EdgeInsets.zero,
                minimumSize: Size(height, height),
              ),
              child: badge == null
                  ? Icon(icon, size: 20)
                  : Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(icon, size: 20),
                        PositionedDirectional(
                          top: -8,
                          end: -12,
                          child: Container(
                            constraints: const BoxConstraints(minWidth: 18),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: palette.gold,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              badge!,
                              textAlign: TextAlign.center,
                              style: AppFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: palette.page,
                                fontFeatures: kMemoryTabular,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      );
    }
    return _MemoryPill(
      label: label,
      icon: icon,
      loading: false,
      height: height,
      onPressed: onPressed,
      fill: palette.raised,
      ink: ink,
      horizontalPadding: 16,
    );
  }
}

class _MemoryPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool loading;
  final double height;
  final VoidCallback? onPressed;
  final Color fill;
  final Color ink;
  final double horizontalPadding;

  const _MemoryPill({
    required this.label,
    required this.icon,
    required this.loading,
    required this.height,
    required this.onPressed,
    required this.fill,
    required this.ink,
    required this.horizontalPadding,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: loading ? null : onPressed,
      style: TextButton.styleFrom(
        backgroundColor: fill,
        foregroundColor: ink,
        disabledBackgroundColor: fill.withValues(alpha: 0.5),
        disabledForegroundColor: ink.withValues(alpha: 0.55),
        minimumSize: Size(0, height),
        shape: const StadiumBorder(),
        padding:
            EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 8),
      ),
      child: loading
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(ink),
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18),
                  const SizedBox(width: 8),
                ],
                // Wraps onto more lines instead of cutting the label off
                // with an ellipsis (long Hindi/Malayalam labels at 320pt).
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    softWrap: true,
                    style: AppFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// Bottom action bar of a practice screen: zero or more [secondary] pills on
/// the left and an optional [primary] pill filling the rest.
///
/// Wraps itself in a bottom [SafeArea] with 16px gutters, so pass it straight
/// to `MemoryPracticeScaffold.bottomBar` (or `Scaffold.bottomNavigationBar`).
/// On narrow screens (e.g. 320pt) secondary pills collapse to icon-only
/// circles so long Hindi/Malayalam labels never overflow.
class MemoryActionBar extends StatelessWidget {
  final List<MemoryActionPill> secondary;
  final Widget? primary;

  /// Force icon-only secondaries; `null` decides from the available width.
  final bool? compactSecondary;

  /// Optional widget shown above the row (e.g. a hint line).
  final Widget? top;

  const MemoryActionBar({
    super.key,
    this.secondary = const [],
    this.primary,
    this.compactSecondary,
    this.top,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Material(
      color: palette.page,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding:
              const EdgeInsets.fromLTRB(kMemoryGutter, 8, kMemoryGutter, 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (top != null) ...[top!, const SizedBox(height: 10)],
              LayoutBuilder(
                builder: (context, constraints) {
                  // Labelled secondaries only when every label fits whole
                  // next to the primary; otherwise they become icon circles.
                  // Labels are never cut off with an ellipsis.
                  final compact = compactSecondary ??
                      !labelsFit(
                        context,
                        constraints.maxWidth,
                        secondary,
                        primary,
                      );
                  return Row(
                    children: [
                      for (var i = 0; i < secondary.length; i++) ...[
                        if (i > 0) const SizedBox(width: 10),
                        if (compact && secondary[i].icon != null)
                          secondary[i].withIconOnly(true)
                        else if (primary == null)
                          Expanded(child: secondary[i])
                        else if (compact)
                          Flexible(child: secondary[i])
                        else
                          secondary[i],
                      ],
                      if (primary != null) ...[
                        if (secondary.isNotEmpty) const SizedBox(width: 10),
                        Expanded(child: primary!),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Whether all [secondary] labels and the [primary] label fit at their
  /// natural width in [maxWidth]. Also used by custom action bars.
  static bool labelsFit(
    BuildContext context,
    double maxWidth,
    List<MemoryActionPill> secondary,
    Widget? primary,
  ) {
    if (secondary.isEmpty) return true;
    final scaler = MediaQuery.textScalerOf(context);
    // Button labels merge with the theme's labelLarge (letter spacing).
    final base = Theme.of(context).textTheme.labelLarge ?? const TextStyle();
    final style = base.merge(
      AppFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, height: 1.25),
    );
    double pillWidth(String label, IconData? icon, double padding) {
      final painter = TextPainter(
        text: TextSpan(
          text: label,
          style: style,
        ),
        maxLines: 1,
        textScaler: scaler,
        textDirection: Directionality.of(context),
      )..layout();
      return painter.width + padding * 2 + (icon != null ? 26 : 0) + 2;
    }

    var needed = 10.0 * (secondary.length - 1);
    for (final pill in secondary) {
      needed += pillWidth(pill.label, pill.icon, 16);
    }
    final primaryPill = primary;
    if (primaryPill is MemoryPrimaryPill) {
      needed += 10 + pillWidth(primaryPill.label, primaryPill.icon, 18);
    } else if (primaryPill != null) {
      needed += 10 + 96;
    }
    return needed <= maxWidth;
  }
}
