import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/auth_protected_screen.dart';
import '../../domain/entities/memory_verse_entity.dart';
import '../bloc/memory_verse_bloc.dart';
import '../bloc/memory_verse_event.dart';
import '../bloc/memory_verse_state.dart';
import '../widgets/quality_rating_buttons.dart';
import '../widgets/verse_flip_card.dart';

/// Page for reviewing a memory verse with spaced repetition.
///
/// Features:
/// - Flip card animation (reference → full verse)
/// - Quality rating buttons (0-5 SM-2 scale)
/// - Timer tracking review duration
/// - Progress indicator
/// - Next verse navigation
/// - Skip option
class VerseReviewPage extends StatefulWidget {
  final String verseId;
  final List<String>? verseIds; // Optional: for sequential review

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
      if (mounted) {
        setState(() {
          elapsedSeconds++;
        });
      }
    });
  }

  void _resetTimer() {
    setState(() {
      elapsedSeconds = 0;
    });
  }

  void _loadVerse() {
    // Load verse by ID from BLoC state
    final state = context.read<MemoryVerseBloc>().state;
    if (state is DueVersesLoaded) {
      try {
        // Derive target ID from current index when reviewing multiple verses
        final targetId = widget.verseIds != null
            ? widget.verseIds![currentIndex]
            : widget.verseId;
        final verse = state.verses.firstWhere(
          (v) => v.id == targetId,
        );
        setState(() {
          currentVerse = verse;
        });
      } catch (e) {
        // Verse not found in due verses, show error
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Verse not found. Please go back and try again.'),
              backgroundColor: Colors.red,
            ),
          );
          // Go back after a delay
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              context.pop();
            }
          });
        }
      }
    } else {
      // BLoC not in the right state, reload verses
      context.read<MemoryVerseBloc>().add(const LoadDueVerses());
      // Wait a bit and try again
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
            // Navigate back to memory verses home
            if (context.canPop()) {
              context.pop();
            } else {
              GoRouter.of(context).goToMemoryVerses();
            }
          },
        ),
        title: const Text('Review Verse'),
        actions: [
          // Progress indicator
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
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          return SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    // Timer display
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.timer,
                              size: 20,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatTime(elapsedSeconds),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Flip Card - takes remaining space
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
                        child: VerseFlipCard(
                          verse: currentVerse!,
                          isFlipped: isFlipped,
                          onFlip: () {
                            setState(() {
                              isFlipped = !isFlipped;
                            });
                          },
                        ),
                      ),
                    ),

                    // Instructions
                    if (!isFlipped)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        child: Text(
                          'Tap card to reveal verse',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),

                    // Skip button
                    if (!isFlipped)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: TextButton.icon(
                          onPressed: _skipVerse,
                          icon: const Icon(Icons.skip_next),
                          label: const Text('Skip for now'),
                          style: TextButton.styleFrom(
                            foregroundColor: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),

                    // Spacing for FAB when card is flipped
                    if (isFlipped) const SizedBox(height: 80),
                  ],
                ),

                // Floating "Rate Review" button (only show when flipped)
                if (isFlipped)
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: ElevatedButton.icon(
                      onPressed: () => _showRatingBottomSheet(context),
                      icon: const Icon(Icons.rate_review),
                      label: const Text('Rate Review'),
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
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Title
                Text(
                  'How well did you remember?',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),

                // Rating buttons
                QualityRatingButtons(
                  onRatingSelected: (rating) {
                    Navigator.pop(context);
                    _submitReview(rating);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(
              _getQualityIcon(state.qualityRating),
              color: _getQualityColor(state.qualityRating),
              size: 32,
            ),
            const SizedBox(width: 12),
            const Text('Review Submitted'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(state.message),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    Theme.of(dialogContext).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Next Review',
                    style:
                        Theme.of(dialogContext).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'In ${state.verse.intervalDays} days',
                    style: Theme.of(dialogContext).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              dialogContext.pop(); // Close dialog
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _moveToNextVerse() {
    if (widget.verseIds != null && currentIndex < widget.verseIds!.length - 1) {
      setState(() {
        currentIndex++;
        isFlipped = false;
        currentVerse = null; // Clear current verse to show loading state
        _resetTimer();
      });
      _loadVerse();
    } else {
      // No more verses, go back to memory verses page
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
        title: const Text('Skip Verse?'),
        content: const Text(
          'This verse will remain in your due list. '
          'It\'s better to review it to maintain your progress.',
        ),
        actions: [
          TextButton(
            onPressed: () => dialogContext.pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              dialogContext.pop(); // Close dialog
              _moveToNextVerse();
            },
            child: const Text('Skip'),
          ),
        ],
      ),
    );
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  IconData _getQualityIcon(int rating) {
    if (rating >= 4) return Icons.celebration;
    if (rating >= 3) return Icons.thumb_up;
    return Icons.refresh;
  }

  Color _getQualityColor(int rating) {
    if (rating >= 4) return Colors.green;
    if (rating >= 3) return Colors.blue;
    return Colors.orange;
  }
}
