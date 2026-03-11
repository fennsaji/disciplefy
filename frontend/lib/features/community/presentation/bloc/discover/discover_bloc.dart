import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../features/community/domain/repositories/community_repository.dart';
import 'discover_event.dart';
import 'discover_state.dart';

/// BLoC that manages discovery of public fellowships and direct-join flow.
///
/// Inject [CommunityRepository] via the constructor.
class DiscoverBloc extends Bloc<DiscoverEvent, DiscoverState> {
  final CommunityRepository _repository;

  DiscoverBloc({required CommunityRepository repository})
      : _repository = repository,
        super(const DiscoverState.initial()) {
    on<DiscoverLoadRequested>(_onLoadRequested);
    on<DiscoverLoadMoreRequested>(_onLoadMoreRequested);
    on<DiscoverJoinRequested>(_onJoinRequested);
    on<DiscoverJoinAcknowledged>(_onJoinAcknowledged);
  }

  // ---------------------------------------------------------------------------
  // Handlers
  // ---------------------------------------------------------------------------

  /// Fetches the first page of public fellowships, optionally filtered by
  /// [event.language]. Resets any existing list.
  Future<void> _onLoadRequested(
    DiscoverLoadRequested event,
    Emitter<DiscoverState> emit,
  ) async {
    emit(state.copyWith(
      status: DiscoverStatus.loading,
      language: () => event.language,
      search: () => event.search,
      errorMessage: () => null,
      hasMore: false,
      nextCursor: () => null,
    ));

    final result = await _repository.discoverFellowships(
      language: event.language,
      search: event.search,
    );

    result.fold(
      (failure) => emit(state.copyWith(
        status: DiscoverStatus.failure,
        errorMessage: () => failure.message,
      )),
      (page) => emit(state.copyWith(
        status: DiscoverStatus.success,
        fellowships: page.fellowships,
        hasMore: page.hasMore,
        nextCursor: () => page.nextCursor,
      )),
    );
  }

  /// Loads the next page and appends it to the existing list.
  Future<void> _onLoadMoreRequested(
    DiscoverLoadMoreRequested event,
    Emitter<DiscoverState> emit,
  ) async {
    if (!state.hasMore || state.isLoadingMore) return;

    emit(state.copyWith(isLoadingMore: true));

    final result = await _repository.discoverFellowships(
      language: state.language,
      search: state.search,
      cursor: state.nextCursor,
    );

    result.fold(
      (failure) => emit(state.copyWith(
        isLoadingMore: false,
        errorMessage: () => failure.message,
      )),
      (page) => emit(state.copyWith(
        isLoadingMore: false,
        fellowships: [...state.fellowships, ...page.fellowships],
        hasMore: page.hasMore,
        nextCursor: () => page.nextCursor,
      )),
    );
  }

  /// Joins a public fellowship directly, then removes it from the list on
  /// success and signals the UI to show a snackbar via [justJoinedName].
  Future<void> _onJoinRequested(
    DiscoverJoinRequested event,
    Emitter<DiscoverState> emit,
  ) async {
    // Mark fellowship as in-flight so the UI can show a per-row loading state.
    emit(state.copyWith(
      joiningIds: {...state.joiningIds, event.fellowshipId},
    ));

    final result = await _repository.joinPublicFellowship(event.fellowshipId);

    final updatedJoining = Set<String>.from(state.joiningIds)
      ..remove(event.fellowshipId);

    result.fold(
      (failure) => emit(state.copyWith(
        joiningIds: updatedJoining,
        errorMessage: () => failure.message,
      )),
      (_) {
        // Remove the just-joined fellowship from the discoverable list.
        final updated =
            state.fellowships.where((f) => f.id != event.fellowshipId).toList();
        emit(state.copyWith(
          joiningIds: updatedJoining,
          fellowships: updated,
          justJoinedName: () => event.fellowshipName,
        ));
      },
    );
  }

  /// Clears [justJoinedName] after the snackbar has been displayed.
  void _onJoinAcknowledged(
    DiscoverJoinAcknowledged event,
    Emitter<DiscoverState> emit,
  ) {
    emit(state.copyWith(justJoinedName: () => null));
  }
}
