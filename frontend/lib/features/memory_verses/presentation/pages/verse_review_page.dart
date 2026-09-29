import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:showcaseview/showcaseview.dart';

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/core/router/app_router.dart';
import 'package:disciplefy_bible_study/core/router/app_routes.dart';
import 'package:disciplefy_bible_study/core/widgets/auth_protected_screen.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/entities/memory_verse_entity.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/entities/practice_result_params.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/bloc/memory_verse_bloc.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/bloc/memory_verse_event.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/bloc/memory_verse_state.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/widgets/memory_ui/memory_ui.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/widgets/self_assessment_bottom_sheet.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/widgets/verse_flip_card.dart';
import 'package:disciplefy_bible_study/features/walkthrough/domain/walkthrough_repository.dart';
import 'package:disciplefy_bible_study/features/walkthrough/domain/walkthrough_screen.dart';
import 'package:disciplefy_bible_study/features/walkthrough/presentation/showcase_keys.dart';
import 'package:disciplefy_bible_study/features/walkthrough/presentation/walkthrough_tooltip.dart';

class VerseReviewPage extends StatefulWidget {
  final String verseId;
  final List<String>? verseIds;

  const VerseReviewPage({
    super.key,
    required this.verseId,
    this.verseIds,
  });

  @override
  State<VerseReviewPage> createState() => _VerseReviewPageState();
}

class _VerseReviewPageState extends State<VerseReviewPage> {
  MemoryVerseEntity? currentVerse;
  bool isFlipped = false;
  Timer? reviewTimer;
  int elapsedSeconds = 0;

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
      if (await repo.hasSeen(WalkthroughScreen.practiceFlipCard)) return;
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted || _showcaseContext == null) return;
      ShowCaseWidget.of(_showcaseContext!).startShowCase(
        [ShowcaseKeys.practiceFlipCard],
      );
    });
  }

  @override
  void dispose() {
    reviewTimer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    reviewTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => elapsedSeconds++);
    });
  }

  void _loadVerse() {
    final state = context.read<MemoryVerseBloc>().state;
    if (state is DueVersesLoaded) {
      final verse =
          state.verses.firstWhereOrNull((v) => v.id == widget.verseId);
      if (verse != null) {
        setState(() => currentVerse = verse);
      } else {
        context
            .read<MemoryVerseBloc>()
            .add(const LoadDueVerses(forceRefresh: true));
      }
    } else {
      context.read<MemoryVerseBloc>().add(const LoadDueVerses());
    }
  }

  /// Handle back navigation - go to the memory verse list when can't pop.
  ///
  /// There is nothing to pop when this page is the root of the stack, which is
  /// exactly the push-notification case: memory_verse_reminder /
  /// memory_verse_overdue open it with no extra, so [widget.verseId] is ''.
  /// The old fallback built '/memory-verses/practice/' from that empty id and
  /// landed on the router's "Page not found" page (issue report, 3 Sept).
  void _handleBackNavigation() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.memoryVerses);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ShowCaseWidget(
      onFinish: () => sl<WalkthroughRepository>()
          .markSeen(WalkthroughScreen.practiceFlipCard),
      builder: (showcaseCtx) {
        _showcaseContext = showcaseCtx;
        final verse = currentVerse;
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
              title: context.tr(TranslationKeys.practiceModeFlipCard),
              subtitle: verse == null
                  ? null
                  : '${verse.verseReference} · '
                      '${context.tr(TranslationKeys.difficultyEasy)}',
              elapsedSeconds: elapsedSeconds,
              onClose: _handleBackNavigation,
              scrollable: false,
              body: verse == null
                  ? const Center(child: CircularProgressIndicator())
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        // Both faces fill the space, so flipping never
                        // changes the card's size.
                        final height = constraints.maxHeight;
                        return Align(
                          alignment: Alignment.topCenter,
                          child: SizedBox(
                            height: height,
                            child: WalkthroughTooltip(
                              showcaseKey: ShowcaseKeys.practiceFlipCard,
                              title: l10n.walkthroughPracticeFlipCardTitle,
                              description: l10n.walkthroughPracticeFlipCardDesc,
                              screen: WalkthroughScreen.practiceFlipCard,
                              stepNumber: 1,
                              totalSteps: 1,
                              onNext: _onNext,
                              tooltipPosition: TooltipPosition.bottom,
                              highlightBorderRadius: 22,
                              child: VerseFlipCard(
                                verse: verse,
                                isFlipped: isFlipped,
                                onFlip: _toggleFlip,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
              bottomBar: verse == null
                  ? null
                  : MemoryActionBar(
                      secondary: [
                        if (isFlipped)
                          MemoryActionPill(
                            label: context
                                .tr(TranslationKeys.memoryRecallFlipAction),
                            icon: Icons.flip_camera_android_rounded,
                            onPressed: _toggleFlip,
                          ),
                      ],
                      primary: isFlipped
                          ? MemoryPrimaryPill(
                              label: context.tr(TranslationKeys.practiceSubmit),
                              icon: Icons.check_rounded,
                              onPressed: _submitPractice,
                            )
                          : MemoryPrimaryPill(
                              label: context
                                  .tr(TranslationKeys.memoryRecallFlipAction),
                              icon: Icons.flip_camera_android_rounded,
                              onPressed: _toggleFlip,
                            ),
                    ),
            ),
          ),
        ).withAuthProtection();
      },
    );
  }

  void _toggleFlip() => setState(() => isFlipped = !isFlipped);

  Future<void> _submitPractice() async {
    if (currentVerse == null) return;

    // Show self-assessment bottom sheet for passive mode
    final rating = await SelfAssessmentBottomSheet.show(context);

    // User cancelled
    if (rating == null || !mounted) return;

    // Stop the timer
    reviewTimer?.cancel();

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
      practiceMode: 'flip_card',
      timeSpentSeconds: elapsedSeconds,
      accuracyPercentage: accuracy,
      hintsUsed: hintsUsed,
      showedAnswer: showedAnswer,
      qualityRating: quality,
      confidenceRating: confidence,
    );

    GoRouter.of(context).goToPracticeResults(params);
  }
}
