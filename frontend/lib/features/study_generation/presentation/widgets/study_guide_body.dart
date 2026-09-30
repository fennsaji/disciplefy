import 'dart:math' as math;

import 'package:disciplefy_bible_study/core/constants/hero_images.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_guide.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_mode.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_stream_event.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/widgets/study_reading_tracker.dart';
import 'package:disciplefy_bible_study/shared/widgets/markdown_with_scripture.dart';
import 'package:disciplefy_bible_study/shared/widgets/numbered_section_header.dart';
import '../../../../shared/widgets/app_snackbar.dart';

/// Layout values shared by the streaming (loading) and the finished study
/// guide views. Both render the full-bleed [StudyGuideBody], which pads its
/// sections with [sidePadding], so the page does not shift when the stream
/// completes and the finished view takes over.
class StudyGuideLayout {
  StudyGuideLayout._();

  /// Sections are hairline-separated text, not inset cards, so this is the
  /// whole margin between the screen edge and a word. 20 keeps Devanagari and
  /// Malayalam from breaking mid-word on a 320pt phone.
  static const EdgeInsets sidePadding = EdgeInsets.symmetric(horizontal: 20);

  /// Height of the floating top bar (back, title, menu) drawn over the hero.
  static const double topBarHeight = 56;

  static bool isLargeScreen(BuildContext context) =>
      MediaQuery.of(context).size.height > 700;

  /// Space between the end-of-guide blocks.
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

/// Photo hero (eyebrow, title, segmented progress) and every numbered section
/// of a study guide, for all modes.
///
/// Used by both the streaming view and the finished view so the two cannot
/// drift apart. Full-bleed: the hero spans the width and the sections apply
/// [StudyGuideLayout.sidePadding] themselves, so callers add no padding.
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

  /// Drives the header's segmented progress. Without one the segments stay
  /// empty.
  final StudyReadingTracker? tracker;

  const StudyGuideBody({
    super.key,
    required this.studyMode,
    required this.sections,
    required this.inputType,
    required this.title,
    this.contentFontSize = 18.0,
    this.readingSectionIndex,
    this.interpretationKey,
    this.tracker,
  });

  /// How many numbered sections [StudyGuideBody] renders for [sections] —
  /// the count the end-of-guide blocks continue numbering from.
  static int visibleSectionCount(
    BuildContext context, {
    required StudyMode studyMode,
    required StudyGuideSections sections,
  }) =>
      _specsFor(context, studyMode, sections)
          .where((spec) => _isVisible(spec, sections))
          .length;

  static bool _isVisible(_SectionSpec spec, StudyGuideSections sections) {
    final text = spec.content;
    if (text != null && text.isNotEmpty) return true;
    return !spec.optional && sections.isLoading(spec.index);
  }

  @override
  Widget build(BuildContext context) {
    final sectionWidgets = _buildSections(context);
    tracker?.total = sectionWidgets.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StudyGuideHero(
          inputType: inputType,
          title: title,
          studyMode: studyMode,
          sectionCount: sectionWidgets.length,
          tracker: tracker,
        ),
        Padding(
          padding: StudyGuideLayout.sidePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: sectionWidgets,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildSections(BuildContext context) {
    final specs = _specsFor(context, studyMode, sections);
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
      if (!_isVisible(spec, sections)) continue;
      final number = children.length + 1;
      final text = spec.content;
      Widget child;
      if (text == null || text.isEmpty) {
        child = StudySectionShimmer(
            title: spec.title, icon: spec.icon, style: style, number: number);
      } else if (spec.isAltarCall) {
        child = AltarCallCard(
          content: text,
          contentFontSize: contentFontSize,
          isNew: sections.isNew(spec.index),
          number: number,
        );
      } else {
        child = StudySectionCard(
          title: spec.title,
          subtitle: spec.subtitle,
          icon: spec.icon,
          content: text,
          style: style,
          number: number,
          isHighlight: spec.isHighlight,
          isBeingRead: tracksReading && readingSectionIndex == spec.index,
          isNew: sections.isNew(spec.index),
          contentFontSize: contentFontSize,
        );
      }
      if (spec.index == 3 && interpretationKey != null) {
        child = KeyedSubtree(key: interpretationKey, child: child);
      }
      if (tracker != null) {
        child = KeyedSubtree(key: tracker!.keyFor(spec.index), child: child);
      }
      children.add(child);
    }
    return children;
  }

  static List<_SectionSpec> _specsFor(
    BuildContext context,
    StudyMode studyMode,
    StudyGuideSections s,
  ) {
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

/// Hero photo at the top of a study guide: eyebrow ("TOPIC · STANDARD STUDY
/// · 8 MIN"), the large title and one progress segment per section.
///
/// The photo fades into the page at its bottom. Leaves room at the top for the
/// floating back/menu bar the screen draws over it.
class StudyGuideHero extends StatelessWidget {
  /// Photo for this guide: tied to its title, so the header and the
  /// guide's library card always show the same scenery.
  String get photoAsset => heroImageForKey(title);

  final String inputType;
  final String title;
  final StudyMode studyMode;
  final int sectionCount;
  final StudyReadingTracker? tracker;

  const StudyGuideHero({
    super.key,
    required this.inputType,
    required this.title,
    required this.studyMode,
    required this.sectionCount,
    this.tracker,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final topInset =
        MediaQuery.paddingOf(context).top + StudyGuideLayout.topBarHeight;
    final page = palette.page;

    // Dark: the photo darkens into the black page. Light: a pale wash keeps
    // dark ink readable over the sky, then fades into the light page.
    final fade = palette.isDark
        ? LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.35),
              Colors.black.withValues(alpha: 0.05),
              page.withValues(alpha: 0.7),
              page,
            ],
            stops: const [0, 0.35, 0.72, 1],
          )
        : LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              page.withValues(alpha: 0.1),
              page.withValues(alpha: 0.3),
              page.withValues(alpha: 0.88),
              page,
            ],
            stops: const [0, 0.4, 0.72, 1],
          );

    return Stack(
      children: [
        Positioned.fill(
          child: ExcludeSemantics(
            child: Image.asset(
              photoAsset,
              fit: BoxFit.cover,
              alignment: const Alignment(0, -0.3),
              // Decode at the screen's pixel width (sharp on 3x phones),
              // never above the 2000px source.
              cacheWidth: math.min(
                  2000,
                  (MediaQuery.sizeOf(context).width *
                          MediaQuery.devicePixelRatioOf(context))
                      .round()),
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(decoration: BoxDecoration(gradient: fade)),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            StudyGuideLayout.sidePadding.left,
            topInset + 52,
            StudyGuideLayout.sidePadding.right,
            4,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StudyGuideTopicTitle(
                inputType: inputType,
                title: title,
                studyMode: studyMode,
              ),
              const SizedBox(height: 16),
              StudyGuideSegmentedProgress(
                sectionCount: sectionCount,
                tracker: tracker,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Gold eyebrow and the large Poppins title of a study guide.
class StudyGuideTopicTitle extends StatelessWidget {
  final String inputType;
  final String title;
  final StudyMode? studyMode;

  const StudyGuideTopicTitle({
    super.key,
    required this.inputType,
    required this.title,
    this.studyMode,
  });

  /// "TOPIC · STANDARD STUDY · 8 MIN", localised.
  static String eyebrow(
    BuildContext context, {
    required String inputType,
    StudyMode? studyMode,
  }) {
    final type = switch (inputType) {
      'scripture' => context.tr('generate_study.scripture_mode'),
      'question' => context.tr('generate_study.question_mode'),
      _ => context.tr('generate_study.topic_mode'),
    };
    final parts = <String>[type];
    if (studyMode != null) {
      parts.add(context.tr(switch (studyMode) {
        StudyMode.quick => TranslationKeys.studyModeQuickName,
        StudyMode.standard => TranslationKeys.studyModeStandardName,
        StudyMode.deep => TranslationKeys.studyModeDeepName,
        StudyMode.lectio => TranslationKeys.studyModeLectioName,
        StudyMode.sermon => TranslationKeys.studyModeSermonName,
      }));
      final minutes = studyMode == StudyMode.sermon
          ? '50-60'
          : '${studyMode.durationMinutes}';
      parts.add('$minutes ${context.tr('gamification.minutes')}');
    }
    return parts.join(' · ').toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    // Long questions and passage ranges step down so they stay within a few
    // lines on a narrow phone.
    final titleSize = title.length > 60
        ? 24.0
        : title.length > 28
            ? 28.0
            : 34.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow(context, inputType: inputType, studyMode: studyMode),
          style: AppFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: palette.gold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Semantics(
          header: true,
          child: Text(
            title,
            style: AppFonts.poppins(
              fontSize: titleSize,
              fontWeight: FontWeight.w600,
              color: palette.isDark ? Colors.white : palette.text,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}

/// One gold segment per section; filled segments are sections read so far.
class StudyGuideSegmentedProgress extends StatelessWidget {
  final int sectionCount;
  final StudyReadingTracker? tracker;

  const StudyGuideSegmentedProgress({
    super.key,
    required this.sectionCount,
    this.tracker,
  });

  @override
  Widget build(BuildContext context) {
    if (sectionCount <= 0) return const SizedBox(height: 3);
    final palette = ReaderPalette.of(context);
    final empty = palette.isDark
        ? Colors.white.withValues(alpha: 0.18)
        : palette.text.withValues(alpha: 0.12);

    Widget bar(int filled) => ExcludeSemantics(
          child: Row(
            children: [
              for (var i = 0; i < sectionCount; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: i < filled ? palette.gold : empty,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );

    final t = tracker;
    if (t == null) return bar(0);
    return ListenableBuilder(
      listenable: t,
      builder: (_, __) => bar(math.min(t.readCount, sectionCount)),
    );
  }
}

/// Text style per [StudySectionStyle]. Sections share one layout; only the
/// reading rhythm differs.
double _lineHeightFor(StudySectionStyle style) =>
    style == StudySectionStyle.lectio ? 1.7 : 1.6;

/// Vertical rhythm shared by a section and its shimmer, so a section does not
/// change position when its content arrives.
const double _sectionTopGap = 22;
const double _sectionHeaderGap = 12;
const double _sectionBottomGap = 22;

void _copySection(BuildContext context, String text) {
  Clipboard.setData(ClipboardData(text: text));
  showAppSnackBar(
    context,
    context.tr(TranslationKeys.studyGuideCopiedToClipboard),
    tone: AppSnackTone.success,
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

/// Copy button shared by sections and the altar call.
class _CopyButton extends StatelessWidget {
  final String title;
  final String content;
  final Color color;

  const _CopyButton({
    required this.title,
    required this.content,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => IconButton(
        onPressed: () => _copySection(context, content),
        icon: Icon(Icons.copy_rounded, color: color, size: 18),
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        padding: const EdgeInsets.all(8),
        tooltip: 'Copy $title',
      );
}

/// A numbered study guide section: gold number, Poppins title, copy button
/// and markdown content with tappable scripture references, closed by a
/// hairline.
class StudySectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;

  /// Kept for callers; the numbered layout shows no section icon.
  final IconData icon;
  final String content;
  final StudySectionStyle style;

  /// 1-based position in the guide, shown as `01`.
  final int? number;
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
    this.number,
    this.isHighlight = false,
    this.isBeingRead = false,
    this.isNew = false,
    this.contentFontSize = 18.0,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);

    return _Appear(
      animate: isNew,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: _sectionTopGap),
          NumberedSectionHeader(
            number: number,
            title: title,
            titleColor: isBeingRead ? palette.accentIcon : null,
            leading: isBeingRead
                ? _PulsingIcon(
                    icon: Icons.volume_up_rounded,
                    size: 18,
                    color: palette.gold,
                  )
                : null,
            trailing: [
              if (isBeingRead) const _ReadingChip(),
              _CopyButton(title: title, content: content, color: palette.dim),
            ],
          ),
          if (subtitle != null)
            Padding(
              padding: EdgeInsets.only(left: number == null ? 0 : 30),
              child: Text(
                subtitle!,
                style: AppFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: palette.muted,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          const SizedBox(height: _sectionHeaderGap),
          MarkdownWithScripture(
            data: cleanDuplicateSectionTitle(content, title),
            textStyle: AppFonts.inter(
              fontSize: contentFontSize,
              fontWeight: isHighlight ? FontWeight.w500 : FontWeight.w400,
              height: _lineHeightFor(style),
              color: palette.text.withValues(alpha: 0.86),
            ),
          ),
          const SizedBox(height: _sectionBottomGap),
          const ReaderHairline(),
        ],
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
          color: ReaderPalette.selectedFill,
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

/// Placeholder for a section still streaming. Same header and rhythm as
/// [StudySectionCard], so the page does not jump when the content lands.
class StudySectionShimmer extends StatelessWidget {
  final String title;
  final IconData icon;
  final StudySectionStyle style;
  final int? number;

  const StudySectionShimmer({
    super.key,
    required this.title,
    required this.icon,
    this.style = StudySectionStyle.standard,
    this.number,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);

    Widget line(double widthFactor) => FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: widthFactor,
          child: Container(
            height: 12,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: _sectionTopGap),
        NumberedSectionHeader(
          number: number,
          title: title,
          // Same 44pt row as a finished section's copy button.
          trailing: const [SizedBox(width: 0, height: 44)],
        ),
        const SizedBox(height: _sectionHeaderGap + 6),
        Shimmer.fromColors(
          baseColor: palette.raised,
          highlightColor: palette.isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              line(1),
              const SizedBox(height: 8),
              line(0.87),
              const SizedBox(height: 8),
              line(0.6),
            ],
          ),
        ),
        const SizedBox(height: _sectionBottomGap),
        const ReaderHairline(),
      ],
    );
  }
}

/// Sermon mode's closing altar call, set apart from the other sections.
class AltarCallCard extends StatelessWidget {
  final String content;
  final double contentFontSize;
  final bool isNew;

  /// 1-based position in the guide, shown as `07`.
  final int? number;

  const AltarCallCard({
    super.key,
    required this.content,
    this.contentFontSize = 18.0,
    this.isNew = false,
    this.number,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final title = context.tr(TranslationKeys.sermonAltarCall);

    return _Appear(
      animate: isNew,
      child: Padding(
        padding: const EdgeInsets.only(
            top: _sectionTopGap, bottom: _sectionBottomGap),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 20),
          decoration: BoxDecoration(
            color: palette.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.gold.withValues(alpha: 0.45)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              NumberedSectionHeader(
                number: number,
                title: title,
                leading: number == null
                    ? Icon(Icons.volunteer_activism,
                        color: palette.gold, size: 20)
                    : null,
                trailing: [
                  _CopyButton(
                      title: title, content: content, color: palette.dim),
                ],
              ),
              const SizedBox(height: _sectionHeaderGap),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: MarkdownWithScripture(
                  data: content,
                  textStyle: AppFonts.inter(
                    fontSize: contentFontSize,
                    height: 1.6,
                    color: palette.text,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Icon that pulses while text-to-speech reads its section.
class _PulsingIcon extends StatefulWidget {
  final IconData icon;
  final double size;
  final Color color;

  const _PulsingIcon({
    required this.icon,
    required this.size,
    required this.color,
  });

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
        child: Icon(widget.icon, color: widget.color, size: widget.size),
      );
}
