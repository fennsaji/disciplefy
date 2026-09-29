import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/discipler_badges.dart';
import 'package:disciplefy_bible_study/shared/widgets/welcome_chrome.dart';

/// App-preview mock-ups shown at the top of each onboarding slide.
///
/// Built from widgets (not screenshots) at a fixed design width of
/// [onboardingPreviewWidth]; the slide scales them down with a `FittedBox`
/// to fit narrow or short screens. Their text is illustrative sample content.
const double onboardingPreviewWidth = 320;

/// Colours shared by the preview cards.
class _PreviewTokens {
  final ReaderPalette palette;
  final Color cardFill;
  final Color cardBorder;
  final Color chipFill;
  final List<BoxShadow> shadow;

  _PreviewTokens._(
    this.palette,
    this.cardFill,
    this.cardBorder,
    this.chipFill,
    this.shadow,
  );

  factory _PreviewTokens.of(BuildContext context) {
    final palette = ReaderPalette.of(context);
    if (palette.isDark) {
      return _PreviewTokens._(
        palette,
        const Color(0xFF1E1E25),
        Colors.white.withValues(alpha: 0.08),
        const Color(0xFF2A2A33),
        const [],
      );
    }
    return _PreviewTokens._(
      palette,
      Colors.white,
      palette.hairline,
      palette.raised,
      [
        BoxShadow(
          color: AppColors.brandPrimary.withValues(alpha: 0.08),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  BoxDecoration card({double radius = 22}) => BoxDecoration(
        color: cardFill,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: cardBorder),
        boxShadow: shadow,
      );
}

TextStyle _metaStyle(Color gold) => AppFonts.poppins(
      fontSize: 10.5,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.6,
      color: gold,
    );

/// Numbered section row ("01  Summary") with an optional body line.
class _NumberedSection extends StatelessWidget {
  final String number;
  final String title;
  final String? body;

  const _NumberedSection({
    required this.number,
    required this.title,
    this.body,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              number,
              style: AppFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: palette.gold,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: palette.text,
                ),
              ),
            ),
          ],
        ),
        if (body != null) ...[
          const SizedBox(height: 6),
          Text(
            body!,
            style: AppFonts.inter(
              fontSize: 12,
              height: 1.45,
              color: palette.muted,
            ),
          ),
        ],
      ],
    );
  }
}

/// Slide 1: a study card tilted behind a "Verse of the day" photo card.
class DailyVersePreview extends StatelessWidget {
  const DailyVersePreview({super.key});

  static const double _height = 350;

  @override
  Widget build(BuildContext context) {
    final tokens = _PreviewTokens.of(context);
    final palette = tokens.palette;

    final studyCard = Container(
      width: 272,
      height: 190,
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 0),
      decoration: tokens.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context
                .tr(TranslationKeys.onboardingPreviewTopicMeta)
                .toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _metaStyle(palette.gold),
          ),
          const SizedBox(height: 10),
          Text(
            context.tr(TranslationKeys.onboardingPreviewTopic),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: palette.text,
            ),
          ),
          const SizedBox(height: 10),
          _NumberedSection(
            number: '01',
            title: context.tr(TranslationKeys.onboardingPreviewSummary),
          ),
          const SizedBox(height: 10),
          _NumberedSection(
            number: '02',
            title: context.tr(TranslationKeys.onboardingPreviewContext),
          ),
        ],
      ),
    );

    const photoHeight = 172.0;
    final photoCard = Container(
      width: 292,
      clipBehavior: Clip.antiAlias,
      decoration: tokens.card(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: photoHeight,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  WelcomePhotos.wheatDawn,
                  fit: BoxFit.cover,
                  cacheWidth: welcomePhotoCacheWidth(context, 292, photoHeight),
                  errorBuilder: (_, __, ___) =>
                      const ColoredBox(color: Color(0xFF3A3326)),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0),
                        Colors.black.withValues(alpha: 0.62),
                      ],
                      stops: const [0.25, 1],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context
                            .tr(TranslationKeys.onboardingPreviewVerseOfDay)
                            .toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _metaStyle(AppColors.brandGold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.tr(TranslationKeys.onboardingSlide1Verse),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Psalm 119:105',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.inter(fontSize: 12, color: palette.muted),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: palette.ctaFill,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      context.tr(TranslationKeys.onboardingPreviewStudyNow),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: palette.ctaInk,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return SizedBox(
      width: onboardingPreviewWidth,
      height: _height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 14,
            right: 4,
            child: Transform.rotate(angle: -0.07, child: studyCard),
          ),
          Positioned(
            top: 108,
            left: 4,
            child: Transform.rotate(angle: 0.05, child: photoCard),
          ),
        ],
      ),
    );
  }
}

/// Slide 2: a study guide card with progress and numbered sections.
class StudyGuidePreview extends StatelessWidget {
  const StudyGuidePreview({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = _PreviewTokens.of(context);
    final palette = tokens.palette;
    final divider = Divider(height: 28, thickness: 1, color: palette.hairline);

    return Container(
      width: 300,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      decoration: tokens.card(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context
                .tr(TranslationKeys.onboardingPreviewScriptureMeta)
                .toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _metaStyle(palette.gold),
          ),
          const SizedBox(height: 10),
          Text(
            'Romans 8:28',
            style: AppFonts.poppins(
              fontSize: 21,
              fontWeight: FontWeight.w600,
              color: palette.text,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < 7; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: i < 3 ? palette.gold : tokens.chipFill,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          divider,
          _NumberedSection(
            number: '01',
            title: context.tr(TranslationKeys.onboardingPreviewSummary),
            body: context.tr(TranslationKeys.onboardingPreviewSummaryBody),
          ),
          divider,
          _NumberedSection(
            number: '02',
            title: context.tr(TranslationKeys.onboardingPreviewContext),
            body: context.tr(TranslationKeys.onboardingPreviewContextBody),
          ),
          divider,
          _NumberedSection(
            number: '03',
            title: context.tr(TranslationKeys.onboardingPreviewInterpretation),
          ),
        ],
      ),
    );
  }
}

/// Slide 3: a Discipler voice chat card.
class DisciplerChatPreview extends StatelessWidget {
  const DisciplerChatPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = _PreviewTokens.of(context);
    final palette = tokens.palette;
    // User bubble: white on dark, indigo on light.
    final userFill = palette.isDark ? Colors.white : AppColors.brandPrimary;
    final userInk = palette.isDark ? AppColors.brandPrimaryInk : Colors.white;

    return Container(
      width: 320,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: tokens.card(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const DisciplerAvatar(radius: 15),
              const SizedBox(width: 10),
              Text(
                'Discipler',
                style: AppFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: palette.text,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '· ${context.tr(TranslationKeys.onboardingPreviewListening)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.inter(fontSize: 12, color: palette.gold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 250),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: userFill,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  context.tr(TranslationKeys.onboardingPreviewQuestion),
                  style: AppFonts.inter(fontSize: 12.5, color: userInk),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: palette.isDark ? tokens.chipFill : palette.raised,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              context.tr(TranslationKeys.onboardingPreviewAnswer),
              style: AppFonts.inter(
                fontSize: 12.5,
                height: 1.45,
                color: palette.text.withValues(alpha: 0.88),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: Container(
              width: 54,
              height: 54,
              decoration: const BoxDecoration(
                color: AppColors.brandPrimary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mic_none_rounded, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

/// Slide 4: a memory-verse review card with blanks and grading buttons.
class MemoryReviewPreview extends StatelessWidget {
  const MemoryReviewPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = _PreviewTokens.of(context);
    final palette = tokens.palette;
    final verseStyle =
        AppFonts.inter(fontSize: 13.5, height: 1.6, color: palette.text);

    Widget grade(String label, {bool primary = false}) => Expanded(
          child: Container(
            height: 38,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: primary ? AppColors.brandPrimary : tokens.chipFill,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: primary ? Colors.white : palette.text,
              ),
            ),
          ),
        );

    return Container(
      width: 300,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: tokens.card(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context
                      .tr(TranslationKeys.onboardingPreviewReviewMeta)
                      .toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _metaStyle(palette.gold),
                ),
              ),
              Icon(Icons.psychology_outlined,
                  size: 18, color: palette.accentIcon),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Psalm 119:11',
            style: AppFonts.poppins(
              fontSize: 19,
              fontWeight: FontWeight.w600,
              color: palette.text,
            ),
          ),
          const SizedBox(height: 10),
          Text.rich(
            TextSpan(
              style: verseStyle,
              children: [
                TextSpan(
                  text:
                      '${context.tr(TranslationKeys.onboardingPreviewBlankStart)} ',
                ),
                TextSpan(
                  text: '____ ____ ____ ____ ',
                  style: verseStyle.copyWith(color: palette.muted),
                ),
                TextSpan(
                  text: context.tr(TranslationKeys.onboardingPreviewBlankEnd),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              grade(context.tr(TranslationKeys.onboardingPreviewAgain)),
              const SizedBox(width: 8),
              grade(context.tr(TranslationKeys.onboardingPreviewGood)),
              const SizedBox(width: 8),
              grade(
                context.tr(TranslationKeys.onboardingPreviewEasy),
                primary: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
