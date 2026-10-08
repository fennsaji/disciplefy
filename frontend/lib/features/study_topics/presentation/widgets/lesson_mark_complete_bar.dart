import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/lesson_ref.dart';

/// The only primary action at the end of a path lesson: "Mark complete".
/// [secondary] holds small outlined buttons (share, follow-up) under it.
class LessonMarkCompleteBar extends StatefulWidget {
  final LessonRef lesson;
  final Future<void> Function() onComplete;
  final Widget? secondary;

  const LessonMarkCompleteBar({
    super.key,
    required this.lesson,
    required this.onComplete,
    this.secondary,
  });

  @override
  State<LessonMarkCompleteBar> createState() => _LessonMarkCompleteBarState();
}

class _LessonMarkCompleteBarState extends State<LessonMarkCompleteBar> {
  bool _busy = false;

  Future<void> _tap() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onComplete();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final fill = palette.isDark ? palette.ctaFill : palette.selectedFill;
    final label = context.tr(TranslationKeys.lessonMarkComplete, {
      'n': widget.lesson.lessonNumber,
      'total': widget.lesson.lessonTotal,
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          // Soft gold glow under the pill, in both themes.
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.brandGold.withValues(alpha: 0.8),
                blurRadius: 16,
              ),
            ],
          ),
          child: FilledButton.icon(
            onPressed: _busy ? null : _tap,
            style: FilledButton.styleFrom(
              backgroundColor: fill,
              foregroundColor: ReaderPalette.ink,
              disabledBackgroundColor: fill.withValues(alpha: 0.6),
              disabledForegroundColor: ReaderPalette.ink,
              minimumSize: const Size.fromHeight(40),
              maximumSize: const Size.fromHeight(40),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              // Web and desktop default to a compact density, which would
              // shave the 40px pill to 32.
              visualDensity: VisualDensity.standard,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              textStyle:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: ReaderPalette.ink,
                    ),
                  )
                : const Icon(Icons.check_rounded, size: 18),
            // Shrinks rather than cutting the label on a narrow phone.
            // The button already wraps the label in a Flexible.
            label: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label, maxLines: 1),
            ),
          ),
        ),
        if (widget.secondary != null) ...[
          const SizedBox(height: 12),
          widget.secondary!,
        ],
      ],
    );
  }
}
