import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/services/system_config_service.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/entities/memory_verse_entity.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/widgets/memory_ui/memory_ui.dart';

/// Flip card used by the flip card practice mode.
///
/// Front: gold "FRONT" label, the reference and a "recite, then flip" hint.
/// Back: the cited reference, the verse text (scrolls when long) and the
/// spaced-repetition stats. Tapping anywhere calls [onFlip]; the 3D flip is
/// a one-shot 500ms animation driven by [isFlipped].
class VerseFlipCard extends StatefulWidget {
  final MemoryVerseEntity verse;
  final bool isFlipped;
  final VoidCallback onFlip;

  const VerseFlipCard({
    super.key,
    required this.verse,
    required this.isFlipped,
    required this.onFlip,
  });

  @override
  State<VerseFlipCard> createState() => _VerseFlipCardState();
}

class _VerseFlipCardState extends State<VerseFlipCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
      value: widget.isFlipped ? 1 : 0,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void didUpdateWidget(VerseFlipCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFlipped != oldWidget.isFlipped) {
      if (widget.isFlipped) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      onTapHint: context.tr(TranslationKeys.memoryRecallFlipAction),
      child: GestureDetector(
        onTap: widget.onFlip,
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, _) {
            final angle = _animation.value * math.pi;
            final showFront = angle < math.pi / 2;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001) // perspective
                ..rotateY(angle),
              child: showFront
                  ? _CardFace(child: _FrontContent(verse: widget.verse))
                  : Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()..rotateY(math.pi),
                      child: _CardFace(
                        child: _BackContent(
                          verse: widget.verse,
                        ),
                      ),
                    ),
            );
          },
        ),
      ),
    );
  }
}

/// Gold-tinted card face filling the space the page gives the card.
class _CardFace extends StatelessWidget {
  final Widget child;

  const _CardFace({required this.child});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return SizedBox.expand(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            palette.gold.withValues(alpha: palette.isDark ? 0.16 : 0.06),
            palette.card,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: palette.gold.withValues(alpha: 0.35),
          ),
        ),
        child: child,
      ),
    );
  }
}

class _FrontContent extends StatelessWidget {
  final MemoryVerseEntity verse;

  const _FrontContent({required this.verse});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Column(
      children: [
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _FaceLabel(context.tr(TranslationKeys.memoryRecallFlipFront)),
                  const SizedBox(height: 14),
                  Text(
                    verse.verseReference,
                    textAlign: TextAlign.center,
                    style: AppFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: palette.text,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.tr(TranslationKeys.memoryRecallFlipReciteHint),
                    textAlign: TextAlign.center,
                    style: AppFonts.inter(fontSize: 14, color: palette.muted),
                  ),
                  const SizedBox(height: 14),
                  Icon(Icons.flip_camera_android_rounded,
                      size: 26, color: palette.accentIcon),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _MetaLine(
          text: [
            context
                .tr(TranslationKeys.flipCardReviewNumber)
                .replaceAll('{count}', '${verse.repetitions + 1}'),
            _languageLabel(verse.language),
          ].join(' · '),
        ),
      ],
    );
  }
}

class _BackContent extends StatelessWidget {
  final MemoryVerseEntity verse;
  const _BackContent({required this.verse});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    // Hide Bible verse text for daily_verse-sourced verses when the
    // bible_content_enabled kill-switch is off.
    final hideApiContent = verse.sourceType == 'daily_verse' &&
        !sl<SystemConfigService>().isBibleContentEnabled;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FaceLabel(context.tr(TranslationKeys.memoryRecallFlipBack)),
        const SizedBox(height: 10),
        // Reference only — no translation label beside a verse being recalled.
        Text(
          verse.verseReference,
          textAlign: TextAlign.center,
          style: AppFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: palette.accentIcon,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                hideApiContent
                    ? context.tr(TranslationKeys.verseSheetContentUnavailable)
                    : verse.verseText,
                textAlign: TextAlign.center,
                style: hideApiContent
                    ? AppFonts.inter(
                        fontSize: 16, height: 1.5, color: palette.muted)
                    : AppFonts.poppins(
                        fontSize: 21,
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                        color: palette.text,
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            MemoryTag(
              label: verse.intervalDays == 1
                  ? context.tr(TranslationKeys.flipCardDayOne)
                  : context
                      .tr(TranslationKeys.flipCardDays)
                      .replaceAll('{count}', '${verse.intervalDays}'),
            ),
            MemoryTag(
              label: verse.repetitions == 1
                  ? context.tr(TranslationKeys.flipCardReviewOne)
                  : context
                      .tr(TranslationKeys.flipCardReviews)
                      .replaceAll('{count}', '${verse.repetitions}'),
            ),
            MemoryTag(
              label: context.tr(TranslationKeys.memoryScreensEaseFactor,
                  {'value': verse.easeFactor.toStringAsFixed(1)}),
            ),
            MemoryTag(label: _languageLabel(verse.language)),
          ],
        ),
      ],
    );
  }
}

class _MetaLine extends StatelessWidget {
  final String text;

  const _MetaLine({required this.text});

  @override
  Widget build(BuildContext context) => Text(
        text,
        textAlign: TextAlign.center,
        style: AppFonts.inter(
          fontSize: 12.5,
          color: ReaderPalette.of(context).dim,
        ),
      );
}

String _languageLabel(String language) {
  switch (language) {
    case 'hi':
      return 'हिन्दी';
    case 'ml':
      return 'മലയാളം';
    default:
      return 'English';
  }
}

/// Gold, tracked, uppercase face label ("FRONT" / "BACK").
class _FaceLabel extends StatelessWidget {
  final String text;

  const _FaceLabel(this.text);

  @override
  Widget build(BuildContext context) => Semantics(
        header: true,
        child: Text(
          text.toUpperCase(),
          textAlign: TextAlign.center,
          style: AppFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
            color: ReaderPalette.of(context).gold,
          ),
        ),
      );
}
