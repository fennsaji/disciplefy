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
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: palette.isDark
            ? Colors.white.withValues(alpha: 0.06)
            : palette.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.outline),
      ),
      child: Row(
        children: [
          for (var i = 0; i < modes.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
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
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Center(
                // Name and duration share a line when they fit, and wrap
                // (never cut) in longer languages.
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 2,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isLocked
                              ? Icons.lock_outline_rounded
                              : mode.outlineIcon,
                          size: 15,
                          color: isSelected ? palette.onSelected : palette.gold,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            mode.localizedShortName(context),
                            style: AppFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      mode.localizedDuration(context),
                      style: AppFonts.inter(fontSize: 12, color: subInk),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
