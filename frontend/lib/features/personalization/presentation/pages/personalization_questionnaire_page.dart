import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/shared/widgets/popup.dart';
import 'package:disciplefy_bible_study/shared/widgets/welcome_chrome.dart';
import 'package:disciplefy_bible_study/features/personalization/domain/entities/personalization_entity.dart';
import 'package:disciplefy_bible_study/features/personalization/domain/repositories/personalization_repository.dart';
import 'package:disciplefy_bible_study/features/personalization/presentation/bloc/personalization_bloc.dart';
import 'package:disciplefy_bible_study/features/personalization/presentation/bloc/personalization_event.dart';
import 'package:disciplefy_bible_study/features/personalization/presentation/bloc/personalization_state.dart';
import 'package:disciplefy_bible_study/features/personalization/presentation/widgets/question_option_card.dart';

/// Number of questions in the questionnaire.
const int _questionCount = 6;

/// Full-screen questionnaire page for personalization (6 questions)
class PersonalizationQuestionnairePage extends StatefulWidget {
  final VoidCallback? onComplete;

  /// Where answers are saved; the default implementation when null.
  final PersonalizationRepository? repository;

  const PersonalizationQuestionnairePage({
    super.key,
    this.onComplete,
    @visibleForTesting this.repository,
  });

  @override
  State<PersonalizationQuestionnairePage> createState() =>
      _PersonalizationQuestionnairePageState();
}

class _PersonalizationQuestionnairePageState
    extends State<PersonalizationQuestionnairePage> {
  /// Bumped by "Retry" after a failed save: a fresh bloc restarts the
  /// questionnaire.
  int _attempt = 0;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      key: ValueKey(_attempt),
      create: (_) => PersonalizationBloc(repository: widget.repository)
        ..add(const NextQuestion()),
      child: _QuestionnaireContent(
        onComplete: widget.onComplete,
        onRetry: () => setState(() => _attempt++),
      ),
    );
  }
}

class _QuestionnaireContent extends StatelessWidget {
  final VoidCallback? onComplete;
  final VoidCallback onRetry;

  const _QuestionnaireContent({this.onComplete, required this.onRetry});

  @override
  Widget build(BuildContext context) {
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
          if (state is PersonalizationError) {
            // Saving failed: without this the spinner would never end.
            return _ErrorScaffold(
              onRetry: onRetry,
              onClose: () => _showSkipDialog(context),
            );
          }
          if (state is! QuestionnaireInProgress) {
            // Starting up or submitting.
            return const _LoadingScaffold();
          }
          return _buildQuestionnaire(context, state);
        },
      ),
    );
  }

  Widget _buildQuestionnaire(
      BuildContext context, QuestionnaireInProgress state) {
    final palette = ReaderPalette.of(context);
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final bloc = context.read<PersonalizationBloc>();
    final step = state.currentQuestion + 1;
    final eyebrow = '${context.tr(
      TranslationKeys.questionnaireStepOf,
      {'current': '$step', 'total': '$_questionCount'},
    )}  ·  ${_getTitle(context, state.currentQuestion)}';

    return Scaffold(
      backgroundColor: palette.page,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: topInset + 200,
            child: const WelcomePhotoBackdrop(
              asset: WelcomePhotos.wheatDawn,
              alignment: Alignment.bottomCenter,
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                children: [
                  SizedBox(height: topInset + 4),
                  // Close + Skip
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        IconButton(
                          key: const Key('questionnaire_close'),
                          tooltip: MaterialLocalizations.of(context)
                              .closeButtonTooltip,
                          icon: Icon(
                            Icons.close_rounded,
                            color: palette.isDark ? Colors.white : palette.text,
                          ),
                          onPressed: () => _showSkipDialog(context),
                        ),
                        const Spacer(),
                        TextButton(
                          key: const Key('questionnaire_skip'),
                          onPressed: () => _showSkipDialog(context),
                          style: TextButton.styleFrom(
                            foregroundColor: palette.isDark
                                ? Colors.white.withValues(alpha: 0.85)
                                : palette.muted,
                            minimumSize: const Size(48, 44),
                            shape: const StadiumBorder(),
                          ),
                          child: Text(
                            context.tr(TranslationKeys.questionnaireSkip),
                            style: AppFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _StepProgress(
                      current: state.currentQuestion,
                      total: _questionCount,
                    ),
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      // Fill the area, top-aligned: the default centres the
                      // question, leaving a gap above short ones and pushing
                      // long ones up under the progress bar.
                      layoutBuilder: (current, previous) => Stack(
                        fit: StackFit.expand,
                        alignment: Alignment.topCenter,
                        children: [...previous, if (current != null) current],
                      ),
                      child: _StepScope(
                        key: ValueKey(state.currentQuestion),
                        eyebrow: eyebrow,
                        child: _buildQuestion(context, state),
                      ),
                    ),
                  ),
                  // Continue + Back
                  Padding(
                    padding: EdgeInsets.fromLTRB(24, 8, 24, bottomInset + 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        WelcomePrimaryButton(
                          key: const Key('questionnaire_continue'),
                          label: state.isLastQuestion
                              ? context.tr(TranslationKeys.questionnaireDone)
                              : context
                                  .tr(TranslationKeys.questionnaireContinue),
                          onPressed: state.canProceed
                              ? () => bloc.add(state.isLastQuestion
                                  ? const SubmitQuestionnaire()
                                  : const NextQuestion())
                              : null,
                        ),
                        if (state.currentQuestion > 0) ...[
                          const SizedBox(height: 4),
                          SizedBox(
                            width: double.infinity,
                            child: TextButton(
                              key: const Key('questionnaire_back'),
                              onPressed: () =>
                                  bloc.add(const PreviousQuestion()),
                              style: TextButton.styleFrom(
                                foregroundColor: palette.muted,
                                minimumSize: const Size.fromHeight(46),
                                shape: const StadiumBorder(),
                              ),
                              child: Text(
                                context.tr(TranslationKeys.questionnaireBack),
                                textAlign: TextAlign.center,
                                style: AppFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: palette.muted,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
      builder: (dialogContext) => PopupDialog(
        children: [
          PopupHeader(
            icon: const PopupIconCircle(icon: Icons.tune_rounded),
            title: context.tr(TranslationKeys.questionnaireSkipTitle),
            body: context.tr(TranslationKeys.questionnaireSkipMessage),
          ),
          const SizedBox(height: 24),
          PopupPrimaryButton(
            key: const Key('questionnaire_skip_confirm'),
            label: context.tr(TranslationKeys.questionnaireSkip),
            onPressed: () {
              Navigator.pop(dialogContext);
              context
                  .read<PersonalizationBloc>()
                  .add(const SkipQuestionnaire());
            },
          ),
          const SizedBox(height: 4),
          PopupTextButton(
            label: context.tr(TranslationKeys.questionnaireCancel),
            onPressed: () => Navigator.pop(dialogContext),
          ),
        ],
      ),
    );
  }
}

/// Page-coloured screen with a palette spinner (starting up, submitting).
class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold();

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Scaffold(
      backgroundColor: palette.page,
      body: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(palette.accentIcon),
          ),
        ),
      ),
    );
  }
}

/// Shown when saving the answers failed: message, retry (starts the
/// questionnaire again) and close (skip dialog).
class _ErrorScaffold extends StatelessWidget {
  final VoidCallback onRetry;
  final VoidCallback onClose;

  const _ErrorScaffold({required this.onRetry, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Scaffold(
      backgroundColor: palette.page,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PopupHeader(
                    icon: const PopupIconCircle(icon: Icons.cloud_off_rounded),
                    title: context.tr(TranslationKeys.commonErrorTryAgain),
                  ),
                  const SizedBox(height: 24),
                  WelcomePrimaryButton(
                    key: const Key('questionnaire_retry'),
                    label: context.tr(TranslationKeys.commonRetry),
                    onPressed: onRetry,
                  ),
                  const SizedBox(height: 4),
                  PopupTextButton(
                    label: context.tr(TranslationKeys.questionnaireSkip),
                    onPressed: onClose,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Slim segmented progress: one gold segment per answered/current question.
class _StepProgress extends StatelessWidget {
  final int current;
  final int total;

  const _StepProgress({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Semantics(
      value: '${current + 1} / $total',
      child: Row(
        children: [
          for (var i = 0; i < total; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 4,
                decoration: BoxDecoration(
                  color: i <= current
                      ? palette.gold
                      : (palette.isDark
                          ? Colors.white.withValues(alpha: 0.16)
                          : palette.outline),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Carries the step eyebrow ("STEP 2 OF 6 · YOUR GOALS") down to the
/// question layout.
class _StepScope extends InheritedWidget {
  final String eyebrow;

  const _StepScope({
    super.key,
    required this.eyebrow,
    required super.child,
  });

  static String? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_StepScope>()?.eyebrow;

  @override
  bool updateShouldNotify(_StepScope oldWidget) => oldWidget.eyebrow != eyebrow;
}

/// Eyebrow, Poppins question title, muted subtitle and the answer cards.
class _QuestionLayout extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? header;
  final List<Widget> options;

  const _QuestionLayout({
    required this.title,
    required this.subtitle,
    required this.options,
    this.header,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final eyebrow = _StepScope.of(context);
    final isNarrow = MediaQuery.sizeOf(context).width < 360;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (eyebrow != null) ...[
            WelcomeEyebrow(eyebrow),
            const SizedBox(height: 10),
          ],
          WelcomeTitle(title, fontSize: isNarrow ? 23 : 26),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: AppFonts.inter(
              fontSize: 15,
              height: 1.45,
              color: palette.muted,
            ),
          ),
          if (header != null) ...[
            const SizedBox(height: 14),
            Align(alignment: Alignment.centerLeft, child: header),
          ],
          const SizedBox(height: 22),
          ...options,
        ],
      ),
    );
  }
}

/// "{n} of 3 selected" chip above the multi-select answers.
class _SelectionCounter extends StatelessWidget {
  final String text;

  const _SelectionCounter({required this.text});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, size: 16, color: palette.gold),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: AppFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: palette.text,
              ),
            ),
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
    return _QuestionLayout(
      title: context.tr(TranslationKeys.questionnaireFaithStageTitle),
      subtitle: context.tr(TranslationKeys.questionnaireFaithStageSubtitle),
      options: [
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
    return _QuestionLayout(
      title: context.tr(TranslationKeys.questionnaireSpiritualGoalsTitle),
      subtitle: context.tr(TranslationKeys.questionnaireSpiritualGoalsSubtitle),
      header: _SelectionCounter(
        text: context.tr(
          TranslationKeys.questionnaireSpiritualGoalsSelectionCounter,
          {'count': selected.length.toString()},
        ),
      ),
      options: [
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
    return _QuestionLayout(
      title: context.tr(TranslationKeys.questionnaireTimeAvailabilityTitle),
      subtitle:
          context.tr(TranslationKeys.questionnaireTimeAvailabilitySubtitle),
      options: [
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
    return _QuestionLayout(
      title: context.tr(TranslationKeys.questionnaireLearningStyleTitle),
      subtitle: context.tr(TranslationKeys.questionnaireLearningStyleSubtitle),
      options: [
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
    return _QuestionLayout(
      title: context.tr(TranslationKeys.questionnaireLifeStageFocusTitle),
      subtitle: context.tr(TranslationKeys.questionnaireLifeStageFocusSubtitle),
      options: [
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
    return _QuestionLayout(
      title: context.tr(TranslationKeys.questionnaireBiggestChallengeTitle),
      subtitle:
          context.tr(TranslationKeys.questionnaireBiggestChallengeSubtitle),
      options: [
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
