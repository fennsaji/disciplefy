import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/repositories/community_repository.dart';
import 'blocked_users_event.dart';
import 'blocked_users_state.dart';

/// Manages the Settings → Blocked Users list.
class BlockedUsersBloc extends Bloc<BlockedUsersEvent, BlockedUsersState> {
  final CommunityRepository _repository;

  BlockedUsersBloc({required CommunityRepository repository})
      : _repository = repository,
        super(const BlockedUsersState()) {
    on<BlockedUsersLoadRequested>(_onLoadRequested);
    on<BlockedUserUnblockRequested>(_onUnblockRequested);
  }

  Future<void> _onLoadRequested(
    BlockedUsersLoadRequested event,
    Emitter<BlockedUsersState> emit,
  ) async {
    emit(state.copyWith(
        status: BlockedUsersStatus.loading, clearErrorMessage: true));

    final result = await _repository.getBlockedUsers();

    result.fold(
      (failure) => emit(state.copyWith(
        status: BlockedUsersStatus.failure,
        errorMessage: failure.message,
      )),
      (users) => emit(state.copyWith(
        status: BlockedUsersStatus.success,
        users: users,
      )),
    );
  }

  Future<void> _onUnblockRequested(
    BlockedUserUnblockRequested event,
    Emitter<BlockedUsersState> emit,
  ) async {
    final previous = state.users;

    // Optimistic removal, restored on failure.
    emit(state.copyWith(
      users: previous.where((u) => u.userId != event.userId).toList(),
      clearErrorMessage: true,
    ));

    final result = await _repository.unblockUser(event.userId);

    result.fold(
      (failure) => emit(state.copyWith(
        users: previous,
        status: BlockedUsersStatus.failure,
        errorMessage: failure.message,
      )),
      (_) => emit(state.copyWith(status: BlockedUsersStatus.success)),
    );
  }
}
