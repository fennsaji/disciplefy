import 'package:equatable/equatable.dart';

abstract class BlockedUsersEvent extends Equatable {
  const BlockedUsersEvent();
  @override
  List<Object?> get props => [];
}

/// Loads the current user's block list.
class BlockedUsersLoadRequested extends BlockedUsersEvent {
  const BlockedUsersLoadRequested();
}

/// Unblocks [userId] and removes them from the list.
class BlockedUserUnblockRequested extends BlockedUsersEvent {
  final String userId;
  const BlockedUserUnblockRequested(this.userId);
  @override
  List<Object?> get props => [userId];
}
