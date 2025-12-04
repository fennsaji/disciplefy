import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../domain/entities/personalization_entity.dart';
import '../bloc/personalization_bloc.dart';
import '../bloc/personalization_event.dart';
import '../bloc/personalization_state.dart';
import '../widgets/question_option_card.dart';

/// Full-screen questionnaire page for personalization
class PersonalizationQuestionnairePage extends StatelessWidget {
  final VoidCallback? onComplete;

  const PersonalizationQuestionnairePage({
    super.key,
    this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => PersonalizationBloc()..add(const NextQuestion()),
      child: _QuestionnaireContent(onComplete: onComplete),
    );
  }
}

class _QuestionnaireContent extends StatelessWidget {
  final VoidCallback? onComplete;

  const _QuestionnaireContent({this.onComplete});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // Show skip dialog when Android back button is pressed
        _showSkipDialog(context);
      },
      child: BlocConsumer<PersonalizationBloc, PersonalizationState>(
        listener: (context, state) {
          if (state is QuestionnaireSubmitted ||
              state is PersonalizationComplete) {
            onComplete?.call();
            if (context.canPop()) {
              context.pop();
            }
          }
        },
        builder: (context, state) {
          if (state is QuestionnaireSubmitting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (state is! QuestionnaireInProgress) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  _showSkipDialog(context);
                },
              ),
              title: Text(_getTitle(context, state.currentQuestion)),
              actions: [
                TextButton(
                  onPressed: () => _showSkipDialog(context),
                  child: Text(context.tr(TranslationKeys.questionnaireSkip)),
                ),
              ],
            ),
            body: SafeArea(
              child: Column(
                children: [
                  // Progress indicator
                  LinearProgressIndicator(
                    value: (state.currentQuestion + 1) / 3,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _buildQuestion(context, state),
                    ),
                  ),
                  // Navigation buttons
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        if (state.currentQuestion > 0)
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                context.read<PersonalizationBloc>().add(
                                      const PreviousQuestion(),
                                    );
                              },
                              child: Text(context
                                  .tr(TranslationKeys.questionnaireBack)),
                            ),
                          ),
                        if (state.currentQuestion > 0)
                          const SizedBox(width: 12),
                        Expanded(
                          flex: state.currentQuestion > 0 ? 1 : 1,
                          child: FilledButton(
                            onPressed: state.canProceed
                                ? () {
                                    if (state.isLastQuestion) {
                                      context.read<PersonalizationBloc>().add(
                                            const SubmitQuestionnaire(),
                                          );
                                    } else {
                                      context.read<PersonalizationBloc>().add(
                                            const NextQuestion(),
                                          );
                                    }
                                  }
                                : null,
                            child: Text(state.isLastQuestion
                                ? context.tr(TranslationKeys.questionnaireDone)
                                : context
                                    .tr(TranslationKeys.questionnaireContinue)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _getTitle(BuildContext context, int question) {
    switch (question) {
      case 0:
        return context.tr(TranslationKeys.questionnaireYourJourney);
      case 1:
        return context.tr(TranslationKeys.questionnaireWhatYouSeek);
      case 2:
        return context.tr(TranslationKeys.questionnaireYourTime);
      default:
        return context.tr(TranslationKeys.questionnairePersonalize);
    }
  }

  Widget _buildQuestion(BuildContext context, QuestionnaireInProgress state) {
    switch (state.currentQuestion) {
      case 0:
        return _FaithJourneyQuestion(
          key: const ValueKey('faith'),
          selected: state.faithJourney,
        );
      case 1:
        return _SeekingQuestion(
          key: const ValueKey('seeking'),
          selected: state.seeking,
        );
      case 2:
        return _TimeCommitmentQuestion(
          key: const ValueKey('time'),
          selected: state.timeCommitment,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  void _showSkipDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr(TranslationKeys.questionnaireSkipTitle)),
        content: Text(
          context.tr(TranslationKeys.questionnaireSkipMessage),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.tr(TranslationKeys.questionnaireCancel)),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context
                  .read<PersonalizationBloc>()
                  .add(const SkipQuestionnaire());
            },
            child: Text(context.tr(TranslationKeys.questionnaireSkip)),
          ),
        ],
      ),
    );
  }
}

class _FaithJourneyQuestion extends StatelessWidget {
  final String? selected;

  const _FaithJourneyQuestion({super.key, this.selected});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr(TranslationKeys.questionnaireFaithTitle),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr(TranslationKeys.questionnaireFaithSubtitle),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          for (final option in FaithJourney.values)
            QuestionOptionCard(
              label: _getFaithLabel(context, option),
              isSelected: selected == option.value,
              icon: _getIcon(option),
              onTap: () {
                context.read<PersonalizationBloc>().add(
                      SelectFaithJourney(option.value),
                    );
              },
            ),
        ],
      ),
    );
  }

  String _getFaithLabel(BuildContext context, FaithJourney option) {
    switch (option) {
      case FaithJourney.newToFaith:
        return context.tr(TranslationKeys.questionnaireFaithNew);
      case FaithJourney.growing:
        return context.tr(TranslationKeys.questionnaireFaithGrowing);
      case FaithJourney.mature:
        return context.tr(TranslationKeys.questionnaireFaithMature);
    }
  }

  IconData _getIcon(FaithJourney option) {
    switch (option) {
      case FaithJourney.newToFaith:
        return Icons.eco_outlined;
      case FaithJourney.growing:
        return Icons.trending_up;
      case FaithJourney.mature:
        return Icons.psychology_outlined;
    }
  }
}

class _SeekingQuestion extends StatelessWidget {
  final List<String> selected;

  const _SeekingQuestion({super.key, required this.selected});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr(TranslationKeys.questionnaireSeekingTitle),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr(TranslationKeys.questionnaireSeekingSubtitle),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          for (final option in SeekingType.values)
            MultiSelectOptionCard(
              label: _getSeekingLabel(context, option),
              isSelected: selected.contains(option.value),
              icon: _getIcon(option),
              onTap: () {
                context.read<PersonalizationBloc>().add(
                      ToggleSeeking(option.value),
                    );
              },
            ),
        ],
      ),
    );
  }

  String _getSeekingLabel(BuildContext context, SeekingType option) {
    switch (option) {
      case SeekingType.peace:
        return context.tr(TranslationKeys.questionnaireSeekingPeace);
      case SeekingType.guidance:
        return context.tr(TranslationKeys.questionnaireSeekingGuidance);
      case SeekingType.knowledge:
        return context.tr(TranslationKeys.questionnaireSeekingKnowledge);
      case SeekingType.relationships:
        return context.tr(TranslationKeys.questionnaireSeekingRelationships);
      case SeekingType.challenges:
        return context.tr(TranslationKeys.questionnaireSeekingChallenges);
    }
  }

  IconData _getIcon(SeekingType option) {
    switch (option) {
      case SeekingType.peace:
        return Icons.spa_outlined;
      case SeekingType.guidance:
        return Icons.explore_outlined;
      case SeekingType.knowledge:
        return Icons.menu_book_outlined;
      case SeekingType.relationships:
        return Icons.people_outlined;
      case SeekingType.challenges:
        return Icons.fitness_center_outlined;
    }
  }
}

class _TimeCommitmentQuestion extends StatelessWidget {
  final String? selected;

  const _TimeCommitmentQuestion({super.key, this.selected});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr(TranslationKeys.questionnaireTimeTitle),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr(TranslationKeys.questionnaireTimeSubtitle),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          for (final option in TimeCommitment.values)
            QuestionOptionCard(
              label: _getTimeLabel(context, option),
              isSelected: selected == option.value,
              icon: _getIcon(option),
              onTap: () {
                context.read<PersonalizationBloc>().add(
                      SelectTimeCommitment(option.value),
                    );
              },
            ),
        ],
      ),
    );
  }

  String _getTimeLabel(BuildContext context, TimeCommitment option) {
    switch (option) {
      case TimeCommitment.fiveMin:
        return context.tr(TranslationKeys.questionnaireTime5Min);
      case TimeCommitment.fifteenMin:
        return context.tr(TranslationKeys.questionnaireTime15Min);
      case TimeCommitment.thirtyMin:
        return context.tr(TranslationKeys.questionnaireTime30Min);
    }
  }

  IconData _getIcon(TimeCommitment option) {
    switch (option) {
      case TimeCommitment.fiveMin:
        return Icons.timer_outlined;
      case TimeCommitment.fifteenMin:
        return Icons.schedule_outlined;
      case TimeCommitment.thirtyMin:
        return Icons.hourglass_bottom_outlined;
    }
  }
}
