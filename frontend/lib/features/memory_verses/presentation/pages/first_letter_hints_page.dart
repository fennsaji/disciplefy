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
import 'package:disciplefy_bible_study/features/memory_verses/domain/entities/practice_result_params.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/bloc/memory_verse_bloc.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/bloc/memory_verse_event.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/bloc/memory_verse_state.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/utils/quality_calculator.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/widgets/memory_ui/memory_ui.dart';
import 'package:disciplefy_bible_study/features/walkthrough/domain/walkthrough_repository.dart';
import 'package:disciplefy_bible_study/features/walkthrough/domain/walkthrough_screen.dart';
import 'package:disciplefy_bible_study/features/walkthrough/presentation/showcase_keys.dart';
import 'package:disciplefy_bible_study/features/walkthrough/presentation/walkthrough_tooltip.dart';

/// First letter hints practice mode.
///
/// Shows first letter of each word with tap-to-reveal functionality.
/// Tracks hint usage (how many words were revealed).
/// Goal: Minimize hints used for higher score.
class FirstLetterHintsPage extends StatefulWidget {
  final String verseId;

  const FirstLetterHintsPage({
    super.key,
    required this.verseId,
  });

  @override
  State<FirstLetterHintsPage> createState() => _FirstLetterHintsPageState();
}

class _FirstLetterHintsPageState extends State<FirstLetterHintsPage> {
  MemoryVerseEntity? currentVerse;
  Timer? practiceTimer;
  int elapsedSeconds = 0;
  List<HintWord> hintWords = [];
  int hintsUsed = 0;
  bool isCompleted = false;

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
      if (await repo.hasSeen(WalkthroughScreen.practiceFirstLetter)) return;
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted || _showcaseContext == null) return;
      ShowCaseWidget.of(_showcaseContext!).startShowCase(
        [ShowcaseKeys.practiceFirstLetter],
      );
    });
  }

  @override
  void dispose() {
    practiceTimer?.cancel();
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
          _initializeHintWords();
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

  void _initializeHintWords() {
    if (currentVerse == null) return;

    // Include reference at the end of verse text for memorization
    final fullText =
        '${currentVerse!.verseText} ${currentVerse!.verseReference}';
    final words = fullText.split(' ');
    hintWords = words.map((word) {
      final firstLetter = word.isNotEmpty ? word[0] : '';
      final hint = firstLetter + '_' * (word.length - 1);
      return HintWord(
        word: word,
        hint: hint,
        isRevealed: false,
      );
    }).toList();
  }

  void _revealWord(int index) {
    if (hintWords[index].isRevealed) return;

    setState(() {
      hintWords[index].isRevealed = true;
      hintsUsed++;
    });
  }

  /// Reveals the first still-hidden word (same hint accounting as tapping
  /// the word itself).
  void _revealNextHint() {
    final index = hintWords.indexWhere((w) => !w.isRevealed);
    if (index != -1) _revealWord(index);
  }

  void _submitPractice() {
    if (currentVerse == null) return;

    // Calculate accuracy based on hints used
    // Fewer hints = higher accuracy
    final totalWords = hintWords.length;
    final accuracy = totalWords > 0
        ? ((totalWords - hintsUsed) / totalWords * 100).clamp(0.0, 100.0)
        : 100.0;

    // Auto-calculate quality and confidence
    final quality = QualityCalculator.calculateQuality(
      accuracy: accuracy,
      hintsUsed: hintsUsed,
      showedAnswer: false,
    );
    final confidence = QualityCalculator.calculateConfidence(
      accuracy: accuracy,
      hintsUsed: hintsUsed,
      showedAnswer: false,
    );

    // Navigate to results page
    final params = PracticeResultParams(
      verseId: widget.verseId,
      verseReference: currentVerse!.verseReference,
      verseText: currentVerse!.verseText,
      practiceMode: 'first_letter',
      timeSpentSeconds: elapsedSeconds,
      accuracyPercentage: accuracy,
      hintsUsed: hintsUsed,
      showedAnswer: false,
      qualityRating: quality,
      confidenceRating: confidence,
    );

    GoRouter.of(context).goToPracticeResults(params);
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

  @override
  Widget build(BuildContext context) {
    return ShowCaseWidget(
      onFinish: () => sl<WalkthroughRepository>()
          .markSeen(WalkthroughScreen.practiceFirstLetter),
      builder: (showcaseCtx) {
        _showcaseContext = showcaseCtx;
        final verse = currentVerse;
        final palette = ReaderPalette.of(context);
        final l10n = AppLocalizations.of(context)!;
        final hasHiddenWords = hintWords.any((w) => !w.isRevealed);
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            _handleBackNavigation();
          },
          child: BlocListener<MemoryVerseBloc, MemoryVerseState>(
            listener: (context, state) {
              if (state is DueVersesLoaded && currentVerse == null) {
                _loadVerse();
              }
            },
            child: MemoryPracticeScaffold(
              title: context.tr(TranslationKeys.practiceModeFirstLetter),
              subtitle: verse == null
                  ? null
                  : '${verse.verseReference} · '
                      '${context.tr(TranslationKeys.difficultyEasy)}',
              elapsedSeconds: elapsedSeconds,
              onClose: _handleBackNavigation,
              scrollable: verse != null,
              body: verse == null
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        WalkthroughTooltip(
                          showcaseKey: ShowcaseKeys.practiceFirstLetter,
                          title: l10n.walkthroughPracticeFirstLetterTitle,
                          description: l10n.walkthroughPracticeFirstLetterDesc,
                          screen: WalkthroughScreen.practiceFirstLetter,
                          stepNumber: 1,
                          totalSteps: 1,
                          onNext: _onNext,
                          tooltipPosition: TooltipPosition.bottom,
                          highlightBorderRadius: 20,
                          child: MemoryAnswerCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _HintWordsView(
                                  hintWords: hintWords,
                                  onWordTap: _revealWord,
                                ),
                                const SizedBox(height: 14),
                                _HintsUsedLine(
                                  hintsUsed: hintsUsed,
                                  totalWords: hintWords.length,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          context.tr(TranslationKeys.firstLetterInstruction),
                          style: AppFonts.inter(
                            fontSize: 13.5,
                            height: 1.45,
                            color: palette.muted,
                          ),
                        ),
                      ],
                    ),
              bottomBar: verse == null
                  ? null
                  : MemoryActionBar(
                      secondary: [
                        MemoryActionPill(
                          label: context
                              .tr(TranslationKeys.memoryRecallFirstLetterHint),
                          icon: Icons.lightbulb_outline_rounded,
                          onPressed: hasHiddenWords ? _revealNextHint : null,
                        ),
                      ],
                      primary: MemoryPrimaryPill(
                        label: context
                            .tr(TranslationKeys.memoryRecallFirstLetterCheck),
                        icon: Icons.check_rounded,
                        onPressed: _submitPractice,
                      ),
                    ),
            ),
          ),
        ).withAuthProtection();
      },
    );
  }
}

/// Hint word entry
class HintWord {
  final String word;
  final String hint;
  bool isRevealed;

  HintWord({
    required this.word,
    required this.hint,
    required this.isRevealed,
  });
}

/// "Hints used 2/10", coloured green / gold / red as hint use grows.
class _HintsUsedLine extends StatelessWidget {
  final int hintsUsed;
  final int totalWords;

  const _HintsUsedLine({required this.hintsUsed, required this.totalWords});

  @override
  Widget build(BuildContext context) {
    final percentage = totalWords > 0 ? (hintsUsed / totalWords) * 100 : 0;
    final tone = hintsUsed == 0
        ? MemoryTone.neutral
        : percentage <= 20
            ? MemoryTone.success
            : percentage <= 50
                ? MemoryTone.gold
                : MemoryTone.error;
    final color = tone == MemoryTone.neutral
        ? ReaderPalette.of(context).muted
        : MemoryToneColors.of(context, tone).foreground;
    return Text(
      context.tr(TranslationKeys.memoryRecallFirstLetterHintsUsed, {
        'used': hintsUsed,
        'total': totalWords,
      }),
      style: AppFonts.inter(
        fontSize: 13.5,
        fontWeight: FontWeight.w500,
        color: color,
        fontFeatures: kMemoryTabular,
      ),
    );
  }
}

/// Wrap of first-letter tiles; revealed words show in full.
class _HintWordsView extends StatelessWidget {
  final List<HintWord> hintWords;
  final ValueChanged<int> onWordTap;

  const _HintWordsView({required this.hintWords, required this.onWordTap});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < hintWords.length; i++)
          _HintWordTile(
            hintWord: hintWords[i],
            index: i,
            onTap: () => onWordTap(i),
          ),
      ],
    );
  }
}

/// One word: its first letter on a raised tile, tap to reveal the word
/// (counts as a hint). Revealed words use the gold selected fill.
class _HintWordTile extends StatelessWidget {
  final HintWord hintWord;
  final int index;
  final VoidCallback onTap;

  const _HintWordTile({
    required this.hintWord,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final revealed = hintWord.isRevealed;
    final letter = hintWord.word.isEmpty ? '' : hintWord.word.characters.first;
    final radius = BorderRadius.circular(10);
    return Semantics(
      button: !revealed,
      label: revealed
          ? hintWord.word
          : context.tr(TranslationKeys.memoryRecallFirstLetterTileLabel, {
              'index': index + 1,
              'letter': letter,
            }),
      excludeSemantics: true,
      child: Material(
        color: revealed ? palette.selectedFill : palette.raised,
        borderRadius: radius,
        child: InkWell(
          onTap: revealed ? null : onTap,
          borderRadius: radius,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 40, minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Center(
                widthFactor: 1,
                heightFactor: 1,
                child: Text(
                  revealed ? hintWord.word : letter.toUpperCase(),
                  softWrap: true,
                  style: AppFonts.inter(
                    fontSize: revealed ? 15.5 : 17,
                    fontWeight: FontWeight.w700,
                    color: revealed ? palette.onSelected : palette.accentIcon,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
