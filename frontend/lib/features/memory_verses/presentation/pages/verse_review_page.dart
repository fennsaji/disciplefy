import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

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

  @override
  void initState() {
    super.initState();
    _startTimer();
    _loadVerse();
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
      try {
        final verse = state.verses.firstWhere((v) => v.id == widget.verseId);
        setState(() => currentVerse = verse);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr(TranslationKeys.reviewVerseNotFound)),
              backgroundColor: AppColors.error,
            ),
          );
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) context.pop();
          });
        }
      }
    } else {
      context.read<MemoryVerseBloc>().add(const LoadDueVerses());
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _loadVerse();
      });
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackNavigation();
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
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          child: Text(
                            context.tr(TranslationKeys.reviewTapToReveal),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontStyle: FontStyle.italic,
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
                        label: Text(context.tr(TranslationKeys.practiceSubmit)),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: AppColors.brandSecondary,
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
    ).withAuthProtection();
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
