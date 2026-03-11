import 'package:equatable/equatable.dart';

/// Base class for all [DiscoverBloc] events.
abstract class DiscoverEvent extends Equatable {
  const DiscoverEvent();

  @override
  List<Object?> get props => [];
}

/// Loads (or reloads) public fellowships with optional language + search filters.
/// [language] null means all languages. [search] null means no text filter.
class DiscoverLoadRequested extends DiscoverEvent {
  final String? language;
  final String? search;

  const DiscoverLoadRequested({this.language, this.search});

  @override
  List<Object?> get props => [language, search];
}

/// Initiates joining a specific public fellowship.
class DiscoverJoinRequested extends DiscoverEvent {
  final String fellowshipId;
  final String fellowshipName;

  const DiscoverJoinRequested({
    required this.fellowshipId,
    required this.fellowshipName,
  });

  @override
  List<Object?> get props => [fellowshipId, fellowshipName];
}

/// Clears justJoinedName after the snackbar has been shown.
class DiscoverJoinAcknowledged extends DiscoverEvent {
  const DiscoverJoinAcknowledged();
}

/// Loads the next page of public fellowships using the stored cursor.
///
/// Ignored when [DiscoverState.hasMore] is false or a load-more is already
/// in flight ([DiscoverState.isLoadingMore] is true).
class DiscoverLoadMoreRequested extends DiscoverEvent {
  const DiscoverLoadMoreRequested();
}
