import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/widgets/settings_group.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/widgets/settings_sheet.dart';

/// Pieces shared by the plain-page community screens (fellowship settings,
/// daily post, create/join, meetings sheet): a gold-eyebrow page heading,
/// form cards and fields, a segmented control, icon-less setting rows and a
/// single-choice sheet.
///
/// All colours come from [ReaderPalette]; no shadows, blur or animation.

/// Gold tracked eyebrow over a large Poppins page title, with an optional
/// muted line under it. Sits at the top of the page body, under a back bar.
class CommunityPageHeading extends StatelessWidget {
  final String? eyebrow;
  final String title;
  final String? subtitle;

  const CommunityPageHeading({
    super.key,
    this.eyebrow,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (eyebrow != null && eyebrow!.isNotEmpty) ...[
          Semantics(
            header: false,
            child: Text(
              eyebrow!.toUpperCase(),
              style: AppFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.7,
                height: 1.4,
                color: palette.gold,
              ),
            ),
          ),
          const SizedBox(height: 6),
        ],
        Semantics(
          header: true,
          child: Text(
            title,
            style: AppFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: palette.text,
              height: 1.2,
            ),
          ),
        ),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
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

/// Card fill, 22 radius and a 1px hairline around free-form content
/// (fields, segmented controls, previews).
class CommunityFormCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Optional border colour (e.g. gold for the Discipler next-post card).
  final Color? borderColor;

  /// Optional top-to-bottom tint painted over the card fill.
  final Gradient? tint;

  const CommunityFormCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderColor,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: palette.card,
        gradient: tint,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor ?? palette.hairline),
      ),
      padding: padding,
      child: child,
    );
  }
}

/// Muted label above a field or control inside a [CommunityFormCard].
class CommunityFieldLabel extends StatelessWidget {
  final String text;

  const CommunityFieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: AppFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: palette.muted,
          height: 1.35,
        ),
      ),
    );
  }
}

/// Fill used by inputs and segmented tracks inside a card: the page colour
/// on dark (a sunken well), the raised grey on light.
Color communityWellFill(ReaderPalette palette) =>
    palette.isDark ? palette.page : palette.raised;

/// Input decoration for community forms: sunken fill, 16 radius, no outline
/// until focused, muted hint, red error text.
InputDecoration communityInputDecoration(
  BuildContext context, {
  String? hintText,
  String? labelText,
  String? helperText,
  IconData? prefixIcon,
}) {
  final palette = ReaderPalette.of(context);
  final error = SettingsToneColors.of(context, SettingsTone.red).foreground;
  OutlineInputBorder border([Color? color, double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: color == null
            ? BorderSide.none
            : BorderSide(color: color, width: width),
      );
  return InputDecoration(
    hintText: hintText,
    labelText: labelText,
    helperText: helperText,
    hintMaxLines: 3,
    helperMaxLines: 3,
    errorMaxLines: 3,
    hintStyle: AppFonts.inter(fontSize: 15, color: palette.dim),
    labelStyle: AppFonts.inter(fontSize: 14, color: palette.muted),
    helperStyle: AppFonts.inter(fontSize: 12, color: palette.muted),
    errorStyle: AppFonts.inter(fontSize: 12, color: error),
    counterStyle: AppFonts.inter(fontSize: 12, color: palette.dim),
    filled: true,
    fillColor: communityWellFill(palette),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    prefixIcon: prefixIcon == null
        ? null
        : Icon(prefixIcon, size: 20, color: palette.muted),
    border: border(),
    enabledBorder: border(),
    disabledBorder: border(),
    focusedBorder: border(palette.accentIcon, 1.5),
    errorBorder: border(error),
    focusedErrorBorder: border(error, 1.5),
  );
}

/// Text style for what the user types into a community form field.
TextStyle communityInputStyle(BuildContext context) => AppFonts.inter(
      fontSize: 15.5,
      color: ReaderPalette.of(context).text,
      height: 1.4,
    );

/// One option of a [CommunitySegmented] control.
@immutable
class CommunitySegment<T> {
  final T value;
  final String label;
  final IconData? icon;

  const CommunitySegment(this.value, this.label, {this.icon});
}

/// Segmented control on a sunken track: the selected segment is lifted onto
/// the raised fill (dark) or the card (light). Labels wrap instead of being
/// cut, so long hi/ml labels grow the control rather than truncate.
class CommunitySegmented<T> extends StatelessWidget {
  final List<CommunitySegment<T>> segments;
  final T selected;

  /// Null disables the control.
  final ValueChanged<T>? onChanged;

  const CommunitySegmented({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final enabled = onChanged != null;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: communityWellFill(palette),
          borderRadius: BorderRadius.circular(16),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final segment in segments)
                Expanded(
                  child: _SegmentButton(
                    label: segment.label,
                    icon: segment.icon,
                    selected: segment.value == selected,
                    onTap: enabled && segment.value != selected
                        ? () => onChanged!(segment.value)
                        : null,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;

  const _SegmentButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final fill = selected
        ? (palette.isDark ? palette.raised : palette.card)
        : Colors.transparent;
    final ink = selected ? palette.text : palette.muted;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: fill,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 16, color: ink),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: AppFonts.inter(
                        fontSize: 14.5,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500,
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

/// Settings-style row without an icon tile: title (+ subtitle), optional
/// muted value, custom trailing widget, and a chevron when tappable.
///
/// Put several in a [SettingsGroup] to get the hairlines between them.
class CommunitySettingRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? value;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Dims the row (e.g. while the feature it configures is off).
  final bool enabled;

  const CommunitySettingRow({
    super.key,
    required this.title,
    this.subtitle,
    this.value,
    this.leading,
    this.trailing,
    this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final tappable = onTap != null && enabled;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: InkWell(
        onTap: tappable ? onTap : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 58),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                if (leading != null) ...[
                  leading!,
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
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: palette.text,
                          height: 1.3,
                        ),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle!,
                          style: AppFonts.inter(
                            fontSize: 13,
                            color: palette.muted,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (value != null && value!.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  // Capped so a long value never squeezes the title away;
                  // it wraps rather than being cut.
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 130),
                    child: Text(
                      value!,
                      textAlign: TextAlign.end,
                      style: AppFonts.inter(
                        fontSize: 15,
                        color: palette.muted,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
                if (trailing != null) ...[
                  const SizedBox(width: 10),
                  trailing!,
                ],
                if (tappable && trailing == null) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.chevron_right_rounded,
                      size: 20, color: palette.dim),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A [CommunitySettingRow] with a [SettingsSwitch]; the whole row toggles.
class CommunitySwitchRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;

  /// Null disables the switch (and dims the row).
  final ValueChanged<bool>? onChanged;

  const CommunitySwitchRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: CommunitySettingRow(
        title: title,
        subtitle: subtitle,
        enabled: onChanged != null,
        onTap: onChanged == null ? null : () => onChanged!(!value),
        trailing: SettingsSwitch(value: value, onChanged: onChanged),
      ),
    );
  }
}

/// Opens a settings-style sheet listing [options] with a radio each; returns
/// the chosen value, or null when dismissed.
Future<T?> showCommunityChoiceSheet<T>({
  required BuildContext context,
  required String title,
  required List<CommunitySegment<T>> options,
  required T selected,
}) {
  return showSettingsSheet<T>(
    context: context,
    builder: (sheetContext) => SettingsSheetFrame(
      title: title,
      children: [
        SettingsSheetGroup(
          children: [
            for (final option in options)
              SettingsRadioRow(
                title: option.label,
                selected: option.value == selected,
                onTap: () => Navigator.of(sheetContext).pop(option.value),
              ),
          ],
        ),
      ],
    ),
  );
}

/// Muted uppercase label above a group, with room for a trailing widget.
/// Thin wrapper so community pages share the settings spacing.
class CommunityGroupLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;

  const CommunityGroupLabel(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) =>
      SettingsSectionLabel(text, trailing: trailing);
}

/// Full-width primary action in the community CTA colours
/// ([ReaderPalette.ctaFill]/`ctaInk`): white with indigo ink on dark, indigo
/// with white ink on light. The label wraps instead of truncating; a
/// spinner replaces the icon while [loading].
class CommunityWideCta extends StatelessWidget {
  final String label;
  final IconData? icon;

  /// Null disables the button.
  final VoidCallback? onPressed;
  final bool loading;

  const CommunityWideCta({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final enabled = onPressed != null && !loading;
    // While loading the pill keeps its colour (with a spinner); otherwise a
    // disabled pill is the raised fill with muted ink, never a faded CTA.
    final ink = loading || enabled ? palette.ctaInk : palette.muted;
    final fill = loading || enabled ? palette.ctaFill : palette.raised;
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: fill,
          foregroundColor: ink,
          disabledBackgroundColor: fill,
          disabledForegroundColor: ink,
          minimumSize: const Size.fromHeight(54),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: const StadiumBorder(),
          elevation: 0,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(ink),
                ),
              )
            else if (icon != null)
              Icon(icon, size: 20),
            if (loading || icon != null) const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: AppFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
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
