import 'package:equatable/equatable.dart';

/// Base class for all [FellowshipMembersBloc] events.
abstract class FellowshipMembersEvent extends Equatable {
  const FellowshipMembersEvent();

  @override
  List<Object?> get props => [];
}

/// Initializes the bloc with context from [FellowshipHomeScreen].
class FellowshipMembersInitialized extends FellowshipMembersEvent {
  final bool isMentor;
  final String fellowshipId;
  final String? currentUserId;

  const FellowshipMembersInitialized({
    required this.isMentor,
    required this.fellowshipId,
    this.currentUserId,
  });

  @override
  List<Object?> get props => [isMentor, fellowshipId, currentUserId];
}

/// Loads (or reloads) the member list for the given fellowship.
class FellowshipMembersLoadRequested extends FellowshipMembersEvent {
  final String fellowshipId;

  const FellowshipMembersLoadRequested({required this.fellowshipId});

  @override
  List<Object?> get props => [fellowshipId];
}

/// Generates a new invite token for the fellowship.
class FellowshipMembersInviteRequested extends FellowshipMembersEvent {
  const FellowshipMembersInviteRequested();
}

/// Mutes [userId] in the fellowship (mentor only).
class FellowshipMembersMuteRequested extends FellowshipMembersEvent {
  final String userId;

  const FellowshipMembersMuteRequested({required this.userId});

  @override
  List<Object?> get props => [userId];
}

/// Unmutes [userId] in the fellowship (mentor only).
class FellowshipMembersUnmuteRequested extends FellowshipMembersEvent {
  final String userId;

  const FellowshipMembersUnmuteRequested({required this.userId});

  @override
  List<Object?> get props => [userId];
}

/// The current user leaves the fellowship.
class FellowshipLeaveRequested extends FellowshipMembersEvent {
  const FellowshipLeaveRequested();
}

/// Mentor requests to update fellowship settings.
class FellowshipEditRequested extends FellowshipMembersEvent {
  final String? name;
  final String? description;
  final int? maxMembers;

  const FellowshipEditRequested({this.name, this.description, this.maxMembers});

  @override
  List<Object?> get props => [name, description, maxMembers];
}

/// Loads the list of active invite links for this fellowship (mentor only).
class FellowshipInvitesListRequested extends FellowshipMembersEvent {
  const FellowshipInvitesListRequested();
}

/// Mentor revokes the invite identified by [inviteId].
class FellowshipInviteRevokeRequested extends FellowshipMembersEvent {
  final String inviteId;

  const FellowshipInviteRevokeRequested({required this.inviteId});

  @override
  List<Object?> get props => [inviteId];
}

/// Mentor removes (kicks) a member from the fellowship.
class FellowshipMembersRemoveRequested extends FellowshipMembersEvent {
  final String userId;

  const FellowshipMembersRemoveRequested({required this.userId});

  @override
  List<Object?> get props => [userId];
}

/// Mentor permanently deletes the fellowship.
class FellowshipDeleteRequested extends FellowshipMembersEvent {
  const FellowshipDeleteRequested();
}

/// Mentor transfers the mentor role to [newMentorUserId].
class FellowshipTransferMentorRequested extends FellowshipMembersEvent {
  final String newMentorUserId;

  const FellowshipTransferMentorRequested({required this.newMentorUserId});

  @override
  List<Object?> get props => [newMentorUserId];
}
