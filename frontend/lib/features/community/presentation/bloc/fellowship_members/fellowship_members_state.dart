import 'package:equatable/equatable.dart';

import '../../../../../features/community/domain/entities/fellowship_member_entity.dart';

/// Describes the load lifecycle for the fellowship members list.
enum FellowshipMembersStatus { initial, loading, success, failure }

/// Describes the status of the invite generation operation.
enum FellowshipInviteStatus { idle, loading, success, failure }

/// Describes the status of loading the active invites list.
enum FellowshipInvitesListStatus { idle, loading, success, failure }

/// Describes the status of a fellowship edit operation.
enum FellowshipEditStatus { idle, loading, success, failure }

/// Describes the status of a transfer-mentor operation.
enum FellowshipTransferStatus { idle, loading, success, failure }

/// Describes the status of a leave-fellowship operation.
enum FellowshipLeaveStatus { idle, loading, success, failure }

/// Describes the status of a delete-fellowship operation.
enum FellowshipDeleteStatus { idle, loading, success, failure }

/// Single immutable state for [FellowshipMembersBloc].
///
/// Use [copyWith] to produce updated snapshots; never mutate fields directly.
class FellowshipMembersState extends Equatable {
  /// Load status of the members list.
  final FellowshipMembersStatus status;

  /// The members of the fellowship, ordered by role (mentor first) and then
  /// join date as returned by the backend.
  final List<FellowshipMemberEntity> members;

  /// Non-null when [status] is [FellowshipMembersStatus.failure].
  final String? errorMessage;

  /// True when the current user is a mentor of this fellowship.
  final bool isMentor;

  /// The fellowship ID (stored so BLoC can pass it to the repository).
  final String fellowshipId;

  /// The current user's Supabase Auth UID, used to re-derive [isMentor]
  /// from the loaded member list when the navigation extra is unavailable.
  final String? currentUserId;

  /// Status of the invite-create operation.
  final FellowshipInviteStatus inviteStatus;

  /// The generated invite token (non-null after a successful invite create).
  final String? inviteToken;

  /// The ID of the generated invite (non-null after a successful invite create).
  final String? inviteId;

  /// The deep-link URL for the invite (e.g. `disciplefy://fellowship/join?token=...`).
  final String? inviteJoinUrl;

  /// Non-null when the invite operation failed.
  final String? inviteError;

  /// Status of loading the active invites list.
  final FellowshipInvitesListStatus invitesListStatus;

  /// Active invite objects returned by the server.
  /// Each map has: `id`, `token`, `expires_at`, `join_url`.
  final List<Map<String, dynamic>> invitesList;

  /// Status of the edit-fellowship operation.
  final FellowshipEditStatus editStatus;

  /// Non-null when the edit operation failed.
  final String? editError;

  /// Status of the transfer-mentor operation.
  final FellowshipTransferStatus transferStatus;

  /// Non-null when the transfer-mentor operation failed.
  final String? transferError;

  /// Status of the leave-fellowship operation.
  final FellowshipLeaveStatus leaveStatus;

  /// Status of the delete-fellowship operation.
  final FellowshipDeleteStatus deleteStatus;

  const FellowshipMembersState({
    this.status = FellowshipMembersStatus.initial,
    this.members = const [],
    this.errorMessage,
    this.isMentor = false,
    this.fellowshipId = '',
    this.currentUserId,
    this.inviteStatus = FellowshipInviteStatus.idle,
    this.inviteToken,
    this.inviteId,
    this.inviteJoinUrl,
    this.inviteError,
    this.invitesListStatus = FellowshipInvitesListStatus.idle,
    this.invitesList = const [],
    this.editStatus = FellowshipEditStatus.idle,
    this.editError,
    this.transferStatus = FellowshipTransferStatus.idle,
    this.transferError,
    this.leaveStatus = FellowshipLeaveStatus.idle,
    this.deleteStatus = FellowshipDeleteStatus.idle,
  });

  /// Returns the initial state (used as the BLoC seed value).
  const FellowshipMembersState.initial() : this();

  @override
  List<Object?> get props => [
        status,
        members,
        errorMessage,
        isMentor,
        fellowshipId,
        currentUserId,
        inviteStatus,
        inviteToken,
        inviteId,
        inviteJoinUrl,
        inviteError,
        invitesListStatus,
        invitesList,
        editStatus,
        editError,
        transferStatus,
        transferError,
        leaveStatus,
        deleteStatus,
      ];

  /// Creates a copy of this state with the provided fields replaced.
  FellowshipMembersState copyWith({
    FellowshipMembersStatus? status,
    List<FellowshipMemberEntity>? members,
    String? errorMessage,
    bool clearErrorMessage = false,
    bool? isMentor,
    String? fellowshipId,
    String? currentUserId,
    FellowshipInviteStatus? inviteStatus,
    String? inviteToken,
    String? inviteId,
    String? inviteJoinUrl,
    String? inviteError,
    bool clearInviteError = false,
    FellowshipInvitesListStatus? invitesListStatus,
    List<Map<String, dynamic>>? invitesList,
    FellowshipEditStatus? editStatus,
    String? editError,
    bool clearEditError = false,
    FellowshipTransferStatus? transferStatus,
    String? transferError,
    bool clearTransferError = false,
    FellowshipLeaveStatus? leaveStatus,
    FellowshipDeleteStatus? deleteStatus,
  }) {
    return FellowshipMembersState(
      status: status ?? this.status,
      members: members ?? this.members,
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      isMentor: isMentor ?? this.isMentor,
      fellowshipId: fellowshipId ?? this.fellowshipId,
      currentUserId: currentUserId ?? this.currentUserId,
      inviteStatus: inviteStatus ?? this.inviteStatus,
      inviteToken: inviteToken ?? this.inviteToken,
      inviteId: inviteId ?? this.inviteId,
      inviteJoinUrl: inviteJoinUrl ?? this.inviteJoinUrl,
      inviteError: clearInviteError ? null : (inviteError ?? this.inviteError),
      invitesListStatus: invitesListStatus ?? this.invitesListStatus,
      invitesList: invitesList ?? this.invitesList,
      editStatus: editStatus ?? this.editStatus,
      editError: clearEditError ? null : (editError ?? this.editError),
      transferStatus: transferStatus ?? this.transferStatus,
      transferError:
          clearTransferError ? null : (transferError ?? this.transferError),
      leaveStatus: leaveStatus ?? this.leaveStatus,
      deleteStatus: deleteStatus ?? this.deleteStatus,
    );
  }
}
