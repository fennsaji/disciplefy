import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/widgets/memory_ui/style.dart';

/// Visual state of an [MemoryAnswerCard].
enum MemoryCardState {
  /// Card fill + hairline border.
  normal,

  /// Lavender/indigo 1.5px border (focused text field, active drop target).
  focused,

  /// Indigo-tinted fill + border (flip card front/back).
  accent,

  /// Green border (checked correct).
  correct,

  /// Red border (checked wrong).
  wrong,
}

/// The raised card that holds the verse / answer area of a practice mode.
class MemoryAnswerCard extends StatelessWidget {
  final Widget child;

  /// Optional tracked label on top ("YOUR ANSWER", "FRONT").
  final String? label;

  /// Colour of [label]; muted by default, pass `palette.gold` for gold.
  final Color? labelColor;
  final MemoryCardState state;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;

  /// Minimum height (e.g. flip card ~320, type-it-out ~200).
  final double? minHeight;

  const MemoryAnswerCard({
    super.key,
    required this.child,
    this.label,
    this.labelColor,
    this.state = MemoryCardState.normal,
    this.padding = const EdgeInsets.fromLTRB(18, 16, 18, 18),
    this.radius = 20,
    this.onTap,
    this.minHeight,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    Color fill = palette.card;
    Color border = palette.hairline;
    double borderWidth = 1;
    switch (state) {
      case MemoryCardState.normal:
        break;
      case MemoryCardState.focused:
        border = palette.accentIcon;
        borderWidth = 1.5;
      case MemoryCardState.accent:
        fill = Color.alphaBlend(
          AppColors.brandPrimary
              .withValues(alpha: palette.isDark ? 0.16 : 0.06),
          palette.card,
        );
        border = AppColors.brandPrimary.withValues(alpha: 0.35);
      case MemoryCardState.correct:
        border = context.appSuccess;
        borderWidth = 1.5;
      case MemoryCardState.wrong:
        border = context.appError;
        borderWidth = 1.5;
    }
    final radiusGeom = BorderRadius.circular(radius);
    Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null) ...[
          MemorySectionLabel(
            label!,
            color: labelColor ?? palette.muted,
            padding: const EdgeInsets.only(bottom: 10),
          ),
        ],
        child,
      ],
    );
    content = Container(
      constraints: BoxConstraints(minHeight: minHeight ?? 0),
      padding: padding,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: radiusGeom,
        border: Border.all(color: border, width: borderWidth),
      ),
      child: content,
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      borderRadius: radiusGeom,
      child: InkWell(onTap: onTap, borderRadius: radiusGeom, child: content),
    );
  }
}

/// Uppercase, tracked section label (Inter 10.5 bold, letterSpacing 1.4).
///
/// Gold by default (list pages); pass `color: palette.muted` for the grey
/// labels used inside practice modes ("WORD BANK", "YOU SAID").
class MemorySectionLabel extends StatelessWidget {
  final String text;
  final Color? color;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  const MemorySectionLabel(
    this.text, {
    super.key,
    this.color,
    this.trailing,
    this.padding = const EdgeInsets.only(top: 20, bottom: 8),
  });

  /// Muted grey variant used inside practice modes.
  factory MemorySectionLabel.muted(
    BuildContext context,
    String text, {
    Key? key,
    Widget? trailing,
    EdgeInsetsGeometry padding = const EdgeInsets.only(top: 20, bottom: 8),
  }) =>
      MemorySectionLabel(
        text,
        key: key,
        color: ReaderPalette.of(context).muted,
        trailing: trailing,
        padding: padding,
      );

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

/// Full-width 1px hairline separator.
class MemoryHairline extends StatelessWidget {
  final double verticalMargin;

  const MemoryHairline({super.key, this.verticalMargin = 0});

  @override
  Widget build(BuildContext context) => Container(
        height: 1,
        margin: EdgeInsets.symmetric(vertical: verticalMargin),
        color: ReaderPalette.of(context).hairline,
      );
}

/// Card tile with a centred big number and a small muted label under it
/// ("0:42 / time", "27 / reviews").
class MemoryStatTile extends StatelessWidget {
  final String value;
  final String label;
  final Color? valueColor;

  const MemoryStatTile({
    super.key,
    required this.value,
    required this.label,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Semantics(
      label: '$value $label',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.hairline),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                style: AppFonts.poppins(
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? palette.text,
                  fontFeatures: kMemoryTabular,
                ),
              ),
            ),
            const SizedBox(height: 2),
            // Wraps freely; the row's IntrinsicHeight keeps tiles even.
            Text(
              label,
              textAlign: TextAlign.center,
              style: AppFonts.inter(fontSize: 12, color: palette.muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Equal-width row of [MemoryStatTile]s with matching heights.
class MemoryStatRow extends StatelessWidget {
  final List<Widget> tiles;
  final double spacing;

  const MemoryStatRow({super.key, required this.tiles, this.spacing = 10});

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < tiles.length; i++) ...[
              if (i > 0) SizedBox(width: spacing),
              Expanded(child: tiles[i]),
            ],
          ],
        ),
      );
}

/// Thin rounded progress bar on a raised track.
class MemoryProgressBar extends StatelessWidget {
  /// 0..1.
  final double value;
  final Color? color;
  final Color? trackColor;
  final double height;

  const MemoryProgressBar({
    super.key,
    required this.value,
    this.color,
    this.trackColor,
    this.height = 6,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final v = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: trackColor ?? palette.raised),
            FractionallySizedBox(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: v,
              child: ColoredBox(color: color ?? palette.accentIcon),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small rounded tag with a soft tone fill ("Review", "Intermediate").
class MemoryTag extends StatelessWidget {
  final String label;
  final MemoryTone tone;

  const MemoryTag(
      {super.key, required this.label, this.tone = MemoryTone.neutral});

  @override
  Widget build(BuildContext context) {
    final colors = MemoryToneColors.of(context, tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.fill,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: colors.foreground,
        ),
      ),
    );
  }
}

/// Coloured difficulty word ("Easy" green / "Medium" gold / "Hard" red).
class MemoryDifficultyLabel extends StatelessWidget {
  final String label;
  final MemoryDifficulty difficulty;

  /// Dimmed (e.g. on a locked mode row).
  final bool dimmed;

  const MemoryDifficultyLabel({
    super.key,
    required this.label,
    required this.difficulty,
    this.dimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = MemoryToneColors.of(context, difficulty.tone).foreground;
    return Text(
      label,
      style: AppFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: dimmed ? color.withValues(alpha: 0.55) : color,
      ),
    );
  }
}
