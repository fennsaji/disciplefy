import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_mode.dart';

/// Two-segment "Quick Read · 3 min / Standard · 8 min" switch shown under a
/// lesson's title. The current segment is filled with the palette's selected
/// gold; tapping the other reports it through [onChanged].
class LessonModeSwitch extends StatelessWidget {
  /// Owner rule: the switch is offered on a Quick Read lesson (to move up
  /// to Standard) and to a guest; a signed-in reader of a Standard or deeper
  /// lesson does not see it at all.
  static bool shownFor({required StudyMode mode, required bool isGuest}) =>
      isGuest || mode == StudyMode.quick;

  final StudyMode current;
  final ValueChanged<StudyMode> onChanged;

  const LessonModeSwitch({
    super.key,
    required this.current,
    required this.onChanged,
  });

  static const double _height = 32;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _Segment(
            boxKey: const Key('lesson_mode_quick'),
            mode: StudyMode.quick,
            labelKey: TranslationKeys.lessonQuickRead,
            selected: current == StudyMode.quick,
            onTap: onChanged,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Segment(
            boxKey: const Key('lesson_mode_full'),
            mode: StudyMode.standard,
            labelKey: TranslationKeys.lessonFullGuide,
            selected: current == StudyMode.standard,
            onTap: onChanged,
          ),
        ),
      ],
    );
  }
}

class _Segment extends StatelessWidget {
  final Key boxKey;
  final StudyMode mode;
  final String labelKey;
  final bool selected;
  final ValueChanged<StudyMode> onTap;

  const _Segment({
    required this.boxKey,
    required this.mode,
    required this.labelKey,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final label = context.tr(labelKey, {'min': mode.durationMinutes});
    return Semantics(
      button: true,
      selected: selected,
      excludeSemantics: true,
      label: label,
      onTap: selected ? null : () => onTap(mode),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: selected ? null : () => onTap(mode),
        child: SizedBox(
          height: LessonModeSwitch._height,
          child: DecoratedBox(
            key: boxKey,
            decoration: BoxDecoration(
              color: selected ? palette.selectedFill : palette.card,
              borderRadius: BorderRadius.circular(16),
              border: selected ? null : Border.all(color: palette.outline),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.fade,
                  style: AppFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected ? palette.onSelected : palette.muted,
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
