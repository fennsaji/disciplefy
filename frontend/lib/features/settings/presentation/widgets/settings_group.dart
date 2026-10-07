import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';

/// Building blocks of the grouped-cards settings design: a plain top bar,
/// tracked section labels, and flat cards of icon rows split by hairlines.
///
/// Every colour comes from [ReaderPalette] or [SettingsTone], so call sites
/// never branch on brightness. No shadows, gradients or blur.

/// Primary action fill in settings: indigo with white ink in both themes (unlike
/// [ReaderPalette.ctaFill], which is white on dark).
const Color settingsPrimaryFill = ReaderPalette.selectedFill;
const Color settingsPrimaryInk = Colors.white;

/// Colour family of a row's icon tile.
enum SettingsTone { indigo, gold, green, sky, pink, red, amber }

/// Resolved icon colour and tile fill for a [SettingsTone].
@immutable
class SettingsToneColors {
  final Color foreground;
  final Color fill;

  const SettingsToneColors(this.foreground, this.fill);

  factory SettingsToneColors.of(BuildContext context, SettingsTone tone) {
    final palette = ReaderPalette.of(context);
    final dark = palette.isDark;
    Color darkTint(Color c) => c.withValues(alpha: 0.15);
    switch (tone) {
      case SettingsTone.indigo:
        return SettingsToneColors(
          palette.accentIcon,
          dark ? darkTint(AppColors.brandSecondary) : const Color(0xFFEEEEFD),
        );
      case SettingsTone.gold:
        return SettingsToneColors(
          palette.gold,
          dark ? darkTint(AppColors.brandGold) : const Color(0xFFF6ECD9),
        );
      case SettingsTone.green:
        return dark
            ? SettingsToneColors(
                const Color(0xFF34D399), darkTint(const Color(0xFF34D399)))
            : const SettingsToneColors(Color(0xFF15803D), Color(0xFFDCFCE7));
      case SettingsTone.sky:
        return dark
            ? SettingsToneColors(
                const Color(0xFF60A5FA), darkTint(const Color(0xFF60A5FA)))
            : const SettingsToneColors(Color(0xFF2563EB), Color(0xFFDBEAFE));
      case SettingsTone.pink:
        return dark
            ? SettingsToneColors(
                const Color(0xFFF472B6), darkTint(const Color(0xFFF472B6)))
            : const SettingsToneColors(Color(0xFFDB2777), Color(0xFFFCE7F3));
      case SettingsTone.red:
        return dark
            ? SettingsToneColors(
                const Color(0xFFF87171), darkTint(const Color(0xFFF87171)))
            : const SettingsToneColors(Color(0xFFDC2626), Color(0xFFFEE2E2));
      case SettingsTone.amber:
        return dark
            ? SettingsToneColors(
                const Color(0xFFFBBF24), darkTint(const Color(0xFFF59E0B)))
            : const SettingsToneColors(Color(0xFFB45309), Color(0xFFFEF3C7));
    }
  }
}

/// Back arrow + Poppins title with an optional muted line under it.
class SettingsTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;

  /// Optional trailing actions (icon buttons).
  final List<Widget> actions;

  const SettingsTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.actions = const [],
  });

  /// Taller with a subtitle, so a long hi/ml subtitle can wrap to three
  /// lines instead of being cut.
  @override
  Size get preferredSize => Size.fromHeight(subtitle == null ? 64 : 76);

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
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
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                icon: Icon(Icons.arrow_back, color: palette.text, size: 22),
                onPressed: onBack ?? () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: 2),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Never cut: alone the title may take two lines; above
                    // a subtitle it shrinks to fit one line instead.
                    if (subtitle == null)
                      Text(
                        title,
                        maxLines: 2,
                        style: AppFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: palette.text,
                          height: 1.25,
                        ),
                      )
                    else
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          title,
                          maxLines: 1,
                          style: AppFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: palette.text,
                          ),
                        ),
                      ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        maxLines: 3,
                        style: AppFonts.inter(
                          fontSize: 12,
                          color: palette.muted,
                          height: 1.25,
                        ),
                      ),
                  ],
                ),
              ),
              ...actions,
              SizedBox(width: actions.isEmpty ? 16 : 4),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tracked uppercase label above a [SettingsGroup].
class SettingsSectionLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;

  const SettingsSectionLabel(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 20, 2, 8),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                text.toUpperCase(),
                style: AppFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                  color: palette.muted,
                ),
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Flat card holding rows, with a 1px hairline between each.
class SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  const SettingsGroup({
    super.key,
    required this.children,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Material(
      color: palette.card,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: palette.hairline),
      ),
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SettingsHairline(),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// The 1px separator between rows of a [SettingsGroup].
class SettingsHairline extends StatelessWidget {
  const SettingsHairline({super.key});

  @override
  Widget build(BuildContext context) => Container(
        height: 1,
        margin: const EdgeInsets.symmetric(horizontal: 14),
        color: ReaderPalette.of(context).hairline,
      );
}

/// 34x34 rounded tile with a tinted fill and a 17px icon.
class SettingsIconTile extends StatelessWidget {
  final IconData icon;
  final SettingsTone tone;
  final double size;

  const SettingsIconTile({
    super.key,
    required this.icon,
    this.tone = SettingsTone.indigo,
    this.size = 34,
  });

  @override
  Widget build(BuildContext context) {
    final colors = SettingsToneColors.of(context, tone);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.fill,
        borderRadius: BorderRadius.circular(size * 11 / 34),
      ),
      child: Icon(icon, size: size / 2, color: colors.foreground),
    );
  }
}

/// One row of a [SettingsGroup]: icon tile, title (+ subtitle), optional
/// value and a chevron when tappable.
///
/// [destructive] rows use red for the title and drop the chevron.
class SettingsRow extends StatelessWidget {
  final IconData icon;
  final SettingsTone tone;
  final String title;
  final String? subtitle;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;

  /// Whether to show the chevron; defaults to "tappable and not destructive
  /// and no custom trailing".
  final bool? showChevron;

  const SettingsRow({
    super.key,
    required this.icon,
    required this.title,
    this.tone = SettingsTone.indigo,
    this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
    this.destructive = false,
    this.showChevron,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final effectiveTone = destructive ? SettingsTone.red : tone;
    final titleColor = destructive
        ? SettingsToneColors.of(context, SettingsTone.red).foreground
        : palette.text;
    final chevron =
        showChevron ?? (onTap != null && !destructive && trailing == null);

    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 58),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              SettingsIconTile(icon: icon, tone: effectiveTone),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppFonts.inter(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w500,
                        color: titleColor,
                        height: 1.3,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: AppFonts.inter(
                          fontSize: 12,
                          color: palette.muted,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (value != null && value!.isNotEmpty) ...[
                const SizedBox(width: 8),
                // Capped so a long value never squeezes the title away; it
                // wraps rather than being cut.
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: Text(
                    value!,
                    textAlign: TextAlign.end,
                    style: AppFonts.inter(fontSize: 13, color: palette.muted),
                  ),
                ),
              ],
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
              if (chevron) ...[
                const SizedBox(width: 6),
                Icon(Icons.chevron_right, size: 18, color: palette.dim),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Indigo-track switch used by settings rows.
class SettingsSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;

  const SettingsSwitch({super.key, required this.value, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Switch(
      value: value,
      onChanged: onChanged,
      activeThumbColor: Colors.white,
      activeTrackColor: settingsPrimaryFill,
      inactiveThumbColor: Colors.white,
      inactiveTrackColor:
          palette.isDark ? const Color(0xFF3A3A42) : const Color(0xFFE2E2E8),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

/// Indigo-ring radio indicator.
class SettingsRadioMark extends StatelessWidget {
  final bool selected;

  const SettingsRadioMark({super.key, required this.selected});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? settingsPrimaryFill : palette.dim,
          width: selected ? 7 : 1.5,
        ),
      ),
    );
  }
}

/// A choice row in a picker: title, optional subtitle, optional leading
/// icon tile, radio on the right.
class SettingsRadioRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final SettingsTone tone;

  const SettingsRadioRow({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.icon,
    this.tone = SettingsTone.indigo,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                if (icon != null) ...[
                  SettingsIconTile(icon: icon!, tone: tone),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppFonts.inter(
                          fontSize: 15,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w500,
                          color: palette.text,
                          height: 1.3,
                        ),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: AppFonts.inter(
                            fontSize: 12.5,
                            color: palette.muted,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SettingsRadioMark(selected: selected),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Visual kind of a [SettingsButton].
enum SettingsButtonKind { primary, destructive, neutral }

/// Pill button: indigo primary, red-tinted destructive or raised neutral.
///
/// The label is never cut off: it wraps to a second line (and the pill grows)
/// when the width is tight. Put two of them side by side with
/// [SettingsButtonRow], which stacks them when their labels don't fit.
class SettingsButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final SettingsButtonKind kind;
  final IconData? icon;
  final bool loading;

  /// Minimum height; a two-line label makes the pill taller.
  final double height;

  const SettingsButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.kind = SettingsButtonKind.primary,
    this.icon,
    this.loading = false,
    this.height = 50,
  });

  /// Horizontal padding inside the pill.
  static const double horizontalPadding = 18;

  static TextStyle labelStyle(Color ink) => AppFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: ink,
        height: 1.25,
      );

  /// Width this button needs to show its label on one line.
  double singleLineWidth(BuildContext context) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: labelStyle(Colors.black)),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final width =
        painter.width + horizontalPadding * 2 + (icon != null ? 26 : 0);
    painter.dispose();
    return width;
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final red = SettingsToneColors.of(context, SettingsTone.red);
    final (Color fill, Color ink) = switch (kind) {
      SettingsButtonKind.primary => (settingsPrimaryFill, settingsPrimaryInk),
      SettingsButtonKind.destructive => (red.fill, red.foreground),
      SettingsButtonKind.neutral => (palette.raised, palette.text),
    };
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: height),
      child: TextButton(
        onPressed: loading ? null : onPressed,
        style: TextButton.styleFrom(
          backgroundColor: fill,
          foregroundColor: ink,
          disabledBackgroundColor: fill.withValues(alpha: 0.6),
          disabledForegroundColor: ink.withValues(alpha: 0.7),
          shape: const StadiumBorder(),
          minimumSize: Size(0, height),
          padding: const EdgeInsets.symmetric(
              horizontal: horizontalPadding, vertical: 8),
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
                      softWrap: true,
                      style: labelStyle(ink),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Two or more [SettingsButton]s side by side, or stacked full-width when any
/// label would not fit its share of the row on one line (long hi/ml copy at
/// 320pt). When stacked, the last button — the primary action — goes on top.
class SettingsButtonRow extends StatelessWidget {
  final List<SettingsButton> buttons;
  final double spacing;

  const SettingsButtonRow({
    super.key,
    required this.buttons,
    this.spacing = 10,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final count = buttons.length;
          final share = (constraints.maxWidth - spacing * (count - 1)) / count;
          final fits =
              buttons.every((b) => b.singleLineWidth(context) <= share);
          if (fits) {
            return Row(
              children: [
                for (var i = 0; i < count; i++) ...[
                  if (i > 0) SizedBox(width: spacing),
                  Expanded(child: buttons[i]),
                ],
              ],
            );
          }
          final stacked = buttons.reversed.toList();
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < stacked.length; i++) ...[
                if (i > 0) SizedBox(height: spacing),
                stacked[i],
              ],
            ],
          );
        },
      );
}

/// Small card with an icon, a big number and a label under it.
class SettingsStatTile extends StatelessWidget {
  final IconData icon;
  final SettingsTone tone;
  final String value;
  final String label;

  const SettingsStatTile({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.tone = SettingsTone.indigo,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final colors = SettingsToneColors.of(context, tone);
    return Semantics(
      label: '$value $label',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: palette.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: colors.foreground),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: AppFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: palette.text,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppFonts.inter(fontSize: 12.5, color: palette.muted),
            ),
          ],
        ),
      ),
    );
  }
}
