import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';

/// Building blocks of the quiet-ledger credits and plans design.
///
/// Content sits straight on the page, split by 1px hairlines; numbers are the
/// hero (Poppins, tabular figures) and a raised card appears only where the
/// design shows one (stat tiles, compared plans, sheets). Every colour comes
/// from [ReaderPalette] or the theme-resolved semantic accents, so the same
/// layout renders in light and dark. No shadows, gradients, blur or
/// continuous animation.

/// Tabular figures so columns of amounts line up.
const List<FontFeature> kLedgerTabular = [FontFeature.tabularFigures()];

/// Semantic colour of a ledger value, pill or notice.
enum LedgerTone { neutral, success, warning, error, accent, gold }

/// Resolved foreground and soft fill for a [LedgerTone].
@immutable
class LedgerToneColors {
  final Color foreground;
  final Color fill;

  const LedgerToneColors(this.foreground, this.fill);

  factory LedgerToneColors.of(BuildContext context, LedgerTone tone) {
    final palette = ReaderPalette.of(context);
    final alpha = palette.isDark ? 0.14 : 0.10;
    switch (tone) {
      case LedgerTone.neutral:
        return LedgerToneColors(palette.text, palette.raised);
      case LedgerTone.success:
        return LedgerToneColors(
            context.appSuccess, AppColors.success.withValues(alpha: alpha));
      case LedgerTone.warning:
        return LedgerToneColors(
            context.appWarning, AppColors.warning.withValues(alpha: alpha));
      case LedgerTone.error:
        return LedgerToneColors(
            context.appError, AppColors.error.withValues(alpha: alpha));
      case LedgerTone.accent:
        return LedgerToneColors(
            palette.accentIcon,
            AppColors.brandPrimary
                .withValues(alpha: palette.isDark ? 0.2 : 0.08));
      case LedgerTone.gold:
        return LedgerToneColors(
            palette.gold, palette.gold.withValues(alpha: alpha));
    }
  }
}

/// Back arrow, big Poppins title and an optional gold subtitle.
class LedgerTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final List<Widget> actions;

  /// Close (x) instead of a back arrow, for pages opened as a modal step.
  final bool useCloseIcon;

  const LedgerTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.actions = const [],
    this.useCloseIcon = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final localizations = MaterialLocalizations.of(context);
    return Material(
      color: palette.page,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: preferredSize.height,
          child: Row(
            children: [
              const SizedBox(width: 4),
              IconButton(
                tooltip: useCloseIcon
                    ? localizations.closeButtonTooltip
                    : localizations.backButtonTooltip,
                icon: Icon(
                  useCloseIcon ? Icons.close_rounded : Icons.arrow_back,
                  color: palette.text,
                  size: 22,
                ),
                onPressed: onBack ?? () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: 2),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Long titles (Malayalam) shrink to fit rather than
                    // being cut with an ellipsis.
                    Semantics(
                      header: true,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          title,
                          maxLines: 1,
                          style: AppFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: palette.text,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty)
                      Text(
                        subtitle!,
                        maxLines: 2,
                        style: AppFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: palette.gold,
                        ),
                      ),
                  ],
                ),
              ),
              ...actions,
              SizedBox(width: actions.isEmpty ? 16 : 6),
            ],
          ),
        ),
      ),
    );
  }
}

/// Plain icon action for [LedgerTopBar].
class LedgerBarAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const LedgerBarAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, size: 22, color: ReaderPalette.of(context).text),
      );
}

/// Gold, uppercase, tracked section label with an optional trailing link.
class LedgerSectionLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;
  final Color? color;
  final EdgeInsetsGeometry padding;

  const LedgerSectionLabel(
    this.text, {
    super.key,
    this.trailing,
    this.color,
    this.padding = const EdgeInsets.only(top: 22, bottom: 8),
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                text.toUpperCase(),
                style: AppFonts.inter(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                  color: color ?? palette.gold,
                ),
              ),
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}

/// Full-width 1px separator between ledger sections and rows.
class LedgerHairline extends StatelessWidget {
  final double verticalMargin;

  const LedgerHairline({super.key, this.verticalMargin = 0});

  @override
  Widget build(BuildContext context) => Container(
        height: 1,
        margin: EdgeInsets.symmetric(vertical: verticalMargin),
        color: ReaderPalette.of(context).hairline,
      );
}

/// A ledger line: muted label on the left, tabular value on the right.
class LedgerRow extends StatelessWidget {
  final String label;
  final String? value;

  /// Replaces [value] (e.g. a spinner or a link).
  final Widget? valueWidget;
  final Color? valueColor;
  final Color? labelColor;
  final bool emphasizeLabel;
  final VoidCallback? onTap;

  const LedgerRow({
    super.key,
    required this.label,
    this.value,
    this.valueWidget,
    this.valueColor,
    this.labelColor,
    this.emphasizeLabel = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: LayoutBuilder(
        builder: (context, constraints) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                label,
                style: AppFonts.inter(
                  fontSize: 14,
                  fontWeight:
                      emphasizeLabel ? FontWeight.w500 : FontWeight.w400,
                  color: labelColor ??
                      (emphasizeLabel ? palette.text : palette.muted),
                  height: 1.35,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // The value hugs the right edge and may take up to ~60% of the
            // line before wrapping, so long values never push the label out.
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: constraints.maxWidth * 0.6,
              ),
              child: valueWidget ??
                  Text(
                    value ?? '',
                    textAlign: TextAlign.end,
                    style: AppFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: valueColor ?? palette.text,
                      height: 1.35,
                      fontFeatures: kLedgerTabular,
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }
}

/// Raised tile with a big number and a small label under it.
class LedgerStatTile extends StatelessWidget {
  final String value;
  final String label;
  final Color? valueColor;
  final bool centered;

  const LedgerStatTile({
    super.key,
    required this.value,
    required this.label,
    this.valueColor,
    this.centered = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final align =
        centered ? CrossAxisAlignment.center : CrossAxisAlignment.start;
    return Semantics(
      label: '$value $label',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.hairline),
        ),
        child: Column(
          crossAxisAlignment: align,
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: centered ? Alignment.center : Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: AppFonts.poppins(
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? palette.text,
                  fontFeatures: kLedgerTabular,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: centered ? TextAlign.center : TextAlign.start,
              style: AppFonts.inter(fontSize: 12, color: palette.muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Up to three [LedgerStatTile]s side by side.
class LedgerStatRow extends StatelessWidget {
  final List<Widget> tiles;

  const LedgerStatRow({super.key, required this.tiles});

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < tiles.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(child: tiles[i]),
            ],
          ],
        ),
      );
}

/// Full-width stadium pill: white with indigo ink on dark, indigo with white
/// ink on light.
class LedgerPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final double height;

  const LedgerPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return _LedgerPill(
      label: label,
      icon: icon,
      loading: loading,
      height: height,
      onPressed: onPressed,
      fill: palette.ctaFill,
      ink: palette.ctaInk,
    );
  }
}

/// Raised neutral pill for secondary actions.
class LedgerSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final double height;

  /// Red-tinted variant for destructive confirmations.
  final bool destructive;

  const LedgerSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.height = 52,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final red = LedgerToneColors.of(context, LedgerTone.error);
    return _LedgerPill(
      label: label,
      icon: icon,
      loading: loading,
      height: height,
      onPressed: onPressed,
      fill: destructive ? red.fill : palette.raised,
      ink: destructive ? red.foreground : palette.text,
    );
  }
}

/// Two actions side by side when both labels fit on one line at half width,
/// otherwise stacked full width (primary first), so no label is ever cut.
class LedgerButtonPair extends StatelessWidget {
  final Widget first;
  final Widget second;

  /// Labels of [first] and [second], measured to pick the layout.
  final List<String> labels;

  /// Whether the buttons carry a leading icon (it takes label room).
  final bool withIcons;

  const LedgerButtonPair({
    super.key,
    required this.first,
    required this.second,
    required this.labels,
    this.withIcons = true,
  });

  static const double _gap = 10;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final half = (constraints.maxWidth - _gap) / 2;
        // Pill padding (18 each side) plus the optional icon and its gap.
        final room = half - 36 - (withIcons ? 26 : 0);
        final scaler = MediaQuery.textScalerOf(context);
        final fits = labels.every((label) {
          final painter = TextPainter(
            text: TextSpan(text: label, style: _LedgerPill.labelStyle),
            textDirection: Directionality.of(context),
            textScaler: scaler,
            maxLines: 1,
          )..layout();
          final width = painter.width;
          painter.dispose();
          return width <= room;
        });
        if (fits) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: first),
                const SizedBox(width: _gap),
                Expanded(child: second),
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [first, const SizedBox(height: _gap), second],
        );
      },
    );
  }
}

class _LedgerPill extends StatelessWidget {
  /// Label style without colour, shared with [LedgerButtonPair]'s measuring.
  static TextStyle get labelStyle => AppFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 1.25,
      );

  final String label;
  final IconData? icon;
  final bool loading;
  final double height;
  final VoidCallback? onPressed;
  final Color fill;
  final Color ink;

  const _LedgerPill({
    required this.label,
    required this.icon,
    required this.loading,
    required this.height,
    required this.onPressed,
    required this.fill,
    required this.ink,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: height),
      child: TextButton(
        onPressed: loading ? null : onPressed,
        style: TextButton.styleFrom(
          backgroundColor: fill,
          foregroundColor: ink,
          disabledBackgroundColor: fill.withValues(alpha: 0.55),
          disabledForegroundColor: ink.withValues(alpha: 0.7),
          minimumSize: Size(0, height),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
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
                    Icon(icon, size: 18, color: ink),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
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
    );
  }
}

/// Plain accent text link ("View all", "Report an issue →").
class LedgerLink extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? leadingIcon;
  final IconData? trailingIcon;

  const LedgerLink({
    super.key,
    required this.label,
    required this.onTap,
    this.leadingIcon,
    this.trailingIcon,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final color = palette.accentIcon;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 36),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leadingIcon != null) ...[
                  Icon(leadingIcon, size: 17, color: color),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    label,
                    style: AppFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
                if (trailingIcon != null) ...[
                  const SizedBox(width: 6),
                  Icon(trailingIcon, size: 16, color: color),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small rounded tile holding a line icon (usage and invoice rows).
class LedgerIconTile extends StatelessWidget {
  final IconData icon;
  final double size;
  final LedgerTone tone;

  const LedgerIconTile({
    super.key,
    required this.icon,
    this.size = 36,
    this.tone = LedgerTone.accent,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final colors = LedgerToneColors.of(context, tone);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tone == LedgerTone.accent ? palette.raised : colors.fill,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: size * 0.5, color: colors.foreground),
    );
  }
}

/// Tinted status pill (Active, Success, Pending, Failed).
class LedgerStatusPill extends StatelessWidget {
  final String label;
  final LedgerTone tone;

  const LedgerStatusPill({super.key, required this.label, required this.tone});

  @override
  Widget build(BuildContext context) {
    final colors = LedgerToneColors.of(context, tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.fill,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: AppFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: colors.foreground,
        ),
      ),
    );
  }
}

/// Inline notice: toned icon and text on a soft wash. Used for the few
/// messages that must stand out (trial ending, cancelled, kill switch).
class LedgerNotice extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? detail;
  final LedgerTone tone;

  const LedgerNotice({
    super.key,
    required this.icon,
    required this.text,
    this.detail,
    this.tone = LedgerTone.accent,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final colors = LedgerToneColors.of(context, tone);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: colors.fill,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 18, color: colors.foreground),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: AppFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: tone == LedgerTone.neutral
                        ? palette.text
                        : colors.foreground,
                    height: 1.4,
                  ),
                ),
                if (detail != null && detail!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    detail!,
                    style: AppFonts.inter(
                      fontSize: 12.5,
                      color: palette.muted,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A feature line with a small check (or dash when [included] is false).
class LedgerCheckRow extends StatelessWidget {
  final String text;
  final bool included;

  const LedgerCheckRow(this.text, {super.key, this.included = true});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              included ? Icons.check_rounded : Icons.remove_rounded,
              size: 17,
              color: included ? palette.gold : palette.dim,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppFonts.inter(
                fontSize: 14,
                color: included ? palette.text : palette.dim,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Centred loading, empty or error message with an optional retry pill.
class LedgerMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? body;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isError;

  const LedgerMessage({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.actionLabel,
    this.onAction,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 40, color: isError ? context.appError : palette.dim),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: palette.text,
              ),
            ),
            if (body != null && body!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                body!,
                textAlign: TextAlign.center,
                style: AppFonts.inter(
                  fontSize: 13.5,
                  color: palette.muted,
                  height: 1.45,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: 200,
                child: LedgerSecondaryButton(
                  label: actionLabel!,
                  onPressed: onAction,
                  icon: Icons.refresh_rounded,
                  height: 46,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Plain centred spinner in the page colours.
class LedgerLoading extends StatelessWidget {
  final String? label;

  const LedgerLoading({super.key, this.label});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(palette.accentIcon),
            ),
          ),
          if (label != null) ...[
            const SizedBox(height: 14),
            Text(
              label!,
              textAlign: TextAlign.center,
              style: AppFonts.inter(fontSize: 13.5, color: palette.muted),
            ),
          ],
        ],
      ),
    );
  }
}

/// Static progress ring: gold arc over a faint track, with [child] centred.
class LedgerRing extends StatelessWidget {
  /// 0..1 share of the arc to fill.
  final double progress;
  final double size;
  final double strokeWidth;
  final Widget child;

  const LedgerRing({
    super.key,
    required this.progress,
    required this.child,
    this.size = 96,
    this.strokeWidth = 7,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          progress: progress.clamp(0.0, 1.0),
          color: palette.gold,
          track: palette.gold.withValues(alpha: palette.isDark ? 0.16 : 0.14),
          fill: palette.gold.withValues(alpha: palette.isDark ? 0.07 : 0.06),
          strokeWidth: strokeWidth,
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color track;
  final Color fill;
  final double strokeWidth;

  _RingPainter({
    required this.progress,
    required this.color,
    required this.track,
    required this.fill,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    canvas.drawCircle(center, radius, Paint()..color = fill);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, stroke..color = track);
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        stroke..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.track != track ||
      old.fill != fill;
}
