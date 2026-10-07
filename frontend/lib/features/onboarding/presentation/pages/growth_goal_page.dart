import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/router/app_routes.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/onboarding/domain/growth_goals.dart';
import 'package:disciplefy_bible_study/features/onboarding/presentation/bloc/first_run_cubit.dart';
import 'package:disciplefy_bible_study/features/onboarding/presentation/bloc/first_run_state.dart';
import 'package:disciplefy_bible_study/features/onboarding/presentation/widgets/first_run_choice_row.dart';
import 'package:disciplefy_bible_study/shared/widgets/photo_wash.dart';
import 'package:disciplefy_bible_study/shared/widgets/welcome_chrome.dart';

/// Second screen of the new first run: "What would you like to grow in?"
/// with six goals, each opening a learning path. "Start lesson 1" starts the
/// path (as a guest when signed out) and opens lesson 1 in Quick Read.
///
/// Needs a [FirstRunCubit] above it.
class GrowthGoalPage extends StatefulWidget {
  const GrowthGoalPage({super.key});

  @override
  State<GrowthGoalPage> createState() => _GrowthGoalPageState();
}

class _GrowthGoalPageState extends State<GrowthGoalPage> {
  GrowthGoal _selected = GrowthGoal.values.first;
  StarterPaths _starter = StarterPaths.empty;
  late final bool _guestHelper;

  /// Icon of each goal's leading tile.
  static IconData iconFor(GrowthGoal goal) => switch (goal) {
        GrowthGoal.newToFaith => Icons.eco_outlined,
        GrowthGoal.freshStart => Icons.wb_twilight_rounded,
        GrowthGoal.walkWithGod => Icons.directions_walk_rounded,
        GrowthGoal.hopeHardTimes => Icons.light_mode_outlined,
        GrowthGoal.readGospel => Icons.auto_stories_outlined,
        GrowthGoal.understandGospel => Icons.lightbulb_outline_rounded,
      };

  String get _language => sl<TranslationService>().currentLanguage.code;

  @override
  void initState() {
    super.initState();
    final cubit = context.read<FirstRunCubit>();
    _guestHelper = cubit.showsGuestHelper;
    cubit.loadStarterPaths(_language).then((starter) {
      if (mounted) setState(() => _starter = starter);
    });
  }

  void _start() =>
      context.read<FirstRunCubit>().startLessonOne(_selected, _language);

  void _skip() => context.read<FirstRunCubit>().skip(_language);

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.welcome);
    }
  }

  void _onState(BuildContext context, FirstRunState state) {
    if (state is FirstRunReady) {
      context.go(state.location);
    } else if (state is FirstRunNeedsLogin) {
      context.go(AppRoutes.login);
    } else if (state is FirstRunSkipped) {
      context.go(AppRoutes.home);
    }
  }

  String _helper(BuildContext context) {
    if (!_guestHelper) return context.tr(TranslationKeys.firstRunPickOne);
    final total = _starter.totalPaths;
    return total == null || total <= 0
        ? context.tr(TranslationKeys.firstRunPickOneGuestPlain)
        : context.tr(TranslationKeys.firstRunPickOneGuest, {'n': total});
  }

  String? _meta(BuildContext context, GrowthGoal goal) {
    final info = _starter.forGoal(goal);
    if (info == null) return null;
    // Keep "· 8 lessons" on one line: only the title may wrap.
    const marker = '\u0001';
    final template = context.tr(TranslationKeys.firstRunPathMeta,
        {'title': marker, 'n': info.lessonCount});
    return template.replaceAll(' ', ' ').replaceFirst(marker, info.title);
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final isNarrow = MediaQuery.sizeOf(context).width < 360;

    return BlocConsumer<FirstRunCubit, FirstRunState>(
      listener: _onState,
      builder: (context, state) {
        final busy = state is FirstRunStarting;
        return Scaffold(
          backgroundColor: palette.page,
          body: PhotoWash(
            image: WelcomePhotos.winterSunset,
            height: 320,
            child: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    children: [
                      _Header(
                        onBack: busy ? null : _back,
                        onSkip: busy ? null : _skip,
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Semantics(
                                header: true,
                                child: WelcomeTitle(
                                  context.tr(TranslationKeys.firstRunGoalTitle),
                                  fontSize: isNarrow ? 22 : 24,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _helper(context),
                                key: const Key('first_run_goal_helper'),
                                style: AppFonts.inter(
                                  fontSize: 13,
                                  height: 1.45,
                                  color: palette.muted,
                                ),
                              ),
                              const SizedBox(height: 16),
                              for (final goal in GrowthGoal.values)
                                FirstRunChoiceRow(
                                  key: Key('first_run_goal_${goal.name}'),
                                  leading: (color) => Icon(iconFor(goal),
                                      size: 20, color: color),
                                  title: context.tr(goal.labelKey),
                                  subtitle: _meta(context, goal),
                                  isSelected: _selected == goal,
                                  onTap: busy
                                      ? null
                                      : () => setState(() => _selected = goal),
                                ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (state is FirstRunFailed)
                              _InlineError(
                                state: state,
                                onRetry: _start,
                                onHome: () => context.go(AppRoutes.home),
                              ),
                            WelcomePrimaryButton(
                              key: const Key('first_run_start_lesson'),
                              label: context
                                  .tr(TranslationKeys.firstRunStartLessonOne),
                              height: 40,
                              isLoading: busy,
                              onPressed: _start,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              context.tr(TranslationKeys.firstRunTerms),
                              textAlign: TextAlign.center,
                              style: AppFonts.inter(
                                fontSize: 12,
                                height: 1.4,
                                color: palette.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Back arrow, the step dashes (2 of 3) and Skip.
class _Header extends StatelessWidget {
  final VoidCallback? onBack;
  final VoidCallback? onSkip;

  const _Header({required this.onBack, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
      child: Row(
        children: [
          IconButton(
            key: const Key('first_run_goal_back'),
            tooltip: context.tr(TranslationKeys.firstRunBack),
            onPressed: onBack,
            icon: Icon(Icons.arrow_back_rounded, color: palette.text),
          ),
          Expanded(
            child: Semantics(
              label: context
                  .tr(TranslationKeys.firstRunStep, {'n': 2, 'total': 3}),
              excludeSemantics: true,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < 3; i++)
                    Container(
                      width: 18,
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: i < 2 ? palette.gold : palette.outline,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                ],
              ),
            ),
          ),
          TextButton(
            key: const Key('first_run_goal_skip'),
            onPressed: onSkip,
            style: TextButton.styleFrom(
              foregroundColor: palette.muted,
              minimumSize: const Size(48, 40),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: Text(
              context.tr(TranslationKeys.firstRunSkip),
              style: AppFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: palette.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Short message and one action (Try again, or Go to Home when retrying
/// cannot help) above the Start button.
class _InlineError extends StatelessWidget {
  final FirstRunFailed state;
  final VoidCallback onRetry;
  final VoidCallback onHome;

  const _InlineError({
    required this.state,
    required this.onRetry,
    required this.onHome,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final actionLabel = state.accountRequired
        ? context.tr(TranslationKeys.firstRunGoHome)
        : context.tr(TranslationKeys.firstRunRetry);
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        key: const Key('first_run_goal_error'),
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: palette.outline),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, size: 18, color: palette.gold),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.tr(state.messageKey),
                style: AppFonts.inter(
                  fontSize: 13,
                  height: 1.35,
                  color: palette.text,
                ),
              ),
            ),
            TextButton(
              key: const Key('first_run_goal_error_action'),
              onPressed: state.accountRequired ? onHome : onRetry,
              style: TextButton.styleFrom(
                foregroundColor: palette.gold,
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              child: Text(
                actionLabel,
                style: AppFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: palette.gold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
