import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_mode.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_stream_event.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/widgets/study_guide_body.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/widgets/study_reading_tracker.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/lesson_ref.dart';

/// Study guide content while it streams in: a thin progress line over the
/// same [StudyGuideBody] (hero + numbered sections) the finished guide uses,
/// with shimmer placeholders for sections that have not arrived. Sharing the
/// body keeps padding, numbering and section order identical, so nothing
/// moves when the stream completes.
class StreamingStudyContent extends StatelessWidget {
  /// The accumulated streaming content
  final StreamingStudyGuideContent content;

  /// Input type (scripture, topic, question)
  final String inputType;

  /// Input value (the verse/topic/question)
  final String inputValue;

  /// Language code
  final String language;

  /// Scroll controller for the content
  final ScrollController? scrollController;

  /// Callback when streaming is complete
  final VoidCallback? onComplete;

  /// Whether this is partial content from a failed stream
  final bool isPartial;

  /// Study mode for layout adaptation
  final StudyMode studyMode;

  /// Font size override for section content text
  final double contentFontSize;

  /// Drives the hero's segmented reading progress.
  final StudyReadingTracker? tracker;

  /// Set when the guide is a lesson of a learning path.
  final LessonRef? lesson;

  /// Shown under the title (the lesson's Quick/Full switch).
  final Widget? headerAccessory;

  const StreamingStudyContent({
    super.key,
    required this.content,
    required this.inputType,
    required this.inputValue,
    required this.language,
    this.scrollController,
    this.onComplete,
    this.isPartial = false,
    this.studyMode = StudyMode.standard,
    this.contentFontSize = 16.0,
    this.tracker,
    this.lesson,
    this.headerAccessory,
  });

  @override
  Widget build(BuildContext context) {
    if (content.isComplete && onComplete != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => onComplete!());
    }

    // The progress line floats over the hero instead of sitting above the
    // scroll view: in the flow it pushed the page down, and the whole guide
    // jumped up when the stream finished and the line went away.
    return Stack(
      children: [
        SingleChildScrollView(
          controller: scrollController,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StudyGuideBody(
                studyMode: studyMode,
                sections: StudyGuideSections.fromStreaming(
                  content,
                  isPartial: isPartial,
                ),
                inputType: inputType,
                title: StudyGuideLayout.displayTitle(inputType, inputValue),
                contentFontSize: contentFontSize,
                tracker: tracker,
                lesson: lesson,
                headerAccessory: headerAccessory,
              ),
              SizedBox(height: StudyGuideLayout.endGap(context)),
            ],
          ),
        ),
        if (!content.isComplete && !isPartial)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildProgressBar(context),
          ),
      ],
    );
  }

  /// A 2px gold line along the top of the hero, under the status bar. The
  /// section count is kept for screen readers.
  Widget _buildProgressBar(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final label = '${context.tr(TranslationKeys.studyGuideStreamingLoading)} '
        '${context.tr(TranslationKeys.studyGuideStreamingSections).replaceAll('{count}', '${content.sectionsLoaded}').replaceAll('{total}', '${content.totalSections}')}';
    return Semantics(
      label: label,
      child: Padding(
        padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
        child: LinearProgressIndicator(
          value: content.progress,
          backgroundColor: Colors.transparent,
          valueColor: AlwaysStoppedAnimation<Color>(palette.gold),
          minHeight: 2,
        ),
      ),
    );
  }
}
