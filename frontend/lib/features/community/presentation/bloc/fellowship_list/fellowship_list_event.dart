import 'package:equatable/equatable.dart';

/// Base class for all [FellowshipListBloc] events.
abstract class FellowshipListEvent extends Equatable {
  const FellowshipListEvent();

  @override
  List<Object?> get props => [];
}

/// Requests the initial load (or a refresh) of the user's fellowships.
class FellowshipListLoadRequested extends FellowshipListEvent {
  const FellowshipListLoadRequested();
}

/// Requests joining a fellowship via an invite token.
class FellowshipJoinRequested extends FellowshipListEvent {
  /// The invite token received from a deep-link or manual entry.
  final String inviteToken;

  const FellowshipJoinRequested({required this.inviteToken});

  @override
  List<Object?> get props => [inviteToken];
}

/// Requests creating a new fellowship.
class FellowshipCreateRequested extends FellowshipListEvent {
  final String name;
  final String? description;
  final int? maxMembers;
  final bool isPublic;
  final String language;

  const FellowshipCreateRequested({
    required this.name,
    this.description,
    this.maxMembers,
    this.isPublic = false,
    this.language = 'en',
  });

  @override
  List<Object?> get props =>
      [name, description, maxMembers, isPublic, language];
}
