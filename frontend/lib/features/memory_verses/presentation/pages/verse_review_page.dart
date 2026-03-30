import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:showcaseview/showcaseview.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/auth_protected_screen.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../domain/entities/memory_verse_entity.dart';
import '../../domain/entities/practice_result_params.dart';
import '../bloc/memory_verse_bloc.dart';
import '../bloc/memory_verse_event.dart';
import '../bloc/memory_verse_state.dart';
import '../widgets/self_assessment_bottom_sheet.dart';
import '../widgets/timer_badge.dart';
import '../widgets/verse_flip_card.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../walkthrough/domain/walkthrough_screen.dart';
import '../../../walkthrough/domain/walkthrough_repository.dart';
import '../../../walkthrough/presentation/showcase_keys.dart';
import '../../../walkthrough/presentation/walkthrough_tooltip.dart';

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
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return ShowCaseWidget(
      onFinish: () => sl<WalkthroughRepository>()
          .markSeen(WalkthroughScreen.practiceFlipCard),
      builder: (showcaseCtx) {
        _showcaseContext = showcaseCtx;
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
            child: Scaffold(
              appBar: AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _handleBackNavigation,
                ),
                title: Text(context.tr(TranslationKeys.reviewVerseTitle)),
                actions: [
                  TimerBadge(elapsedSeconds: elapsedSeconds, compact: true),
                  const SizedBox(width: 8),
                ],
              ),
              body: BlocBuilder<MemoryVerseBloc, MemoryVerseState>(
                builder: (context, state) {
                  if (currentVerse == null) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return SafeArea(
                    child: Stack(
                      children: [
                        Column(
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: VerseFlipCard(
                                  verse: currentVerse!,
                                  isFlipped: isFlipped,
                                  onFlip: () =>
                                      setState(() => isFlipped = !isFlipped),
                                ),
                              ),
                            ),
                            if (!isFlipped)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16.0),
                                child: WalkthroughTooltip(
                                  showcaseKey: ShowcaseKeys.practiceFlipCard,
                                  title: l10n.walkthroughPracticeFlipCardTitle,
                                  description:
                                      l10n.walkthroughPracticeFlipCardDesc,
                                  screen: WalkthroughScreen.practiceFlipCard,
                                  stepNumber: 1,
                                  totalSteps: 1,
                                  onNext: _onNext,
                                  highlightBorderRadius: 20,
                                  child: Text(
                                    context
                                        .tr(TranslationKeys.reviewTapToReveal),
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ),
                            if (isFlipped) const SizedBox(height: 80),
                          ],
                        ),
                        if (isFlipped)
                          Positioned(
                            bottom: 16,
                            left: 16,
                            right: 16,
                            child: ElevatedButton.icon(
                              onPressed: _submitPractice,
                              icon: const Icon(Icons.check),
                              label: Text(
                                  context.tr(TranslationKeys.practiceSubmit)),
                              style: ElevatedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                backgroundColor: context.appInteractive,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 4,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ).withAuthProtection();
      },
    );
  }

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
