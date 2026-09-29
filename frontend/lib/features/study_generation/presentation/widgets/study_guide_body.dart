import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_guide.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_mode.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_stream_event.dart';
import 'package:disciplefy_bible_study/shared/widgets/markdown_with_scripture.dart';

/// Layout values shared by the streaming (loading) and the finished study
/// guide views. Both render [StudyGuideBody] inside [sidePadding], so the page
/// does not shift when the stream completes and the finished view takes over.
class StudyGuideLayout {
  StudyGuideLayout._();

  /// 12, not 24: the cards carry their own inset, so a wider value cost ~44px
  /// on each side before a word appeared. Devanagari and Malayalam set longer
  /// words than English and were breaking mid-word on a phone.
  static const EdgeInsets sidePadding = EdgeInsets.symmetric(horizontal: 12);

  static bool isLargeScreen(BuildContext context) =>
      MediaQuery.of(context).size.height > 700;

  /// Space above the title card, and between the title card and the badge or
  /// first section.
  static double blockGap(BuildContext context) =>
      isLargeScreen(context) ? 24 : 20;

  /// Space after the last section.
  static double endGap(BuildContext context) =>
      isLargeScreen(context) ? 32 : 24;

  /// Title shown in the title card: scripture references as typed, topics with
  /// a capital first letter.
  static String displayTitle(String inputType, String input) {
    if (inputType == 'scripture' || input.isEmpty) return input;
    return input.substring(0, 1).toUpperCase() + input.substring(1);
  }
}

/// The study guide's section content, from either a finished [StudyGuide] or
/// a stream that is still arriving. Null fields mean "not received yet".
class StudyGuideSections {
  final String? summary;
  final String? context;
  final String? passage;
  final String? interpretation;
  final List<String>? relatedVerses;
  final List<String>? reflectionQuestions;
  final List<String>? prayerPoints;

  /// Sections received so far; only meaningful while [isStreaming].
  final int sectionsLoaded;

  /// True while sections are still arriving: missing sections show a shimmer.
  final bool isStreaming;

  const StudyGuideSections({
    this.summary,
    this.context,
    this.passage,
    this.interpretation,
    this.relatedVerses,
    this.reflectionQuestions,
    this.prayerPoints,
    this.sectionsLoaded = 0,
    this.isStreaming = false,
  });

  factory StudyGuideSections.fromStudyGuide(StudyGuide guide) =>
      StudyGuideSections(
        summary: guide.summary,
        context: guide.context,
        passage: guide.passage,
        interpretation: guide.interpretation,
        relatedVerses: guide.relatedVerses,
        reflectionQuestions: guide.reflectionQuestions,
        prayerPoints: guide.prayerPoints,
      );

  /// [isPartial] is a stream that failed part-way: show what arrived and no
  /// shimmer for what never will.
  factory StudyGuideSections.fromStreaming(
    StreamingStudyGuideContent content, {
    bool isPartial = false,
  }) =>
      StudyGuideSections(
        summary: content.summary,
        context: content.context,
        passage: content.passage,
        interpretation: content.interpretation,
        relatedVerses: content.relatedVerses,
        reflectionQuestions: content.reflectionQuestions,
        prayerPoints: content.prayerPoints,
        sectionsLoaded: content.sectionsLoaded,
        isStreaming: !content.isComplete && !isPartial,
      );

  bool isLoading(int index) => isStreaming && sectionsLoaded <= index;

  bool isNew(int index) => isStreaming && sectionsLoaded == index + 1;
}

/// Card style for a section. One per study mode family.
enum StudySectionStyle { standard, quick, lectio }

/// Title card, mode badge and every section of a study guide, for all modes.
///
/// Used by both the streaming view and the finished view so the two cannot
/// drift apart. Applies no horizontal padding: callers wrap it in
/// [StudyGuideLayout.sidePadding].
class StudyGuideBody extends StatelessWidget {
  final StudyMode studyMode;
  final StudyGuideSections sections;
  final String inputType;
  final String title;
  final double contentFontSize;

  /// Index of the section text-to-speech is reading, or null. Highlighted in
  /// the modes that support read-aloud tracking (standard, deep, sermon).
  final int? readingSectionIndex;

  /// Attached to the interpretation section so the screen can find it.
  final Key? interpretationKey;

  const StudyGuideBody({
    super.key,
    required this.studyMode,
    required this.sections,
    required this.inputType,
    required this.title,
    this.contentFontSize = 18.0,
    this.readingSectionIndex,
    this.interpretationKey,
  });

  @override
  Widget build(BuildContext context) {
    final blockGap = StudyGuideLayout.blockGap(context);
    final badge = _buildBadge(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: blockGap),
        StudyGuideTopicTitle(inputType: inputType, title: title),
        SizedBox(height: blockGap),
        if (badge != null) ...[badge, const SizedBox(height: 16)],
        ..._buildSections(context),
      ],
    );
  }

  Widget? _buildBadge(BuildContext context) => switch (studyMode) {
        StudyMode.quick => StudyModeBadge(
            icon: Icons.bolt,
            label: context.tr(TranslationKeys.studyModeQuickDuration)),
        StudyMode.deep => StudyModeBadge(
            icon: Icons.explore,
            label: context.tr(TranslationKeys.studyModeDeepDuration)),
        StudyMode.lectio => StudyModeBadge(
            icon: Icons.spa,
            label: context.tr(TranslationKeys.lectioDurationLabel)),
        StudyMode.sermon => const SermonBadge(),
        StudyMode.standard => null,
      };

  List<Widget> _buildSections(BuildContext context) {
    final specs = _specsFor(context);
    final gap = switch (studyMode) {
      StudyMode.quick => 16.0,
      StudyMode.deep => 28.0,
      _ => 24.0,
    };
    final style = switch (studyMode) {
      StudyMode.quick => StudySectionStyle.quick,
      StudyMode.lectio => StudySectionStyle.lectio,
      _ => StudySectionStyle.standard,
    };
    final tracksReading = studyMode == StudyMode.standard ||
        studyMode == StudyMode.deep ||
        studyMode == StudyMode.sermon;

    final children = <Widget>[];
    for (final spec in specs) {
      final text = spec.content;
      Widget? child;
      if (text == null || text.isEmpty) {
        if (!spec.optional && sections.isLoading(spec.index)) {
          child = StudySectionShimmer(
              title: spec.title, icon: spec.icon, style: style);
        }
      } else if (spec.isAltarCall) {
        child = AltarCallCard(
          content: text,
          contentFontSize: contentFontSize,
          isNew: sections.isNew(spec.index),
        );
      } else {
        child = StudySectionCard(
          title: spec.title,
          subtitle: spec.subtitle,
          icon: spec.icon,
          content: text,
          style: style,
          isHighlight: spec.isHighlight,
          isBeingRead: tracksReading && readingSectionIndex == spec.index,
          isNew: sections.isNew(spec.index),
          contentFontSize: contentFontSize,
        );
      }
      if (child == null) continue;
      if (spec.index == 3 && interpretationKey != null) {
        child = KeyedSubtree(key: interpretationKey, child: child);
      }
      if (children.isNotEmpty) children.add(SizedBox(height: gap));
      children.add(child);
    }
    return children;
  }

  List<_SectionSpec> _specsFor(BuildContext context) {
    final s = sections;
    String? numbered(List<String>? items) => items
        ?.asMap()
        .entries
        .map((e) => '${e.key + 1}. ${e.value}')
        .join('\n\n');
    String? bulleted(List<String>? items) =>
        items?.map((i) => '• $i').join('\n');
    String? prayer(List<String>? items) => items == null
        ? null
        : items.length == 1
            ? items.first
            : bulleted(items);
    String? paragraphs(List<String>? items) => items?.join('\n\n');
    final passage = _SectionSpec(
      index: 2,
      title: context.tr(TranslationKeys.studyGuidePassageReading),
      icon: studyMode == StudyMode.quick
          ? Icons.menu_book_outlined
          : Icons.auto_stories,
      content: s.passage,
      optional: true,
    );

    return switch (studyMode) {
      StudyMode.standard => [
          _SectionSpec(
              index: 0,
              title: context.tr(TranslationKeys.studyGuideSummary),
              icon: Icons.summarize,
              content: s.summary),
          _SectionSpec(
              index: 1,
              title: context.tr(TranslationKeys.studyGuideContext),
              icon: Icons.history_edu,
              content: s.context),
          passage,
          _SectionSpec(
              index: 3,
              title: context.tr(TranslationKeys.studyGuideInterpretation),
              icon: Icons.lightbulb_outline,
              content: s.interpretation),
          _SectionSpec(
              index: 4,
              title: context.tr(TranslationKeys.studyGuideRelatedVerses),
              icon: Icons.menu_book,
              content: paragraphs(s.relatedVerses)),
          _SectionSpec(
              index: 5,
              title: context.tr(TranslationKeys.studyGuideDiscussionQuestions),
              icon: Icons.quiz,
              content: numbered(s.reflectionQuestions)),
          _SectionSpec(
              index: 6,
              title: context.tr(TranslationKeys.studyGuidePrayerPoints),
              icon: Icons.favorite,
              content: prayer(s.prayerPoints)),
        ],
      StudyMode.sermon => [
          _SectionSpec(
              index: 0,
              title: context.tr(TranslationKeys.sermonThesis),
              icon: Icons.lightbulb_outline,
              content: s.summary),
          _SectionSpec(
              index: 1,
              title: context.tr(TranslationKeys.sermonContext),
              icon: Icons.history_edu,
              content: s.context),
          passage,
          _SectionSpec(
              index: 3,
              title: context.tr(TranslationKeys.sermonBody),
              icon: Icons.menu_book,
              content: s.interpretation),
          _SectionSpec(
              index: 4,
              title: context.tr(TranslationKeys.sermonSupportingVerses),
              icon: Icons.bookmark_border,
              content: paragraphs(s.relatedVerses)),
          _SectionSpec(
              index: 5,
              title: context.tr(TranslationKeys.sermonDiscussionQuestions),
              icon: Icons.question_answer,
              content: numbered(s.reflectionQuestions)),
          _SectionSpec(
              index: 6,
              title: context.tr(TranslationKeys.sermonAltarCall),
              icon: Icons.volunteer_activism,
              content: paragraphs(s.prayerPoints),
              isAltarCall: true),
        ],
      StudyMode.quick => [
          _SectionSpec(
              index: 0,
              title: context.tr(TranslationKeys.studyGuideKeyInsight),
              icon: Icons.lightbulb_outline,
              content: s.summary,
              isHighlight: true),
          _SectionSpec(
              index: 1,
              title: context.tr(TranslationKeys.studyGuideContext),
              icon: Icons.history_edu_outlined,
              content: s.context),
          passage,
          _SectionSpec(
              index: 3,
              title: context.tr(TranslationKeys.studyGuideKeyVerse),
              icon: Icons.auto_stories_outlined,
              content: s.interpretation),
          _SectionSpec(
              index: 4,
              title: context.tr(TranslationKeys.studyGuideRelatedVerses),
              icon: Icons.format_list_bulleted,
              content: paragraphs(s.relatedVerses)),
          _SectionSpec(
              index: 5,
              title: context.tr(TranslationKeys.studyGuideDiscussionQuestions),
              icon: Icons.forum_outlined,
              content: numbered(s.reflectionQuestions)),
          _SectionSpec(
              index: 6,
              title: context.tr(TranslationKeys.studyGuidePrayerPoints),
              icon: Icons.volunteer_activism_outlined,
              content: prayer(s.prayerPoints)),
        ],
      StudyMode.deep => [
          _SectionSpec(
              index: 0,
              title:
                  context.tr(TranslationKeys.studyGuideComprehensiveOverview),
              icon: Icons.summarize,
              content: s.summary),
          _SectionSpec(
              index: 1,
              title: context.tr(TranslationKeys.studyGuideHistoricalContext),
              icon: Icons.history_edu,
              content: s.context),
          passage,
          _SectionSpec(
              index: 3,
              title:
                  context.tr(TranslationKeys.studyGuideInDepthInterpretation),
              icon: Icons.lightbulb_outline,
              content: s.interpretation),
          _SectionSpec(
              index: 4,
              title: context.tr(TranslationKeys.studyGuideScriptureConnections),
              icon: Icons.menu_book,
              content: paragraphs(s.relatedVerses)),
          _SectionSpec(
              index: 5,
              title: context.tr(TranslationKeys.studyGuideDeepReflection),
              icon: Icons.edit_note,
              content: numbered(s.reflectionQuestions)),
          _SectionSpec(
              index: 6,
              title: context.tr(TranslationKeys.studyGuidePrayerForApplication),
              icon: Icons.favorite,
              content: prayer(s.prayerPoints)),
        ],
      StudyMode.lectio => [
          _SectionSpec(
              index: 0,
              title: context.tr(TranslationKeys.lectioScriptureForMeditation),
              icon: Icons.menu_book,
              content: s.summary),
          _SectionSpec(
              index: 1,
              title: context.tr(TranslationKeys.lectioAboutPracticeEmoji),
              icon: Icons.info_outline,
              content: s.context),
          passage,
          _SectionSpec(
              index: 3,
              title: context.tr(TranslationKeys.lectioLectioMeditatio),
              subtitle: context.tr(TranslationKeys.lectioReadMeditate),
              icon: Icons.auto_stories,
              content: s.interpretation),
          _SectionSpec(
              index: 4,
              title: context.tr(TranslationKeys.lectioFocusWordsEmoji),
              icon: Icons.highlight,
              content: bulleted(s.relatedVerses)),
          _SectionSpec(
              index: 5,
              title: context.tr(TranslationKeys.lectioOratioContemplatio),
              subtitle: context.tr(TranslationKeys.lectioPrayRest),
              icon: Icons.self_improvement,
              content: numbered(s.reflectionQuestions)),
          _SectionSpec(
              index: 6,
              title: context.tr(TranslationKeys.lectioClosingBlessingEmoji),
              icon: Icons.wb_sunny_outlined,
              content: paragraphs(s.prayerPoints)),
        ],
    };
  }
}

class _SectionSpec {
  final int index;
  final String title;
  final String? subtitle;
  final IconData icon;
  final String? content;

  /// Never shimmers: the generator does not always produce it.
  final bool optional;
  final bool isHighlight;
  final bool isAltarCall;

  const _SectionSpec({
    required this.index,
    required this.title,
    required this.icon,
    required this.content,
    this.subtitle,
    this.optional = false,
    this.isHighlight = false,
    this.isAltarCall = false,
  });
}

/// Removes a duplicate section title from the start of section content.
String cleanDuplicateSectionTitle(String content, String title) {
  final lines = content.split('\n');
  if (lines.isEmpty) return content;

  final normalizedTitle =
      title.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
  final firstLine =
      lines.first.toLowerCase().replaceAll(RegExp(r'[*_#]'), '').trim();

  if (firstLine.contains(normalizedTitle) ||
      normalizedTitle.contains(firstLine)) {
    final cleaned =
        lines.skip(1).skipWhile((line) => line.trim().isEmpty).join('\n');
    // If the "title" was the whole content, keep the original.
    return cleaned.trim().isEmpty ? content : cleaned;
  }
  return content;
}

/// Title card at the top of a study guide: the input mode and the topic or
/// passage.
class StudyGuideTopicTitle extends StatelessWidget {
  final String inputType;
  final String title;

  const StudyGuideTopicTitle({
    super.key,
    required this.inputType,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = theme.colorScheme.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accentColor.withOpacity(0.1),
            theme.colorScheme.secondary.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withOpacity(0.2)),
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
              color: accentColor,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: AppFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pill showing a study mode and its reading time.
class StudyModeBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const StudyModeBadge({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final accentColor = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: accentColor),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: AppFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: accentColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sermon mode's badge.
class SermonBadge extends StatelessWidget {
  const SermonBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('⛪', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          // Flexible: the duration label wraps instead of overflowing a
          // narrow phone in the longer languages.
          Flexible(
            child: Text(
              context.tr(TranslationKeys.sermonDuration),
              style: AppFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Box geometry per [StudySectionStyle], shared by the card and its shimmer so
/// a section does not change size when its content arrives.
class _SectionGeometry {
  final EdgeInsets padding;
  final double radius;
  final double iconBox;
  final double iconSize;
  final double iconRadius;
  final double headerGap;

  const _SectionGeometry({
    required this.padding,
    required this.radius,
    required this.iconBox,
    required this.iconSize,
    required this.iconRadius,
    required this.headerGap,
  });

  static _SectionGeometry of(StudySectionStyle style) => switch (style) {
        // Tighter on the sides than top and bottom: horizontal space is what
        // the text needs, vertical space separates one section from the next.
        StudySectionStyle.standard => const _SectionGeometry(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            radius: 16,
            iconBox: 40,
            iconSize: 20,
            iconRadius: 10,
            headerGap: 16),
        StudySectionStyle.quick => const _SectionGeometry(
            padding: EdgeInsets.all(16),
            radius: 12,
            iconBox: 40,
            iconSize: 22,
            iconRadius: 10,
            headerGap: 10),
        StudySectionStyle.lectio => const _SectionGeometry(
            padding: EdgeInsets.all(20),
            radius: 16,
            iconBox: 36,
            iconSize: 18,
            iconRadius: 8,
            headerGap: 16),
      };
}

BoxDecoration _sectionDecoration(
  BuildContext context,
  StudySectionStyle style, {
  bool isBeingRead = false,
}) {
  final theme = Theme.of(context);
  final accent = theme.colorScheme.primary;
  final isDark = theme.brightness == Brightness.dark;
  final radius = BorderRadius.circular(_SectionGeometry.of(style).radius);

  return switch (style) {
    StudySectionStyle.standard => BoxDecoration(
        color:
            isBeingRead ? accent.withOpacity(0.08) : theme.colorScheme.surface,
        borderRadius: radius,
        border: Border.all(
          color:
              isBeingRead ? accent.withOpacity(0.5) : accent.withOpacity(0.1),
          width: isBeingRead ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isBeingRead
                ? accent.withOpacity(0.15)
                : accent.withOpacity(0.05),
            blurRadius: isBeingRead ? 16 : 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    StudySectionStyle.quick => BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: radius,
        border: Border.all(color: accent.withOpacity(0.1)),
      ),
    StudySectionStyle.lectio => BoxDecoration(
        color: accent.withOpacity(isDark ? 0.08 : 0.04),
        borderRadius: radius,
        border: Border.all(color: accent.withOpacity(isDark ? 0.2 : 0.15)),
      ),
  };
}

void _copySection(BuildContext context, String text) {
  Clipboard.setData(ClipboardData(text: text));
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        context.tr(TranslationKeys.studyGuideCopiedToClipboard),
        style: AppFonts.inter(color: Colors.white),
      ),
      backgroundColor: context.appInteractive,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ),
  );
}

/// Fades and slides a section in the first time it appears in the stream.
class _Appear extends StatefulWidget {
  final bool animate;
  final Widget child;

  const _Appear({required this.animate, required this.child});

  @override
  State<_Appear> createState() => _AppearState();
}

class _AppearState extends State<_Appear> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 400),
    vsync: this,
    value: widget.animate ? 0.0 : 1.0,
  );
  late final Animation<double> _fade =
      CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.1),
    end: Offset.zero,
  ).animate(_fade);

  @override
  void initState() {
    super.initState();
    if (widget.animate) _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _fade,
        child: SlideTransition(position: _slide, child: widget.child),
      );
}

/// A study guide section: icon, title, copy button and markdown content with
/// tappable scripture references.
class StudySectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final String content;
  final StudySectionStyle style;
  final bool isHighlight;
  final bool isBeingRead;
  final bool isNew;
  final double contentFontSize;

  const StudySectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.content,
    this.subtitle,
    this.style = StudySectionStyle.standard,
    this.isHighlight = false,
    this.isBeingRead = false,
    this.isNew = false,
    this.contentFontSize = 18.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final geometry = _SectionGeometry.of(style);

    return _Appear(
      animate: isNew,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: geometry.padding,
        decoration:
            _sectionDecoration(context, style, isBeingRead: isBeingRead),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: geometry.iconBox,
                  height: geometry.iconBox,
                  decoration: BoxDecoration(
                    color: isBeingRead
                        ? accent
                        : accent.withOpacity(
                            style == StudySectionStyle.standard ? 0.1 : 0.15),
                    borderRadius: BorderRadius.circular(geometry.iconRadius),
                  ),
                  child: isBeingRead
                      ? _PulsingIcon(
                          icon: Icons.volume_up, size: geometry.iconSize)
                      : Icon(icon, color: accent, size: geometry.iconSize),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: AppFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: accent.withOpacity(0.8),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isBeingRead) const _ReadingChip(),
                IconButton(
                  onPressed: () => _copySection(context, content),
                  icon: Icon(
                    Icons.copy,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                    size: 18,
                  ),
                  constraints:
                      const BoxConstraints(minWidth: 44, minHeight: 44),
                  padding: const EdgeInsets.all(8),
                  tooltip: 'Copy $title',
                ),
              ],
            ),
            SizedBox(height: geometry.headerGap),
            if (style == StudySectionStyle.lectio) ...[
              Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    accent.withOpacity(0.0),
                    accent.withOpacity(0.2),
                    accent.withOpacity(0.0),
                  ]),
                ),
              ),
              const SizedBox(height: 16),
            ],
            MarkdownWithScripture(
              data: cleanDuplicateSectionTitle(content, title),
              textStyle: AppFonts.inter(
                fontSize: contentFontSize,
                fontWeight: isHighlight ? FontWeight.w500 : FontWeight.w400,
                height: style == StudySectionStyle.lectio ? 1.7 : 1.6,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadingChip extends StatelessWidget {
  const _ReadingChip();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.graphic_eq, color: Colors.white, size: 14),
            const SizedBox(width: 4),
            Text(
              'Reading',
              style: AppFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      );
}

/// Placeholder for a section still streaming. Same box as [StudySectionCard]
/// in the same style, so the page does not jump when the content lands.
class StudySectionShimmer extends StatelessWidget {
  final String title;
  final IconData icon;
  final StudySectionStyle style;

  const StudySectionShimmer({
    super.key,
    required this.title,
    required this.icon,
    this.style = StudySectionStyle.standard,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;
    final geometry = _SectionGeometry.of(style);

    Widget line(double width) => Container(
          width: width,
          height: 16,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
          ),
        );

    return Container(
      padding: geometry.padding,
      decoration: _sectionDecoration(context, style),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: geometry.iconBox,
                height: geometry.iconBox,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(geometry.iconRadius),
                ),
                child: Icon(icon,
                    color: accent.withOpacity(0.5), size: geometry.iconSize),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: AppFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: geometry.headerGap),
          Shimmer.fromColors(
            baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
            highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                line(double.infinity),
                const SizedBox(height: 8),
                line(double.infinity),
                const SizedBox(height: 8),
                line(200),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Sermon mode's closing altar call, set apart from the other sections.
class AltarCallCard extends StatelessWidget {
  final String content;
  final double contentFontSize;
  final bool isNew;

  const AltarCallCard({
    super.key,
    required this.content,
    this.contentFontSize = 18.0,
    this.isNew = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final title = context.tr(TranslationKeys.sermonAltarCall);

    return _Appear(
      animate: isNew,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primaryContainer,
              theme.colorScheme.secondaryContainer,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: accent.withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child:
                      Icon(Icons.volunteer_activism, color: accent, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: AppFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _copySection(context, content),
                  icon: Icon(Icons.copy, color: accent, size: 20),
                  constraints:
                      const BoxConstraints(minWidth: 44, minHeight: 44),
                  padding: const EdgeInsets.all(8),
                  tooltip: 'Copy $title',
                ),
              ],
            ),
            const SizedBox(height: 16),
            MarkdownWithScripture(
              data: content,
              textStyle: AppFonts.inter(
                fontSize: contentFontSize,
                height: 1.6,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Icon that pulses while text-to-speech reads its section.
class _PulsingIcon extends StatefulWidget {
  final IconData icon;
  final double size;

  const _PulsingIcon({required this.icon, required this.size});

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 1000),
    vsync: this,
  )..repeat(reverse: true);
  late final Animation<double> _opacity = Tween<double>(begin: 0.6, end: 1.0)
      .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _opacity,
        child: Icon(widget.icon, color: Colors.white, size: widget.size),
      );
}
