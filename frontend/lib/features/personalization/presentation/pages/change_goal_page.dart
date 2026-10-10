import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/router/app_routes.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/onboarding/domain/growth_goals.dart';
import 'package:disciplefy_bible_study/features/onboarding/presentation/widgets/first_run_choice_row.dart';
import 'package:disciplefy_bible_study/features/onboarding/presentation/widgets/growth_goal_icon.dart';
import 'package:disciplefy_bible_study/features/personalization/presentation/bloc/change_goal_cubit.dart';
import 'package:disciplefy_bible_study/shared/widgets/app_snackbar.dart';
import 'package:disciplefy_bible_study/shared/widgets/welcome_chrome.dart';

/// Settings > Change my goal: the six goals of the first run, the saved one
/// selected. Save stores the new goal on the server and closes the page with
/// `true`, so the caller can refresh what comes next.
class ChangeGoalPage extends StatelessWidget {
  /// For tests; the page makes its own from the service locator otherwise.
  final ChangeGoalCubit? cubit;

  const ChangeGoalPage({super.key, this.cubit});

  @override
  Widget build(BuildContext context) {
    final provided = cubit;
    if (provided != null) {
      return BlocProvider<ChangeGoalCubit>.value(
        value: provided,
        child: const _ChangeGoalView(),
      );
    }
    return BlocProvider<ChangeGoalCubit>(
      create: (_) => ChangeGoalCubit(sl())..load(),
      child: const _ChangeGoalView(),
    );
  }
}

class _ChangeGoalView extends StatelessWidget {
  const _ChangeGoalView();

  void _close(BuildContext context, {bool changed = false}) {
    if (context.canPop()) {
      context.pop(changed);
    } else {
      context.go(AppRoutes.settings);
    }
  }

  void _onState(BuildContext context, ChangeGoalState state) {
    if (state.status == ChangeGoalStatus.saved) {
      showAppSnackBar(context, context.tr(TranslationKeys.goalSaved),
          tone: AppSnackTone.success);
      _close(context, changed: true);
    } else if (state.status == ChangeGoalStatus.failed) {
      showAppSnackBar(context, context.tr(TranslationKeys.goalSaveFailed),
          tone: AppSnackTone.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final isNarrow = MediaQuery.sizeOf(context).width < 360;
    return BlocConsumer<ChangeGoalCubit, ChangeGoalState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: _onState,
      builder: (context, state) {
        final saving = state.status == ChangeGoalStatus.saving;
        final cubit = context.read<ChangeGoalCubit>();
        return Scaffold(
          backgroundColor: palette.page,
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: IconButton(
                          key: const Key('change_goal_back'),
                          tooltip: context.tr(TranslationKeys.firstRunBack),
                          onPressed: saving ? null : () => _close(context),
                          icon: Icon(Icons.arrow_back_rounded,
                              color: palette.text),
                        ),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Semantics(
                              header: true,
                              child: WelcomeTitle(
                                context.tr(TranslationKeys.firstRunGoalTitle),
                                fontSize: isNarrow ? 21 : 23,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              context.tr(TranslationKeys.goalPageHelper),
                              style: AppFonts.inter(
                                fontSize: 14,
                                height: 1.5,
                                color: palette.muted,
                              ),
                            ),
                            const SizedBox(height: 12),
                            for (final goal in GrowthGoal.values)
                              FirstRunChoiceRow(
                                key: Key('change_goal_${goal.name}'),
                                leading: (color) => Icon(growthGoalIcon(goal),
                                    size: 20, color: color),
                                title: context.tr(goal.labelKey),
                                isSelected: state.selected == goal,
                                onTap: saving ? null : () => cubit.select(goal),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                      child: WelcomePrimaryButton(
                        key: const Key('change_goal_save'),
                        label: context.tr(TranslationKeys.commonSave),
                        height: 40,
                        isLoading: saving,
                        onPressed: state.canSave ? cubit.save : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
