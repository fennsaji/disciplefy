import 'package:equatable/equatable.dart';

import '../../../domain/entities/fellowship_entity.dart';

/// Lifecycle status for [FellowshipSettingsBloc]'s save operation.
enum FellowshipSettingsStatus { idle, saving, saved, failure }

/// State for [FellowshipSettingsBloc].
///
/// [original] is the last-saved fellowship (starts as the seeded entity);
/// [draft] accumulates in-progress edits. [isDirty] compares the two via
/// [FellowshipEntity]'s [Equatable] props.
class FellowshipSettingsState extends Equatable {
  final FellowshipEntity? original;
  final FellowshipEntity? draft;
  final FellowshipSettingsStatus status;
  final String? errorMessage;

  const FellowshipSettingsState({
    this.original,
    this.draft,
    this.status = FellowshipSettingsStatus.idle,
    this.errorMessage,
  });

  /// True when [draft] differs from the last-saved [original].
  bool get isDirty => original != draft;

  FellowshipSettingsState copyWith({
    FellowshipEntity? original,
    FellowshipEntity? draft,
    FellowshipSettingsStatus? status,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return FellowshipSettingsState(
      original: original ?? this.original,
      draft: draft ?? this.draft,
      status: status ?? this.status,
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [original, draft, status, errorMessage];
}
