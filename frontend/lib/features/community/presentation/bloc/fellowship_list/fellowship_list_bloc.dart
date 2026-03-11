import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../features/community/domain/repositories/community_repository.dart';
import 'fellowship_list_event.dart';
import 'fellowship_list_state.dart';

/// BLoC that manages the list of fellowships the current user belongs to,
/// and the join-via-invite-token flow.
///
/// Inject [CommunityRepository] via the constructor.
class FellowshipListBloc
    extends Bloc<FellowshipListEvent, FellowshipListState> {
  final CommunityRepository _repository;

  FellowshipListBloc({required CommunityRepository repository})
      : _repository = repository,
        super(const FellowshipListState.initial()) {
    on<FellowshipListLoadRequested>(_onLoadRequested);
    on<FellowshipJoinRequested>(_onJoinRequested);
    on<FellowshipCreateRequested>(_onCreateRequested);
  }

  // ---------------------------------------------------------------------------
  // Handlers
  // ---------------------------------------------------------------------------

  /// Fetches the full list of fellowships for the current user.
  Future<void> _onLoadRequested(
    FellowshipListLoadRequested event,
    Emitter<FellowshipListState> emit,
  ) async {
    emit(state.copyWith(
      status: FellowshipListStatus.loading,
      clearErrorMessage: true,
    ));

    final result = await _repository.getFellowships();

    result.fold(
      (failure) => emit(state.copyWith(
        status: FellowshipListStatus.failure,
        errorMessage: failure.message,
      )),
      (fellowships) => emit(state.copyWith(
        status: FellowshipListStatus.success,
        fellowships: fellowships,
        clearErrorMessage: true,
      )),
    );
  }

  /// Creates a new fellowship, then reloads the list on success.
  Future<void> _onCreateRequested(
    FellowshipCreateRequested event,
    Emitter<FellowshipListState> emit,
  ) async {
    emit(state.copyWith(
      createStatus: FellowshipCreateStatus.loading,
      clearCreateError: true,
    ));

    final result = await _repository.createFellowship(
      name: event.name,
      description: event.description,
      maxMembers: event.maxMembers,
      isPublic: event.isPublic,
      language: event.language,
    );

    await result.fold(
      (failure) async => emit(state.copyWith(
        createStatus: FellowshipCreateStatus.failure,
        createError: failure.message,
      )),
      (_) async {
        emit(state.copyWith(createStatus: FellowshipCreateStatus.success));
        add(const FellowshipListLoadRequested());
      },
    );
  }

  /// Joins a fellowship using [event.inviteToken], then reloads the list on
  /// success so the newly joined fellowship appears immediately.
  Future<void> _onJoinRequested(
    FellowshipJoinRequested event,
    Emitter<FellowshipListState> emit,
  ) async {
    emit(state.copyWith(
      joinStatus: FellowshipJoinStatus.loading,
      clearJoinError: true,
    ));

    final result = await _repository.joinFellowship(event.inviteToken);

    await result.fold(
      (failure) async => emit(state.copyWith(
        joinStatus: FellowshipJoinStatus.failure,
        joinError: failure.message,
      )),
      (_) async {
        emit(state.copyWith(joinStatus: FellowshipJoinStatus.success));

        // Reload the fellowship list so the UI reflects the newly joined group.
        add(const FellowshipListLoadRequested());
      },
    );
  }
}
