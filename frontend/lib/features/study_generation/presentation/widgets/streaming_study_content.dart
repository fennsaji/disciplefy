import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/constants/app_fonts.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../../../shared/widgets/clickable_scripture_text.dart';
import '../../domain/entities/study_stream_event.dart';

/// Widget for displaying streaming study guide content with progressive rendering.
///
/// Shows sections as they arrive from the SSE stream, with shimmer placeholders
/// for sections still loading.
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

  const StreamingStudyContent({
    super.key,
    required this.content,
    required this.inputType,
    required this.inputValue,
    required this.language,
    this.scrollController,
    this.onComplete,
    this.isPartial = false,
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isLargeScreen = screenHeight > 700;

    // Trigger completion callback when content is complete
    if (content.isComplete && onComplete != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onComplete!();
      });
    }

    return Column(
      children: [
        // Progress indicator
        if (!content.isComplete && !isPartial) _buildProgressBar(context),

        // Main content
        Expanded(
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: isLargeScreen ? 24 : 16),

                // Topic Title
                _buildTopicTitle(context),

                SizedBox(height: isLargeScreen ? 24 : 20),

                // Summary Section
                _buildSection(
                  context,
                  title: context.tr(TranslationKeys.studyGuideSummary),
                  icon: Icons.summarize,
                  content: content.summary,
                  index: 0,
                ),

                const SizedBox(height: 24),

                // Interpretation Section
                _buildSection(
                  context,
                  title: context.tr(TranslationKeys.studyGuideInterpretation),
                  icon: Icons.lightbulb_outline,
                  content: content.interpretation,
                  index: 1,
                ),

                const SizedBox(height: 24),

                // Context Section
                _buildSection(
                  context,
                  title: context.tr(TranslationKeys.studyGuideContext),
                  icon: Icons.history_edu,
                  content: content.context,
                  index: 2,
                ),

                const SizedBox(height: 24),

                // Related Verses Section
                _buildSection(
                  context,
                  title: context.tr(TranslationKeys.studyGuideRelatedVerses),
                  icon: Icons.menu_book,
                  content: content.relatedVerses?.join('\n\n'),
                  index: 3,
                ),

                const SizedBox(height: 24),

                // Reflection Questions Section
                _buildSection(
                  context,
                  title:
                      context.tr(TranslationKeys.studyGuideDiscussionQuestions),
                  icon: Icons.quiz,
                  content: content.reflectionQuestions
                      ?.asMap()
                      .entries
                      .map((entry) => '${entry.key + 1}. ${entry.value}')
                      .join('\n\n'),
                  index: 4,
                ),

                const SizedBox(height: 24),

                // Prayer Points Section
                _buildSection(
                  context,
                  title: context.tr(TranslationKeys.studyGuidePrayerPoints),
                  icon: Icons.favorite,
                  content: content.prayerPoints
                      ?.asMap()
                      .entries
                      .map((entry) => '• ${entry.value}')
                      .join('\n'),
                  index: 5,
                ),

                SizedBox(height: isLargeScreen ? 32 : 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Build the progress bar showing streaming progress
  Widget _buildProgressBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.tr(TranslationKeys.studyGuideStreamingLoading),
                style: AppFonts.inter(
                  fontSize: 12,
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              Text(
                context
                    .tr(TranslationKeys.studyGuideStreamingSections)
                    .replaceAll('{count}', '${content.sectionsLoaded}'),
                style: AppFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: content.progress,
              backgroundColor:
                  Theme.of(context).colorScheme.primary.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  /// Build the topic title section
  Widget _buildTopicTitle(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary.withOpacity(0.1),
            Theme.of(context).colorScheme.secondary.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            inputType == 'scripture'
                ? context.tr('generate_study.scripture_mode')
                : context.tr('generate_study.topic_mode'),
            style: AppFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            inputType == 'scripture'
                ? inputValue
                : inputValue.substring(0, 1).toUpperCase() +
                    inputValue.substring(1),
            style: AppFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onBackground,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  /// Build a single section with content or shimmer placeholder
  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required String? content,
    required int index,
  }) {
    final hasContent = content != null && content.isNotEmpty;
    final isLoading = !hasContent && this.content.sectionsLoaded <= index;

    if (isLoading && !isPartial) {
      return _ShimmerSection(title: title, icon: icon);
    }

    if (!hasContent) {
      // Section was expected but content is empty (error case)
      return const SizedBox.shrink();
    }

    return _StreamingSection(
      title: title,
      icon: icon,
      content: content,
      isNew: this.content.sectionsLoaded == index + 1,
    );
  }
}

/// A section that displays content with fade-in animation
class _StreamingSection extends StatefulWidget {
  final String title;
  final IconData icon;
  final String content;
  final bool isNew;

  const _StreamingSection({
    required this.title,
    required this.icon,
    required this.content,
    this.isNew = false,
  });

  @override
  State<_StreamingSection> createState() => _StreamingSectionState();
}

class _StreamingSectionState extends State<_StreamingSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    // Start animation if this is a new section
    if (widget.isNew) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: primaryColor.withOpacity(0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section Header
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      widget.icon,
                      color: primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: AppFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onBackground,
                      ),
                    ),
                  ),
                  // Copy button
                  IconButton(
                    onPressed: () => _copyToClipboard(context),
                    icon: Icon(
                      Icons.copy,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.6),
                      size: 18,
                    ),
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                    tooltip: 'Copy ${widget.title}',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Section Content with clickable scripture references
              ClickableScriptureText(
                text: widget.content,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onBackground,
                      height: 1.6,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: widget.content));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.tr(TranslationKeys.studyGuideCopiedToClipboard),
          style: AppFonts.inter(color: Colors.white),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

/// Shimmer placeholder for sections still loading
class _ShimmerSection extends StatelessWidget {
  final String title;
  final IconData icon;

  const _ShimmerSection({
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: primaryColor.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header (static)
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: primaryColor.withOpacity(0.5),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: AppFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context)
                      .colorScheme
                      .onBackground
                      .withOpacity(0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Shimmer content lines
          Shimmer.fromColors(
            baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
            highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _shimmerLine(width: double.infinity),
                const SizedBox(height: 8),
                _shimmerLine(width: double.infinity),
                const SizedBox(height: 8),
                _shimmerLine(width: 200),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _shimmerLine({required double width}) {
    return Container(
      width: width,
      height: 16,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
