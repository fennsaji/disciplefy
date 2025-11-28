import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/auth_protected_screen.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../notifications/presentation/widgets/notification_enable_prompt.dart';
import '../../domain/entities/memory_verse_entity.dart';
import '../bloc/memory_verse_bloc.dart';
import '../bloc/memory_verse_event.dart';
import '../bloc/memory_verse_state.dart';
import '../widgets/quality_rating_buttons.dart';
import '../widgets/review_feedback_dialog.dart';
import '../widgets/timer_badge.dart';
import '../widgets/verse_flip_card.dart';
import '../widgets/verse_rating_sheet.dart';

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
  int currentIndex = 0;
  bool _hasTriggeredNotificationPrompt = false;

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

  void _resetTimer() {
    setState(() => elapsedSeconds = 0);
  }

  /// Shows memory verse overdue notification prompt after first review
  Future<void> _showMemoryVerseOverduePrompt() async {
    if (_hasTriggeredNotificationPrompt) return;
    _hasTriggeredNotificationPrompt = true;

    // Delay to show after the review feedback
    await Future.delayed(const Duration(milliseconds: 2000));

    if (!mounted) return;

    final languageCode = context.translationService.currentLanguage.code;
    await showNotificationEnablePrompt(
      context: context,
      type: NotificationPromptType.memoryVerseOverdue,
      languageCode: languageCode,
    );
  }

  void _loadVerse() {
    final state = context.read<MemoryVerseBloc>().state;
    if (state is DueVersesLoaded) {
      try {
        final targetId = widget.verseIds != null
            ? widget.verseIds![currentIndex]
            : widget.verseId;
        final verse = state.verses.firstWhere((v) => v.id == targetId);
        setState(() => currentVerse = verse);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr(TranslationKeys.reviewVerseNotFound)),
              backgroundColor: Colors.red,
            ),
          );
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              context.pop();
            }
          });
        }
      }
    } else {
      context.read<MemoryVerseBloc>().add(const LoadDueVerses());
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _loadVerse();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              GoRouter.of(context).goToMemoryVerses();
            }
          },
        ),
        title: Text(context.tr(TranslationKeys.reviewVerseTitle)),
        actions: [
          if (widget.verseIds != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Center(
                child: Text(
                  '${currentIndex + 1}/${widget.verseIds!.length}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: BlocConsumer<MemoryVerseBloc, MemoryVerseState>(
        listener: (context, state) {
          if (state is ReviewSubmitted) {
            _showReviewFeedback(context, state);
            // Only show notification prompt if there are more verses to review
            // This prevents race condition where navigation occurs while prompt is showing
            final hasMoreVerses = widget.verseIds != null &&
                currentIndex < widget.verseIds!.length - 1;
            if (hasMoreVerses) {
              _showMemoryVerseOverduePrompt();
            }
            _moveToNextVerse();
          } else if (state is MemoryVerseError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          } else if (state is OperationQueued) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.cloud_off, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(child: Text(state.message)),
                  ],
                ),
                backgroundColor: Colors.orange,
              ),
            );
            _moveToNextVerse();
          }
        },
        builder: (context, state) {
          if (currentVerse == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    TimerBadge(elapsedSeconds: elapsedSeconds),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
                        child: VerseFlipCard(
                          verse: currentVerse!,
                          isFlipped: isFlipped,
                          onFlip: () => setState(() => isFlipped = !isFlipped),
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
                    if (!isFlipped)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: TextButton.icon(
                          onPressed: _skipVerse,
                          icon: const Icon(Icons.skip_next),
                          label: Text(
                              context.tr(TranslationKeys.reviewSkipForNow)),
                          style: TextButton.styleFrom(
                            foregroundColor: theme.colorScheme.onSurfaceVariant,
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
                      onPressed: () => _showRatingBottomSheet(context),
                      icon: const Icon(Icons.rate_review),
                      label: Text(context.tr(TranslationKeys.reviewRateReview)),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: theme.colorScheme.primaryContainer,
                        foregroundColor: theme.colorScheme.onPrimaryContainer,
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
    ).withAuthProtection();
  }

  void _showRatingBottomSheet(BuildContext context) {
    VerseRatingSheet.show(
      context,
      onRatingSelected: _submitReview,
    );
  }

  void _submitReview(int qualityRating) {
    if (currentVerse == null) return;
    context.read<MemoryVerseBloc>().add(
          SubmitReview(
            memoryVerseId: currentVerse!.id,
            qualityRating: qualityRating,
            timeSpentSeconds: elapsedSeconds,
          ),
        );
  }

  void _showReviewFeedback(BuildContext context, ReviewSubmitted state) {
    ReviewFeedbackDialog.show(
      context,
      qualityRating: state.qualityRating,
      message: state.message,
      intervalDays: state.verse.intervalDays,
    );
  }

  void _moveToNextVerse() {
    if (widget.verseIds != null && currentIndex < widget.verseIds!.length - 1) {
      setState(() {
        currentIndex++;
        isFlipped = false;
        currentVerse = null;
        _resetTimer();
      });
      _loadVerse();
    } else {
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          context.pop();
        }
      });
    }
  }

  void _skipVerse() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr(TranslationKeys.reviewSkipTitle)),
        content: Text(context.tr(TranslationKeys.reviewSkipContent)),
        actions: [
          TextButton(
            onPressed: () => dialogContext.pop(),
            child: Text(context.tr(TranslationKeys.reviewCancel)),
          ),
          ElevatedButton(
            onPressed: () {
              dialogContext.pop();
              _moveToNextVerse();
            },
            child: Text(context.tr(TranslationKeys.reviewSkip)),
          ),
        ],
      ),
    );
  }
}
