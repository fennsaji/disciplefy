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
    final label = context.tr(TranslationKeys.lessonMarkComplete, {
      'n': widget.lesson.lessonNumber,
      'total': widget.lesson.lessonTotal,
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: _busy ? null : _tap,
          style: FilledButton.styleFrom(
            backgroundColor: palette.gold,
            foregroundColor: AppColors.brandPrimaryInk,
            disabledBackgroundColor: palette.gold.withValues(alpha: 0.6),
            disabledForegroundColor: AppColors.brandPrimaryInk,
            minimumSize: const Size.fromHeight(40),
            maximumSize: const Size.fromHeight(40),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            textStyle:
                const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          icon: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.brandPrimaryInk,
                  ),
                )
              : const Icon(Icons.check_rounded, size: 18),
          label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        if (widget.secondary != null) ...[
          const SizedBox(height: 8),
          widget.secondary!,
        ],
      ],
    );
  }
}
