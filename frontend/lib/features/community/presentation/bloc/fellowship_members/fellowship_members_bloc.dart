import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../features/community/domain/repositories/community_repository.dart';
import 'fellowship_members_event.dart';
import 'fellowship_members_state.dart';

/// BLoC that manages the member list for a single fellowship, plus
/// invite creation, mute/unmute, and leave operations.
class FellowshipMembersBloc
    extends Bloc<FellowshipMembersEvent, FellowshipMembersState> {
  final CommunityRepository _repository;

  FellowshipMembersBloc({required CommunityRepository repository})
      : _repository = repository,
        super(const FellowshipMembersState.initial()) {
    on<FellowshipMembersInitialized>(_onInitialized);
    on<FellowshipMembersLoadRequested>(_onLoadRequested);
    on<FellowshipMembersInviteRequested>(_onInviteRequested);
    on<FellowshipMembersMuteRequested>(_onMuteRequested);
    on<FellowshipMembersUnmuteRequested>(_onUnmuteRequested);
    on<FellowshipLeaveRequested>(_onLeaveRequested);
    on<FellowshipEditRequested>(_onEditRequested);
    on<FellowshipInvitesListRequested>(_onInvitesListRequested);
    on<FellowshipInviteRevokeRequested>(_onInviteRevokeRequested);
    on<FellowshipMembersRemoveRequested>(_onRemoveRequested);
    on<FellowshipTransferMentorRequested>(_onTransferMentorRequested);
  }

  Future<void> _onInitialized(
    FellowshipMembersInitialized event,
    Emitter<FellowshipMembersState> emit,
  ) async {
    emit(state.copyWith(
      isMentor: event.isMentor,
      fellowshipId: event.fellowshipId,
      currentUserId: event.currentUserId,
    ));
  }

  Future<void> _onLoadRequested(
    FellowshipMembersLoadRequested event,
    Emitter<FellowshipMembersState> emit,
  ) async {
    emit(state.copyWith(
      status: FellowshipMembersStatus.loading,
      clearErrorMessage: true,
    ));

    final result = await _repository.getFellowshipMembers(event.fellowshipId);

    result.fold(
      (failure) => emit(state.copyWith(
        status: FellowshipMembersStatus.failure,
        errorMessage: failure.message,
      )),
      (members) {
        // Re-derive isMentor from the loaded list — this self-corrects when
        // the navigation extra (FellowshipEntity) was unavailable (e.g. web
        // page refresh or direct URL), which would have caused isMentor to
        // default to false even for actual mentors.
        final uid = state.currentUserId;
        final derivedIsMentor = uid != null
            ? members.any((m) => m.userId == uid && m.role == 'mentor')
            : state.isMentor;

        emit(state.copyWith(
          status: FellowshipMembersStatus.success,
          members: members,
          isMentor: derivedIsMentor,
          clearErrorMessage: true,
        ));
      },
    );
  }

  Future<void> _onInviteRequested(
    FellowshipMembersInviteRequested event,
    Emitter<FellowshipMembersState> emit,
  ) async {
    emit(state.copyWith(
      inviteStatus: FellowshipInviteStatus.loading,
      clearInviteError: true,
    ));

    final result = await _repository.createInvite(state.fellowshipId);

    result.fold(
      (failure) => emit(state.copyWith(
        inviteStatus: FellowshipInviteStatus.failure,
        inviteError: failure.message,
      )),
      (data) => emit(state.copyWith(
        inviteStatus: FellowshipInviteStatus.success,
        inviteToken: data['token'] as String?,
        inviteJoinUrl: data['join_url'] as String?,
        clearInviteError: true,
      )),
    );
  }

  Future<void> _onMuteRequested(
    FellowshipMembersMuteRequested event,
    Emitter<FellowshipMembersState> emit,
  ) async {
    final result = await _repository.muteMember(
      fellowshipId: state.fellowshipId,
      userId: event.userId,
    );

    result.fold(
      (failure) => emit(state.copyWith(errorMessage: failure.message)),
      (_) {
        // Update the member's isMuted flag locally.
        final updated = state.members.map((m) {
          if (m.userId != event.userId) return m;
          return m.copyWith(isMuted: true);
        }).toList();
        emit(state.copyWith(members: updated, clearErrorMessage: true));
      },
    );
  }

  Future<void> _onUnmuteRequested(
    FellowshipMembersUnmuteRequested event,
    Emitter<FellowshipMembersState> emit,
  ) async {
    final result = await _repository.unmuteMember(
      fellowshipId: state.fellowshipId,
      userId: event.userId,
    );

    result.fold(
      (failure) => emit(state.copyWith(errorMessage: failure.message)),
      (_) {
        final updated = state.members.map((m) {
          if (m.userId != event.userId) return m;
          return m.copyWith(isMuted: false);
        }).toList();
        emit(state.copyWith(members: updated, clearErrorMessage: true));
      },
    );
  }

  Future<void> _onLeaveRequested(
    FellowshipLeaveRequested event,
    Emitter<FellowshipMembersState> emit,
  ) async {
    final result = await _repository.leaveFellowship(state.fellowshipId);

    result.fold(
      (failure) => emit(state.copyWith(errorMessage: failure.message)),
      (_) => emit(state.copyWith(
        status: FellowshipMembersStatus.success,
        members: const [],
        clearErrorMessage: true,
      )),
    );
  }

  Future<void> _onEditRequested(
    FellowshipEditRequested event,
    Emitter<FellowshipMembersState> emit,
  ) async {
    emit(state.copyWith(
      editStatus: FellowshipEditStatus.loading,
      clearEditError: true,
    ));

    final result = await _repository.updateFellowship(
      fellowshipId: state.fellowshipId,
      name: event.name,
      description: event.description,
      maxMembers: event.maxMembers,
    );

    result.fold(
      (failure) => emit(state.copyWith(
        editStatus: FellowshipEditStatus.failure,
        editError: failure.message,
      )),
      (_) => emit(state.copyWith(
        editStatus: FellowshipEditStatus.success,
        clearEditError: true,
      )),
    );
  }

  Future<void> _onInvitesListRequested(
    FellowshipInvitesListRequested event,
    Emitter<FellowshipMembersState> emit,
  ) async {
    emit(state.copyWith(
      invitesListStatus: FellowshipInvitesListStatus.loading,
    ));

    final result = await _repository.listInvites(state.fellowshipId);

    result.fold(
      (failure) => emit(state.copyWith(
        invitesListStatus: FellowshipInvitesListStatus.failure,
      )),
      (invites) => emit(state.copyWith(
        invitesListStatus: FellowshipInvitesListStatus.success,
        invitesList: invites,
      )),
    );
  }

  Future<void> _onInviteRevokeRequested(
    FellowshipInviteRevokeRequested event,
    Emitter<FellowshipMembersState> emit,
  ) async {
    // Optimistically remove the invite from the local list.
    final updated =
        state.invitesList.where((i) => i['id'] != event.inviteId).toList();
    emit(state.copyWith(invitesList: updated));

    final result = await _repository.revokeInvite(
      fellowshipId: state.fellowshipId,
      inviteId: event.inviteId,
    );

    result.fold(
      (failure) {
        // Restore the original list on failure.
        emit(state.copyWith(
          invitesList: state.invitesList,
          errorMessage: failure.message,
        ));
      },
      (_) {},
    );
  }

  Future<void> _onRemoveRequested(
    FellowshipMembersRemoveRequested event,
    Emitter<FellowshipMembersState> emit,
  ) async {
    final result = await _repository.removeMember(
      fellowshipId: state.fellowshipId,
      userId: event.userId,
    );

    result.fold(
      (failure) => emit(state.copyWith(errorMessage: failure.message)),
      (_) {
        // Optimistically remove member from local list.
        final updated =
            state.members.where((m) => m.userId != event.userId).toList();
        emit(state.copyWith(members: updated, clearErrorMessage: true));
      },
    );
  }

  Future<void> _onTransferMentorRequested(
    FellowshipTransferMentorRequested event,
    Emitter<FellowshipMembersState> emit,
  ) async {
    emit(state.copyWith(
      transferStatus: FellowshipTransferStatus.loading,
      clearTransferError: true,
    ));

    final result = await _repository.transferMentor(
      fellowshipId: state.fellowshipId,
      newMentorUserId: event.newMentorUserId,
    );

    result.fold(
      (failure) => emit(state.copyWith(
        transferStatus: FellowshipTransferStatus.failure,
        transferError: failure.message,
      )),
      (_) => emit(state.copyWith(
        transferStatus: FellowshipTransferStatus.success,
        // Caller is no longer the mentor after transferring.
        isMentor: false,
        members: const [],
        clearTransferError: true,
      )),
    );
  }
}
