import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/constants/app_fonts.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../../../shared/widgets/clickable_scripture_text.dart';
import '../../domain/entities/study_mode.dart';
import '../../domain/entities/study_stream_event.dart';

/// Removes duplicate section title from content if present at the start
String _cleanDuplicateTitle(String content, String title) {
  final lines = content.split('\n');
  if (lines.isEmpty) return content;

  // Remove markdown formatting and normalize for comparison
  final normalizedTitle =
      title.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
  final firstLine =
      lines.first.toLowerCase().replaceAll(RegExp(r'[*_#]'), '').trim();

  // Check if first line matches the title (with some tolerance)
  if (firstLine.contains(normalizedTitle) ||
      normalizedTitle.contains(firstLine)) {
    // Remove first line and any empty lines that follow
    final cleanedLines =
        lines.skip(1).skipWhile((line) => line.trim().isEmpty).toList();
    return cleanedLines.join('\n');
  }

  return content;
}

/// Widget for displaying streaming study guide content with progressive rendering.
///
/// Shows sections as they arrive from the SSE stream, with shimmer placeholders
/// for sections still loading. Adapts layout based on study mode:
/// - Quick: Compact card layout for 3-minute reads
/// - Standard: Full 6-section scrollable layout (default)
/// - Deep: Extended sections with word studies and cross-references
/// - Lectio: Meditative layout with Lectio Divina movements
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
  });

  @override
  Widget build(BuildContext context) {
    // Trigger completion callback when content is complete
    if (content.isComplete && onComplete != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onComplete!();
      });
    }

    // Route to mode-specific layout
    return switch (studyMode) {
      StudyMode.quick => _buildQuickModeContent(context),
      StudyMode.deep => _buildDeepModeContent(context),
      StudyMode.lectio => _buildLectioDivinaContent(context),
      StudyMode.standard => _buildStandardModeContent(context),
    };
  }

  /// Standard mode layout - full 6-section scrollable content (default)
  Widget _buildStandardModeContent(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isLargeScreen = screenHeight > 700;

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

  /// Quick mode layout - compact card-style for 3-minute reads
  Widget _buildQuickModeContent(BuildContext context) {
    return Column(
      children: [
        // Progress indicator
        if (!content.isComplete && !isPartial) _buildProgressBar(context),

        // Main content
        Expanded(
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),

                // Quick Read badge
                _buildQuickReadBadge(context),

                const SizedBox(height: 16),

                // Key Insight Card (summary)
                _buildQuickSection(
                  context,
                  title: 'Key Insight',
                  content: content.summary,
                  index: 0,
                  isHighlight: true,
                ),

                const SizedBox(height: 16),

                // Key Verse Card (interpretation contains verse)
                _buildQuickSection(
                  context,
                  title: 'Key Verse',
                  content: content.interpretation,
                  index: 1,
                ),

                const SizedBox(height: 16),

                // Quick Reflection (single question)
                _buildQuickSection(
                  context,
                  title: '🤔 Quick Reflection',
                  content: content.reflectionQuestions?.isNotEmpty == true
                      ? content.reflectionQuestions!.first
                      : null,
                  index: 4,
                ),

                const SizedBox(height: 16),

                // Brief Prayer
                _buildQuickSection(
                  context,
                  title: 'Brief Prayer',
                  content: content.prayerPoints?.isNotEmpty == true
                      ? content.prayerPoints!.first
                      : null,
                  index: 5,
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Quick Read badge widget
  Widget _buildQuickReadBadge(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt, size: 16, color: primaryColor),
          const SizedBox(width: 6),
          Text(
            '3-Minute Read',
            style: AppFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  /// Build a compact section for Quick mode
  Widget _buildQuickSection(
    BuildContext context, {
    required String title,
    required String? content,
    required int index,
    bool isHighlight = false,
  }) {
    final hasContent = content != null && content.isNotEmpty;
    final isLoading = !hasContent && this.content.sectionsLoaded <= index;

    if (isLoading && !isPartial) {
      return _QuickShimmerSection(title: title);
    }

    if (!hasContent) {
      return const SizedBox.shrink();
    }

    return _QuickSection(
      title: title,
      content: content,
      isHighlight: isHighlight,
      isNew: this.content.sectionsLoaded == index + 1,
    );
  }

  /// Deep Dive mode layout - extended sections with scholarly content
  Widget _buildDeepModeContent(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isLargeScreen = screenHeight > 700;

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

                // Deep Dive badge
                _buildDeepDiveBadge(context),

                const SizedBox(height: 16),

                // Topic Title
                _buildTopicTitle(context),

                SizedBox(height: isLargeScreen ? 24 : 20),

                // Comprehensive Overview (summary)
                _buildSection(
                  context,
                  title: 'Comprehensive Overview',
                  icon: Icons.summarize,
                  content: content.summary,
                  index: 0,
                ),

                const SizedBox(height: 28),

                // In-Depth Interpretation with Word Studies (interpretation)
                _buildSection(
                  context,
                  title: 'In-Depth Interpretation & Word Studies',
                  icon: Icons.lightbulb_outline,
                  content: content.interpretation,
                  index: 1,
                ),

                const SizedBox(height: 28),

                // Extended Context with Cross-References (context)
                _buildSection(
                  context,
                  title: 'Historical Context & Cross-References',
                  icon: Icons.history_edu,
                  content: content.context,
                  index: 2,
                ),

                const SizedBox(height: 28),

                // Scripture Connections (relatedVerses)
                _buildSection(
                  context,
                  title: 'Scripture Connections',
                  icon: Icons.menu_book,
                  content: content.relatedVerses?.join('\n\n'),
                  index: 3,
                ),

                const SizedBox(height: 28),

                // Deep Reflection Questions (reflectionQuestions)
                _buildSection(
                  context,
                  title: 'Deep Reflection & Journaling',
                  icon: Icons.edit_note,
                  content: content.reflectionQuestions
                      ?.asMap()
                      .entries
                      .map((entry) => '${entry.key + 1}. ${entry.value}')
                      .join('\n\n'),
                  index: 4,
                ),

                const SizedBox(height: 28),

                // Comprehensive Prayer (prayerPoints)
                _buildSection(
                  context,
                  title: 'Prayer for Deep Application',
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

  /// Deep Dive badge widget
  Widget _buildDeepDiveBadge(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.explore, size: 16, color: primaryColor),
          const SizedBox(width: 6),
          Text(
            '25-Minute Deep Dive',
            style: AppFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  /// Lectio Divina mode layout - meditative format with 4 movements
  Widget _buildLectioDivinaContent(BuildContext context) {
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
                const SizedBox(height: 20),

                // Lectio Divina badge
                _buildLectioDivinaBadge(context),

                const SizedBox(height: 20),

                // Scripture for Meditation (summary contains scripture)
                _buildLectioSection(
                  context,
                  title: 'Scripture for Meditation',
                  content: content.summary,
                  index: 0,
                  icon: Icons.menu_book,
                ),

                const SizedBox(height: 24),

                // LECTIO & MEDITATIO (interpretation)
                _buildLectioSection(
                  context,
                  title: 'Lectio & Meditatio',
                  subtitle: 'Read & Meditate',
                  content: content.interpretation,
                  index: 1,
                  icon: Icons.auto_stories,
                ),

                const SizedBox(height: 24),

                // About Lectio Divina (context)
                _buildLectioSection(
                  context,
                  title: 'About This Practice',
                  content: content.context,
                  index: 2,
                  icon: Icons.info_outline,
                ),

                const SizedBox(height: 24),

                // Focus Words (relatedVerses contains focus words)
                _buildLectioSection(
                  context,
                  title: 'Focus Words for Meditation',
                  content: content.relatedVerses?.join('\n• '),
                  index: 3,
                  icon: Icons.highlight,
                ),

                const SizedBox(height: 24),

                // ORATIO & CONTEMPLATIO (reflectionQuestions)
                _buildLectioSection(
                  context,
                  title: 'Oratio & Contemplatio',
                  subtitle: 'Pray & Rest',
                  content: content.reflectionQuestions?.join('\n\n'),
                  index: 4,
                  icon: Icons.self_improvement,
                ),

                const SizedBox(height: 24),

                // Closing (prayerPoints)
                _buildLectioSection(
                  context,
                  title: '🌟 Closing Blessing',
                  content: content.prayerPoints?.join('\n\n'),
                  index: 5,
                  icon: Icons.wb_sunny_outlined,
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Lectio Divina badge widget
  Widget _buildLectioDivinaBadge(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.spa, size: 16, color: primaryColor),
          const SizedBox(width: 6),
          Text(
            'Lectio Divina • 15 Minutes',
            style: AppFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  /// Build a Lectio Divina section with meditative styling
  Widget _buildLectioSection(
    BuildContext context, {
    required String title,
    String? subtitle,
    required String? content,
    required int index,
    required IconData icon,
  }) {
    final hasContent = content != null && content.isNotEmpty;
    final isLoading = !hasContent && this.content.sectionsLoaded <= index;

    if (isLoading && !isPartial) {
      return _ShimmerSection(title: title, icon: icon);
    }

    if (!hasContent) {
      return const SizedBox.shrink();
    }

    return _LectioSection(
      title: title,
      subtitle: subtitle,
      content: content,
      icon: icon,
      isNew: this.content.sectionsLoaded == index + 1,
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
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    padding: const EdgeInsets.all(8),
                    tooltip: 'Copy ${widget.title}',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Section Content with clickable scripture references
              ClickableScriptureText(
                text: _cleanDuplicateTitle(widget.content, widget.title),
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
              Expanded(
                child: Text(
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

/// Compact section for Quick Read mode with card-style layout
class _QuickSection extends StatefulWidget {
  final String title;
  final String content;
  final bool isHighlight;
  final bool isNew;

  const _QuickSection({
    required this.title,
    required this.content,
    this.isHighlight = false,
    this.isNew = false,
  });

  @override
  State<_QuickSection> createState() => _QuickSectionState();
}

class _QuickSectionState extends State<_QuickSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

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
    final highlightColor = Theme.of(context).colorScheme.secondary;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.isHighlight
                ? highlightColor.withOpacity(0.15)
                : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.isHighlight
                  ? highlightColor.withOpacity(0.4)
                  : primaryColor.withOpacity(0.1),
              width: widget.isHighlight ? 1.5 : 1,
            ),
            boxShadow: widget.isHighlight
                ? [
                    BoxShadow(
                      color: highlightColor.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Compact title
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: AppFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: widget.isHighlight
                            ? primaryColor
                            : Theme.of(context)
                                .colorScheme
                                .onBackground
                                .withOpacity(0.8),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _copyToClipboard(context),
                    icon: Icon(
                      Icons.copy,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.5),
                      size: 16,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    padding: const EdgeInsets.all(8),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Content
              ClickableScriptureText(
                text: _cleanDuplicateTitle(widget.content, widget.title),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: widget.isHighlight
                          ? FontWeight.w500
                          : FontWeight.w400,
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

/// Shimmer placeholder for Quick Read sections
class _QuickShimmerSection extends StatelessWidget {
  final String title;

  const _QuickShimmerSection({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: primaryColor.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            title,
            style: AppFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color:
                  Theme.of(context).colorScheme.onBackground.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 10),
          // Shimmer lines
          Shimmer.fromColors(
            baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
            highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _shimmerLine(width: double.infinity),
                const SizedBox(height: 6),
                _shimmerLine(width: 180),
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
      height: 14,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

/// Meditative section for Lectio Divina mode
class _LectioSection extends StatefulWidget {
  final String title;
  final String? subtitle;
  final String content;
  final IconData icon;
  final bool isNew;

  const _LectioSection({
    required this.title,
    this.subtitle,
    required this.content,
    required this.icon,
    this.isNew = false,
  });

  @override
  State<_LectioSection> createState() => _LectioSectionState();
}

class _LectioSectionState extends State<_LectioSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Softer, more meditative colors for Lectio Divina
    final backgroundColor = isDark
        ? primaryColor.withOpacity(0.08)
        : primaryColor.withOpacity(0.04);
    final borderColor =
        isDark ? primaryColor.withOpacity(0.2) : primaryColor.withOpacity(0.15);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with icon
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      widget.icon,
                      color: primaryColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: AppFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onBackground,
                          ),
                        ),
                        if (widget.subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.subtitle!,
                            style: AppFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: primaryColor.withOpacity(0.8),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _copyToClipboard(context),
                    icon: Icon(
                      Icons.copy,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.5),
                      size: 16,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    padding: const EdgeInsets.all(8),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Divider for meditative feel
              Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      primaryColor.withOpacity(0.0),
                      primaryColor.withOpacity(0.2),
                      primaryColor.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Content with meditative typography
              ClickableScriptureText(
                text: _cleanDuplicateTitle(widget.content, widget.title),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w400,
                      color: Theme.of(context).colorScheme.onBackground,
                      height: 1.7, // Extra line height for meditative reading
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
