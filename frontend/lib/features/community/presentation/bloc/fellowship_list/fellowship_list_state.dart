import 'package:equatable/equatable.dart';

import '../../../../../features/community/domain/entities/fellowship_entity.dart';

/// Describes the load lifecycle for the fellowships list.
enum FellowshipListStatus { initial, loading, success, failure }

/// Describes the join-flow lifecycle (separate from the list status so both
/// can be observed independently by the UI).
enum FellowshipJoinStatus { idle, loading, success, failure }

/// Describes the create-flow lifecycle.
enum FellowshipCreateStatus { idle, loading, success, failure }

/// Single immutable state for [FellowshipListBloc].
///
/// Use [copyWith] to produce updated snapshots; never mutate fields directly.
class FellowshipListState extends Equatable {
  /// Load status of the fellowships list.
  final FellowshipListStatus status;

  /// The fellowships the current user belongs to.
  final List<FellowshipEntity> fellowships;

  /// Non-null when [status] is [FellowshipListStatus.failure].
  final String? errorMessage;

  /// Join-flow status, independent of the list status.
  final FellowshipJoinStatus joinStatus;

  /// Non-null when [joinStatus] is [FellowshipJoinStatus.failure].
  final String? joinError;

  /// Create-flow status, independent of the list status.
  final FellowshipCreateStatus createStatus;

  /// Non-null when [createStatus] is [FellowshipCreateStatus.failure].
  final String? createError;

  const FellowshipListState({
    this.status = FellowshipListStatus.initial,
    this.fellowships = const [],
    this.errorMessage,
    this.joinStatus = FellowshipJoinStatus.idle,
    this.joinError,
    this.createStatus = FellowshipCreateStatus.idle,
    this.createError,
  });

  /// Returns the initial state (used as the BLoC seed value).
  const FellowshipListState.initial() : this();

  @override
  List<Object?> get props => [
        status,
        fellowships,
        errorMessage,
        joinStatus,
        joinError,
        createStatus,
        createError,
      ];

  /// Creates a copy of this state with the provided fields replaced.
  FellowshipListState copyWith({
    FellowshipListStatus? status,
    List<FellowshipEntity>? fellowships,
    String? errorMessage,
    bool clearErrorMessage = false,
    FellowshipJoinStatus? joinStatus,
    String? joinError,
    bool clearJoinError = false,
    FellowshipCreateStatus? createStatus,
    String? createError,
    bool clearCreateError = false,
  }) {
    return FellowshipListState(
      status: status ?? this.status,
      fellowships: fellowships ?? this.fellowships,
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      joinStatus: joinStatus ?? this.joinStatus,
      joinError: clearJoinError ? null : (joinError ?? this.joinError),
      createStatus: createStatus ?? this.createStatus,
      createError: clearCreateError ? null : (createError ?? this.createError),
    );
  }
}
