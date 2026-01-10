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

/// Full-screen questionnaire page for personalization (6 questions)
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
                  // Progress indicator (1/6 to 6/6)
                  LinearProgressIndicator(
                    value: (state.currentQuestion + 1) / 6,
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
        return context.tr(TranslationKeys.questionnaireYourGoals);
      case 2:
        return context.tr(TranslationKeys.questionnaireYourTime);
      case 3:
        return context.tr(TranslationKeys.questionnaireYourStyle);
      case 4:
        return context.tr(TranslationKeys.questionnaireYourFocus);
      case 5:
        return context.tr(TranslationKeys.questionnaireYourChallenge);
      default:
        return context.tr(TranslationKeys.questionnairePersonalize);
    }
  }

  Widget _buildQuestion(BuildContext context, QuestionnaireInProgress state) {
    switch (state.currentQuestion) {
      case 0:
        return _FaithStageQuestion(
          key: const ValueKey('faith_stage'),
          selected: state.faithStage,
        );
      case 1:
        return _SpiritualGoalsQuestion(
          key: const ValueKey('spiritual_goals'),
          selected: state.spiritualGoals,
        );
      case 2:
        return _TimeAvailabilityQuestion(
          key: const ValueKey('time_availability'),
          selected: state.timeAvailability,
        );
      case 3:
        return _LearningStyleQuestion(
          key: const ValueKey('learning_style'),
          selected: state.learningStyle,
        );
      case 4:
        return _LifeStageFocusQuestion(
          key: const ValueKey('life_stage_focus'),
          selected: state.lifeStageFocus,
        );
      case 5:
        return _BiggestChallengeQuestion(
          key: const ValueKey('biggest_challenge'),
          selected: state.biggestChallenge,
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

// ===========================================================================
// Question 1: Faith Stage
// ===========================================================================

class _FaithStageQuestion extends StatelessWidget {
  final FaithStage? selected;

  const _FaithStageQuestion({super.key, this.selected});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr(TranslationKeys.questionnaireFaithStageTitle),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr(TranslationKeys.questionnaireFaithStageSubtitle),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          for (final option in FaithStage.values)
            QuestionOptionCard(
              label: context.tr(_getFaithStageTranslationKey(option)),
              isSelected: selected == option,
              icon: _getIcon(option),
              onTap: () {
                context.read<PersonalizationBloc>().add(
                      SelectFaithStage(option),
                    );
              },
            ),
        ],
      ),
    );
  }

  String _getFaithStageTranslationKey(FaithStage option) {
    switch (option) {
      case FaithStage.newBeliever:
        return TranslationKeys.questionnaireFaithStageNewBeliever;
      case FaithStage.growingBeliever:
        return TranslationKeys.questionnaireFaithStageGrowingBeliever;
      case FaithStage.committedDisciple:
        return TranslationKeys.questionnaireFaithStageCommittedDisciple;
    }
  }

  IconData _getIcon(FaithStage option) {
    switch (option) {
      case FaithStage.newBeliever:
        return Icons.eco_outlined;
      case FaithStage.growingBeliever:
        return Icons.trending_up;
      case FaithStage.committedDisciple:
        return Icons.psychology_outlined;
    }
  }
}

// ===========================================================================
// Question 2: Spiritual Goals (Multi-select, 1-3)
// ===========================================================================

class _SpiritualGoalsQuestion extends StatelessWidget {
  final List<SpiritualGoal> selected;

  const _SpiritualGoalsQuestion({super.key, required this.selected});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr(TranslationKeys.questionnaireSpiritualGoalsTitle),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr(TranslationKeys.questionnaireSpiritualGoalsSubtitle),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          // Selection counter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  context.tr(
                    TranslationKeys.questionnaireSpiritualGoalsSelectionCounter,
                    {'count': selected.length.toString()},
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          for (final option in SpiritualGoal.values)
            MultiSelectOptionCard(
              label: context.tr(_getSpiritualGoalTranslationKey(option)),
              isSelected: selected.contains(option),
              icon: _getIcon(option),
              onTap: () {
                context.read<PersonalizationBloc>().add(
                      ToggleSpiritualGoal(option),
                    );
              },
            ),
        ],
      ),
    );
  }

  String _getSpiritualGoalTranslationKey(SpiritualGoal option) {
    switch (option) {
      case SpiritualGoal.foundationalFaith:
        return TranslationKeys.questionnaireSpiritualGoalsFoundationalFaith;
      case SpiritualGoal.spiritualDepth:
        return TranslationKeys.questionnaireSpiritualGoalsSpiritualDepth;
      case SpiritualGoal.relationships:
        return TranslationKeys.questionnaireSpiritualGoalsRelationships;
      case SpiritualGoal.apologetics:
        return TranslationKeys.questionnaireSpiritualGoalsApologetics;
      case SpiritualGoal.service:
        return TranslationKeys.questionnaireSpiritualGoalsService;
      case SpiritualGoal.theology:
        return TranslationKeys.questionnaireSpiritualGoalsTheology;
    }
  }

  IconData _getIcon(SpiritualGoal option) {
    switch (option) {
      case SpiritualGoal.foundationalFaith:
        return Icons.menu_book_outlined;
      case SpiritualGoal.spiritualDepth:
        return Icons.self_improvement_outlined;
      case SpiritualGoal.relationships:
        return Icons.people_outlined;
      case SpiritualGoal.apologetics:
        return Icons.shield_outlined;
      case SpiritualGoal.service:
        return Icons.volunteer_activism_outlined;
      case SpiritualGoal.theology:
        return Icons.psychology_outlined;
    }
  }
}

// ===========================================================================
// Question 3: Time Availability
// ===========================================================================

class _TimeAvailabilityQuestion extends StatelessWidget {
  final TimeAvailability? selected;

  const _TimeAvailabilityQuestion({super.key, this.selected});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr(TranslationKeys.questionnaireTimeAvailabilityTitle),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr(TranslationKeys.questionnaireTimeAvailabilitySubtitle),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          for (final option in TimeAvailability.values)
            QuestionOptionCard(
              label: context.tr(_getTimeAvailabilityTranslationKey(option)),
              isSelected: selected == option,
              icon: _getIcon(option),
              onTap: () {
                context.read<PersonalizationBloc>().add(
                      SelectTimeAvailability(option),
                    );
              },
            ),
        ],
      ),
    );
  }

  String _getTimeAvailabilityTranslationKey(TimeAvailability option) {
    switch (option) {
      case TimeAvailability.fiveToTenMin:
        return TranslationKeys.questionnaireTimeAvailability5To10Min;
      case TimeAvailability.tenToTwentyMin:
        return TranslationKeys.questionnaireTimeAvailability10To20Min;
      case TimeAvailability.twentyPlusMin:
        return TranslationKeys.questionnaireTimeAvailability20PlusMin;
    }
  }

  IconData _getIcon(TimeAvailability option) {
    switch (option) {
      case TimeAvailability.fiveToTenMin:
        return Icons.timer_outlined;
      case TimeAvailability.tenToTwentyMin:
        return Icons.schedule_outlined;
      case TimeAvailability.twentyPlusMin:
        return Icons.hourglass_bottom_outlined;
    }
  }
}

// ===========================================================================
// Question 4: Learning Style
// ===========================================================================

class _LearningStyleQuestion extends StatelessWidget {
  final LearningStyle? selected;

  const _LearningStyleQuestion({super.key, this.selected});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr(TranslationKeys.questionnaireLearningStyleTitle),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr(TranslationKeys.questionnaireLearningStyleSubtitle),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          for (final option in LearningStyle.values)
            QuestionOptionCard(
              label: context.tr(_getLearningStyleTranslationKey(option)),
              isSelected: selected == option,
              icon: _getIcon(option),
              onTap: () {
                context.read<PersonalizationBloc>().add(
                      SelectLearningStyle(option),
                    );
              },
            ),
        ],
      ),
    );
  }

  String _getLearningStyleTranslationKey(LearningStyle option) {
    switch (option) {
      case LearningStyle.practicalApplication:
        return TranslationKeys.questionnaireLearningStylePracticalApplication;
      case LearningStyle.deepUnderstanding:
        return TranslationKeys.questionnaireLearningStyleDeepUnderstanding;
      case LearningStyle.reflectionMeditation:
        return TranslationKeys.questionnaireLearningStyleReflectionMeditation;
      case LearningStyle.balancedApproach:
        return TranslationKeys.questionnaireLearningStyleBalancedApproach;
    }
  }

  IconData _getIcon(LearningStyle option) {
    switch (option) {
      case LearningStyle.practicalApplication:
        return Icons.build_outlined;
      case LearningStyle.deepUnderstanding:
        return Icons.school_outlined;
      case LearningStyle.reflectionMeditation:
        return Icons.self_improvement_outlined;
      case LearningStyle.balancedApproach:
        return Icons.balance_outlined;
    }
  }
}

// ===========================================================================
// Question 5: Life Stage Focus
// ===========================================================================

class _LifeStageFocusQuestion extends StatelessWidget {
  final LifeStageFocus? selected;

  const _LifeStageFocusQuestion({super.key, this.selected});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr(TranslationKeys.questionnaireLifeStageFocusTitle),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr(TranslationKeys.questionnaireLifeStageFocusSubtitle),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          for (final option in LifeStageFocus.values)
            QuestionOptionCard(
              label: context.tr(_getLifeStageFocusTranslationKey(option)),
              isSelected: selected == option,
              icon: _getIcon(option),
              onTap: () {
                context.read<PersonalizationBloc>().add(
                      SelectLifeStageFocus(option),
                    );
              },
            ),
        ],
      ),
    );
  }

  String _getLifeStageFocusTranslationKey(LifeStageFocus option) {
    switch (option) {
      case LifeStageFocus.personalFoundation:
        return TranslationKeys.questionnaireLifeStageFocusPersonalFoundation;
      case LifeStageFocus.familyRelationships:
        return TranslationKeys.questionnaireLifeStageFocusFamilyRelationships;
      case LifeStageFocus.communityImpact:
        return TranslationKeys.questionnaireLifeStageFocusCommunityImpact;
      case LifeStageFocus.intellectualGrowth:
        return TranslationKeys.questionnaireLifeStageFocusIntellectualGrowth;
    }
  }

  IconData _getIcon(LifeStageFocus option) {
    switch (option) {
      case LifeStageFocus.personalFoundation:
        return Icons.person_outlined;
      case LifeStageFocus.familyRelationships:
        return Icons.family_restroom_outlined;
      case LifeStageFocus.communityImpact:
        return Icons.public_outlined;
      case LifeStageFocus.intellectualGrowth:
        return Icons.psychology_outlined;
    }
  }
}

// ===========================================================================
// Question 6: Biggest Challenge
// ===========================================================================

class _BiggestChallengeQuestion extends StatelessWidget {
  final BiggestChallenge? selected;

  const _BiggestChallengeQuestion({super.key, this.selected});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr(TranslationKeys.questionnaireBiggestChallengeTitle),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr(TranslationKeys.questionnaireBiggestChallengeSubtitle),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          for (final option in BiggestChallenge.values)
            QuestionOptionCard(
              label: context.tr(_getBiggestChallengeTranslationKey(option)),
              isSelected: selected == option,
              icon: _getIcon(option),
              onTap: () {
                context.read<PersonalizationBloc>().add(
                      SelectBiggestChallenge(option),
                    );
              },
            ),
        ],
      ),
    );
  }

  String _getBiggestChallengeTranslationKey(BiggestChallenge option) {
    switch (option) {
      case BiggestChallenge.startingBasics:
        return TranslationKeys.questionnaireBiggestChallengeStartingBasics;
      case BiggestChallenge.stayingConsistent:
        return TranslationKeys.questionnaireBiggestChallengeStayingConsistent;
      case BiggestChallenge.handlingDoubts:
        return TranslationKeys.questionnaireBiggestChallengeHandlingDoubts;
      case BiggestChallenge.sharingFaith:
        return TranslationKeys.questionnaireBiggestChallengeSharingFaith;
      case BiggestChallenge.growingStagnant:
        return TranslationKeys.questionnaireBiggestChallengeGrowingStagnant;
    }
  }

  IconData _getIcon(BiggestChallenge option) {
    switch (option) {
      case BiggestChallenge.startingBasics:
        return Icons.help_outline;
      case BiggestChallenge.stayingConsistent:
        return Icons.event_repeat;
      case BiggestChallenge.handlingDoubts:
        return Icons.live_help_outlined;
      case BiggestChallenge.sharingFaith:
        return Icons.share_outlined;
      case BiggestChallenge.growingStagnant:
        return Icons.trending_flat;
    }
  }
}
