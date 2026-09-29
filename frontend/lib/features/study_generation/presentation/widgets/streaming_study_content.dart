import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_mode.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_stream_event.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/widgets/study_guide_body.dart';

/// Study guide content while it streams in: a progress bar over the same
/// [StudyGuideBody] the finished guide uses, with shimmer placeholders for
/// sections that have not arrived. Sharing the body keeps padding, cards and
/// section order identical, so nothing moves when the stream completes.
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
    this.contentFontSize = 18.0,
  });

  @override
  Widget build(BuildContext context) {
    if (content.isComplete && onComplete != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => onComplete!());
    }

    // The progress bar floats over the top gap instead of sitting above the
    // scroll view: in the flow it pushed the page down ~45px, and the whole
    // guide jumped up when the stream finished and the bar went away.
    return Stack(
      children: [
        SingleChildScrollView(
          controller: scrollController,
          padding: StudyGuideLayout.sidePadding,
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

  /// A 4px bar that fits inside the gap above the title card. The section
  /// count is kept for screen readers.
  Widget _buildProgressBar(BuildContext context) {
    final theme = Theme.of(context);
    final label = '${context.tr(TranslationKeys.studyGuideStreamingLoading)} '
        '${context.tr(TranslationKeys.studyGuideStreamingSections).replaceAll('{count}', '${content.sectionsLoaded}').replaceAll('{total}', '${content.totalSections}')}';
    return Semantics(
      label: label,
      child: Padding(
        padding: StudyGuideLayout.sidePadding.copyWith(top: 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: content.progress,
            backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
            valueColor:
                AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
            minHeight: 4,
          ),
        ),
      ),
    );
  }
}
