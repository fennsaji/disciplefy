import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:showcaseview/showcaseview.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/core/router/app_router.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/core/widgets/auth_protected_screen.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/entities/memory_verse_entity.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/entities/practice_mode_entity.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/entities/practice_result_params.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/bloc/memory_verse_bloc.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/bloc/memory_verse_event.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/bloc/memory_verse_state.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/widgets/memory_ui/memory_ui.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/widgets/self_assessment_bottom_sheet.dart';
import 'package:disciplefy_bible_study/features/walkthrough/domain/walkthrough_repository.dart';
import 'package:disciplefy_bible_study/features/walkthrough/domain/walkthrough_screen.dart';
import 'package:disciplefy_bible_study/features/walkthrough/presentation/showcase_keys.dart';
import 'package:disciplefy_bible_study/features/walkthrough/presentation/walkthrough_tooltip.dart';

/// Progressive reveal practice mode for memory verses.
///
/// Reveals the verse word-by-word or phrase-by-phrase to help users
/// memorize in chunks using the chunking cognitive principle.
/// Users can control the reveal speed and choose between word or phrase mode.
class ProgressiveRevealPracticePage extends StatefulWidget {
  final String verseId;

  const ProgressiveRevealPracticePage({
    super.key,
    required this.verseId,
  });

  @override
  State<ProgressiveRevealPracticePage> createState() =>
      _ProgressiveRevealPracticePageState();
}

class _ProgressiveRevealPracticePageState
    extends State<ProgressiveRevealPracticePage> {
  MemoryVerseEntity? currentVerse;
  Timer? practiceTimer;
  Timer? revealTimer;
  int elapsedSeconds = 0;
  int currentRevealIndex = 0;
  bool isAutoRevealing = false;
  bool isCompleted = false;
  RevealMode revealMode = RevealMode.word;
  int revealSpeedSeconds = 2; // Seconds between auto-reveals

  List<String> chunks = [];

  BuildContext? _showcaseContext;
  VoidCallback get _onNext => () => ShowCaseWidget.of(_showcaseContext!).next();

  @override
  void initState() {
    super.initState();
    _startTimer();
    _loadVerse();
    _triggerWalkthroughIfNeeded();
  }

  Future<void> _triggerWalkthroughIfNeeded() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _showcaseContext == null) return;
      final repo = sl<WalkthroughRepository>();
      if (await repo.hasSeen(WalkthroughScreen.practiceProgressive)) return;
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted || _showcaseContext == null) return;
      ShowCaseWidget.of(_showcaseContext!).startShowCase([
        ShowcaseKeys.practiceProgressive,
        ShowcaseKeys.practiceProgressiveAutoReveal,
        ShowcaseKeys.practiceProgressiveRevealAll,
        ShowcaseKeys.practiceProgressiveSubmit,
      ]);
    });
  }

  @override
  void dispose() {
    practiceTimer?.cancel();
    revealTimer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    practiceTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => elapsedSeconds++);
    });
  }

  void _loadVerse() {
    final state = context.read<MemoryVerseBloc>().state;
    if (state is DueVersesLoaded) {
      final verse =
          state.verses.firstWhereOrNull((v) => v.id == widget.verseId);
      if (verse != null) {
        setState(() {
          currentVerse = verse;
          // Include reference at the end of verse text for memorization
          final fullText = '${verse.verseText} ${verse.verseReference}';
          _splitTextIntoChunks(fullText);
        });
      } else {
        context
            .read<MemoryVerseBloc>()
            .add(const LoadDueVerses(forceRefresh: true));
      }
    } else {
      context.read<MemoryVerseBloc>().add(const LoadDueVerses());
    }
  }

  /// Handle back navigation - go to practice mode selection when can't pop
  void _handleBackNavigation() {
    if (context.canPop()) {
      context.pop();
    } else {
      // Fallback to practice mode selection
      context.go('/memory-verses/practice/${widget.verseId}');
    }
  }

  void _splitTextIntoChunks(String text) {
    if (revealMode == RevealMode.word) {
      // Split by words (space-separated)
      chunks = text.split(' ');
    } else {
      // Split by phrases (punctuation or every 4-5 words)
      chunks = _splitIntoPhrases(text);
    }
  }

  List<String> _splitIntoPhrases(String text) {
    final phrases = <String>[];
    final words = text.split(' ');
    final buffer = StringBuffer();

    for (int i = 0; i < words.length; i++) {
      buffer.write(words[i]);

      // Split on punctuation or every 4-5 words
      final hasPunctuation = words[i].contains(RegExp(r'[.!?,;:]'));

      final wordCount = buffer.toString().split(' ').length;
      if (hasPunctuation || wordCount >= 5 || i == words.length - 1) {
        phrases.add(buffer.toString().trim());
        buffer.clear();
      } else {
        buffer.write(' ');
      }
    }

    return phrases;
  }

  void _revealNext() {
    if (currentRevealIndex < chunks.length - 1) {
      setState(() {
        currentRevealIndex++;
      });
      // Check if we've now revealed everything
      if (currentRevealIndex >= chunks.length - 1) {
        _completeReveal();
      }
    }
  }

  void _revealAll() {
    setState(() {
      currentRevealIndex = chunks.length - 1;
    });
    _completeReveal();
  }

  void _completeReveal() {
    setState(() {
      isCompleted = true;
      isAutoRevealing = false;
    });
    revealTimer?.cancel();
  }

  void _toggleAutoReveal() {
    setState(() {
      isAutoRevealing = !isAutoRevealing;
    });

    if (isAutoRevealing) {
      revealTimer = Timer.periodic(
        Duration(seconds: revealSpeedSeconds),
        (timer) {
          if (currentRevealIndex < chunks.length - 1) {
            _revealNext();
          } else {
            _completeReveal();
          }
        },
      );
    } else {
      revealTimer?.cancel();
    }
  }

  void _changeRevealMode(RevealMode newMode) {
    if (newMode == revealMode) return;

    setState(() {
      revealMode = newMode;
      currentRevealIndex = 0;
      isAutoRevealing = false;
    });
    revealTimer?.cancel();

    if (currentVerse != null) {
      // Include reference at the end of verse text for memorization
      final fullText =
          '${currentVerse!.verseText} ${currentVerse!.verseReference}';
      _splitTextIntoChunks(fullText);
    }
  }

  Future<void> _submitPractice() async {
    if (currentVerse == null) return;

    // Show self-assessment bottom sheet for passive mode
    final rating = await SelfAssessmentBottomSheet.show(context);

    // User cancelled
    if (rating == null || !mounted) return;

    // Stop the timer
    practiceTimer?.cancel();

    // Use self-assessment values
    final accuracy = rating.accuracyPercentage;
    final quality = rating.qualityRating;
    final confidence = rating.confidenceRating;
    const hintsUsed = 0;
    const showedAnswer = false;

    // Navigate to results page
    final params = PracticeResultParams(
      verseId: widget.verseId,
      verseReference: currentVerse!.verseReference,
      verseText: currentVerse!.verseText,
      practiceMode: 'progressive',
      timeSpentSeconds: elapsedSeconds,
      accuracyPercentage: accuracy,
      hintsUsed: hintsUsed,
      showedAnswer: showedAnswer,
      qualityRating: quality,
      confidenceRating: confidence,
    );

    GoRouter.of(context).goToPracticeResults(params);
  }

  @override
  Widget build(BuildContext context) {
    return ShowCaseWidget(
      onFinish: () => sl<WalkthroughRepository>()
          .markSeen(WalkthroughScreen.practiceProgressive),
      builder: (showcaseCtx) {
        _showcaseContext = showcaseCtx;
        final title = context.tr(TranslationKeys.practiceModeProgressive);

        if (currentVerse == null) {
          return BlocListener<MemoryVerseBloc, MemoryVerseState>(
            listener: (context, state) {
              if (state is DueVersesLoaded && currentVerse == null) {
                _loadVerse();
              }
            },
            child: MemoryPracticeScaffold(
              title: title,
              elapsedSeconds: elapsedSeconds,
              onClose: _handleBackNavigation,
              scrollable: false,
              body: const Center(child: CircularProgressIndicator()),
            ).withAuthProtection(),
          );
        }

        final l10n = AppLocalizations.of(context)!;
        final canRevealNext = currentRevealIndex < chunks.length - 1;

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            _handleBackNavigation();
          },
          child: MemoryPracticeScaffold(
            title: title,
            subtitle: '${currentVerse!.verseReference} · '
                '${context.tr(TranslationKeys.difficultyEasy)}',
            elapsedSeconds: elapsedSeconds,
            onClose: _handleBackNavigation,
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MemoryAnswerCard(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _RevealedChunks(
                        chunks: chunks,
                        revealedUpTo: currentRevealIndex,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        context.tr(
                          revealMode == RevealMode.word
                              ? TranslationKeys.memoryRecallProgressiveWords
                              : TranslationKeys.memoryRecallProgressivePhrases,
                          {
                            'current':
                                chunks.isEmpty ? 0 : currentRevealIndex + 1,
                            'total': chunks.length,
                          },
                        ),
                        style: AppFonts.inter(
                          fontSize: 13.5,
                          color: ReaderPalette.of(context).muted,
                          fontFeatures: kMemoryTabular,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                MemorySegmentedControl<RevealMode>(
                  segments: [
                    MemorySegment(
                      value: RevealMode.word,
                      label: context.tr(TranslationKeys.progressiveWordByWord),
                    ),
                    MemorySegment(
                      value: RevealMode.phrase,
                      label:
                          context.tr(TranslationKeys.progressivePhraseByPhrase),
                    ),
                  ],
                  selected: revealMode,
                  onChanged: _changeRevealMode,
                ),
              ],
            ),
            bottomBar: MemoryActionBar(
              secondary: [
                _WalkthroughPill(
                  walkthrough: (child) => WalkthroughTooltip(
                    showcaseKey: ShowcaseKeys.practiceProgressiveAutoReveal,
                    title: l10n.walkthroughPracticeProgressiveAutoRevealTitle,
                    description:
                        l10n.walkthroughPracticeProgressiveAutoRevealDesc,
                    screen: WalkthroughScreen.practiceProgressive,
                    stepNumber: 2,
                    totalSteps: 4,
                    onNext: _onNext,
                    highlightBorderRadius: 26,
                    child: child,
                  ),
                  label: context.tr(isAutoRevealing
                      ? TranslationKeys.memoryRecallProgressivePause
                      : TranslationKeys.memoryRecallProgressiveAuto),
                  icon: isAutoRevealing
                      ? Icons.pause_rounded
                      : Icons.play_arrow_outlined,
                  active: isAutoRevealing,
                  onPressed: !isCompleted ? _toggleAutoReveal : null,
                ),
                _WalkthroughPill(
                  walkthrough: (child) => WalkthroughTooltip(
                    showcaseKey: ShowcaseKeys.practiceProgressiveRevealAll,
                    title: l10n.walkthroughPracticeProgressiveRevealAllTitle,
                    description:
                        l10n.walkthroughPracticeProgressiveRevealAllDesc,
                    screen: WalkthroughScreen.practiceProgressive,
                    stepNumber: 3,
                    totalSteps: 4,
                    onNext: _onNext,
                    highlightBorderRadius: 26,
                    child: child,
                  ),
                  label: context.tr(TranslationKeys.memoryRecallProgressiveAll),
                  icon: Icons.visibility_outlined,
                  onPressed: !isCompleted ? _revealAll : null,
                ),
              ],
              // Steps 1 (reveal next) and 4 (submit) both point at the
              // primary pill: it reads "Reveal next" until the verse is fully
              // shown, then becomes "Submit".
              primary: WalkthroughTooltip(
                showcaseKey: ShowcaseKeys.practiceProgressive,
                title: l10n.walkthroughPracticeProgressiveTitle,
                description: l10n.walkthroughPracticeProgressiveDesc,
                screen: WalkthroughScreen.practiceProgressive,
                stepNumber: 1,
                totalSteps: 4,
                onNext: _onNext,
                highlightBorderRadius: 26,
                child: WalkthroughTooltip(
                  showcaseKey: ShowcaseKeys.practiceProgressiveSubmit,
                  title: l10n.walkthroughPracticeProgressiveSubmitTitle,
                  description: l10n.walkthroughPracticeProgressiveSubmitDesc,
                  screen: WalkthroughScreen.practiceProgressive,
                  stepNumber: 4,
                  totalSteps: 4,
                  onNext: _onNext,
                  highlightBorderRadius: 26,
                  child: SizedBox(
                    width: double.infinity,
                    child: isCompleted
                        ? MemoryPrimaryPill(
                            label: context.tr(TranslationKeys.practiceSubmit),
                            icon: Icons.check_rounded,
                            onPressed: _submitPractice,
                          )
                        : MemoryPrimaryPill(
                            label: context
                                .tr(TranslationKeys.progressiveRevealNext),
                            icon: Icons.keyboard_double_arrow_right_rounded,
                            onPressed: canRevealNext ? _revealNext : null,
                          ),
                  ),
                ),
              ),
            ),
          ),
        ).withAuthProtection();
      },
    );
  }
}

/// Verse chunks revealed so far as text, the rest as quiet placeholder bars
/// sized roughly like the hidden words so the verse keeps its shape.
class _RevealedChunks extends StatelessWidget {
  final List<String> chunks;
  final int revealedUpTo;

  const _RevealedChunks({required this.chunks, required this.revealedUpTo});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final revealedText = chunks.take(revealedUpTo + 1).join(' ');
    final hiddenCount = chunks.length - (revealedUpTo + 1);
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxBar = constraints.maxWidth;
        return Semantics(
          label: revealedText,
          excludeSemantics: true,
          child: Wrap(
            spacing: 10,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (var i = 0; i <= revealedUpTo && i < chunks.length; i++)
                Text(
                  chunks[i],
                  style: AppFonts.poppins(
                    fontSize: 21,
                    fontWeight: FontWeight.w500,
                    height: 1.45,
                    color: palette.text,
                  ),
                ),
              for (var i = 0; i < hiddenCount; i++)
                Container(
                  width: (chunks[revealedUpTo + 1 + i].characters.length * 11.0)
                      .clamp(28.0, maxBar),
                  height: 18,
                  decoration: BoxDecoration(
                    color: palette.raised,
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// [MemoryActionPill] that stays a walkthrough target, including when the action
/// bar collapses it to an icon-only circle on narrow screens.
class _WalkthroughPill extends MemoryActionPill {
  final Widget Function(Widget child) walkthrough;

  const _WalkthroughPill({
    required this.walkthrough,
    required super.label,
    required super.onPressed,
    super.icon,
    super.active,
    super.iconOnly,
  });

  @override
  MemoryActionPill withIconOnly(bool value) => _WalkthroughPill(
        walkthrough: walkthrough,
        label: label,
        onPressed: onPressed,
        icon: icon,
        active: active,
        iconOnly: value,
      );

  @override
  Widget build(BuildContext context) => walkthrough(super.build(context));
}

/// Reveal mode for progressive practice
enum RevealMode {
  word, // Word by word
  phrase, // Phrase by phrase
}
