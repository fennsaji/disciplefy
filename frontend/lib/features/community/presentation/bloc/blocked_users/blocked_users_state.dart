import 'package:equatable/equatable.dart';

import '../../../domain/entities/blocked_user_entity.dart';

enum BlockedUsersStatus { initial, loading, success, failure }

class BlockedUsersState extends Equatable {
  final BlockedUsersStatus status;
  final List<BlockedUserEntity> users;
  final String? errorMessage;

  const BlockedUsersState({
    this.status = BlockedUsersStatus.initial,
    this.users = const [],
    this.errorMessage,
  });

  BlockedUsersState copyWith({
    BlockedUsersStatus? status,
    List<BlockedUserEntity>? users,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) =>
      BlockedUsersState(
        status: status ?? this.status,
        users: users ?? this.users,
        errorMessage:
            clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      );

  @override
  List<Object?> get props => [status, users, errorMessage];
}
