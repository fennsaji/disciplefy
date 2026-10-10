import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:disciplefy_bible_study/features/onboarding/domain/growth_goals.dart';
import 'package:disciplefy_bible_study/features/personalization/domain/growth_goal_repository.dart';

enum ChangeGoalStatus { ready, saving, saved, failed }

class ChangeGoalState extends Equatable {
  /// The goal saved now (null: none yet).
  final GrowthGoal? current;

  /// The goal picked on the page.
  final GrowthGoal? selected;
  final ChangeGoalStatus status;

  const ChangeGoalState({
    this.current,
    this.selected,
    this.status = ChangeGoalStatus.ready,
  });

  /// Save is offered once a different goal is picked.
  bool get canSave =>
      selected != null &&
      selected != current &&
      status != ChangeGoalStatus.saving;

  ChangeGoalState copyWith({
    GrowthGoal? current,
    GrowthGoal? selected,
    ChangeGoalStatus? status,
  }) =>
      ChangeGoalState(
        current: current ?? this.current,
        selected: selected ?? this.selected,
        status: status ?? this.status,
      );

  @override
  List<Object?> get props => [current, selected, status];
}

/// Settings > Change my goal: shows the saved goal selected, saves a new one
/// on the server.
class ChangeGoalCubit extends Cubit<ChangeGoalState> {
  final GrowthGoalRepository _goals;

  ChangeGoalCubit(this._goals)
      : super(ChangeGoalState(
          current: _goals.cachedGoal,
          selected: _goals.cachedGoal,
        ));

  /// Refreshes the saved goal from the server. Keeps a pick already made.
  Future<void> load() async {
    final goal = await _goals.loadGoal();
    if (isClosed || goal == null) return;
    final picked = state.selected != state.current;
    emit(ChangeGoalState(
      current: goal,
      selected: picked ? state.selected : goal,
      status: state.status,
    ));
  }

  void select(GrowthGoal goal) {
    if (state.status == ChangeGoalStatus.saving) return;
    emit(state.copyWith(selected: goal, status: ChangeGoalStatus.ready));
  }

  Future<void> save() async {
    final goal = state.selected;
    if (goal == null || !state.canSave) return;
    emit(state.copyWith(status: ChangeGoalStatus.saving));
    final result =
        await _goals.saveGoal(goal, source: GrowthGoalSource.settings);
    if (isClosed) return;
    emit(result.fold(
      (_) => state.copyWith(status: ChangeGoalStatus.failed),
      (saved) => ChangeGoalState(
          current: saved, selected: saved, status: ChangeGoalStatus.saved),
    ));
  }
}
