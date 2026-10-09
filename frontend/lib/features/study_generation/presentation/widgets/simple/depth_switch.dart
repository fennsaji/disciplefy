import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_mode.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/widgets/study_mode_labels.dart';

/// Two-segment depth choice on the Generate tab: "Quick Read · 3 min" and
/// "Standard · 8 min".
///
/// [selected] may be a depth that is not one of [modes] (picked from the
/// full chooser); then no segment is highlighted.
class DepthSwitch extends StatelessWidget {
  final List<StudyMode> modes;
  final StudyMode? selected;
  final Set<StudyMode> locked;
  final ValueChanged<StudyMode> onSelected;
  final ValueChanged<StudyMode> onLockedTap;

  const DepthSwitch({
    super.key,
    required this.modes,
    required this.selected,
    required this.onSelected,
    required this.onLockedTap,
    this.locked = const {},
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: palette.isDark ? palette.raised : palette.card,
        borderRadius: BorderRadius.circular(23),
        border: palette.isDark ? null : Border.all(color: palette.outline),
      ),
      child: Row(
        children: [
          for (var i = 0; i < modes.length; i++) ...[
            if (i > 0) const SizedBox(width: 3),
            Expanded(child: _segment(context, palette, modes[i])),
          ],
        ],
      ),
    );
  }

  Widget _segment(BuildContext context, ReaderPalette palette, StudyMode mode) {
    final isSelected = mode == selected;
    final isLocked = locked.contains(mode);
    // The duration on the selected segment uses the same on-gold colour as
    // the name: a faded tint of it dropped below a readable ratio.
    final ink = isSelected ? palette.onSelected : palette.text;
    final subInk = isSelected ? palette.onSelected : palette.muted;

    return Semantics(
      button: true,
      selected: isSelected,
      child: Material(
        color: isSelected ? palette.selectedFill : Colors.transparent,
        shape: const StadiumBorder(),
        child: InkWell(
          key: ValueKey('depth_switch_${mode.name}'),
          customBorder: const StadiumBorder(),
          onTap: () => isLocked ? onLockedTap(mode) : onSelected(mode),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: _SegmentLabel(
                icon: isLocked ? Icons.lock_outline_rounded : mode.outlineIcon,
                // A lock always shows; the depth icon goes first when space
                // is short.
                keepIcon: isLocked,
                iconColor: isSelected ? palette.onSelected : palette.muted,
                name: mode.localizedShortName(context),
                nameStyle: AppFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: ink,
                ),
                duration: mode.localizedShortDuration(context),
                durationStyle: AppFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: subInk,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One line per segment: icon, name and short duration. When they do not
/// fit, the depth icon is dropped first; only then is the line scaled down
/// (never wrapped or cut).
class _SegmentLabel extends StatelessWidget {
  final IconData icon;
  final bool keepIcon;
  final Color iconColor;
  final String name;
  final TextStyle nameStyle;
  final String duration;
  final TextStyle durationStyle;

  const _SegmentLabel({
    required this.icon,
    required this.keepIcon,
    required this.iconColor,
    required this.name,
    required this.nameStyle,
    required this.duration,
    required this.durationStyle,
  });

  static const double _iconSize = 14;
  static const double _iconGap = 5;
  static const double _gap = 6;

  double _width(BuildContext context, String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final text = _width(context, name, nameStyle) +
          _gap +
          _width(context, duration, durationStyle);
      final showIcon =
          keepIcon || text + _iconSize + _iconGap <= constraints.maxWidth;
      return Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showIcon) ...[
                Icon(icon, size: _iconSize, color: iconColor),
                const SizedBox(width: _iconGap),
              ],
              Text(name, maxLines: 1, softWrap: false, style: nameStyle),
              const SizedBox(width: _gap),
              Text(duration,
                  maxLines: 1, softWrap: false, style: durationStyle),
            ],
          ),
        ),
      );
    });
  }
}
