import 'package:equatable/equatable.dart';

import '../../../../../features/community/domain/entities/public_fellowship_entity.dart';

/// Describes the load lifecycle for the discover screen.
enum DiscoverStatus { initial, loading, success, failure }

/// Single immutable state for [DiscoverBloc].
///
/// Use [copyWith] to produce updated snapshots; never mutate fields directly.
class DiscoverState extends Equatable {
  /// Load status of the public fellowships list.
  final DiscoverStatus status;

  /// The public fellowships available to join.
  final List<PublicFellowshipEntity> fellowships;

  /// The currently applied language filter; null means all languages.
  final String? language;

  /// The currently applied text search query; null means no filter.
  final String? search;

  /// IDs of fellowships currently being joined (in-flight requests).
  final Set<String> joiningIds;

  /// Non-null immediately after a successful join — consumed by the UI to
  /// show a snackbar, then cleared via [DiscoverJoinAcknowledged].
  final String? justJoinedName;

  /// Non-null when [status] is [DiscoverStatus.failure] or when a join fails.
  final String? errorMessage;

  /// Whether more pages are available to load.
  final bool hasMore;

  /// Cursor for the next page; null when there is no next page.
  final String? nextCursor;

  /// True while a load-more request is in flight.
  final bool isLoadingMore;

  const DiscoverState({
    this.status = DiscoverStatus.initial,
    this.fellowships = const [],
    this.language,
    this.search,
    this.joiningIds = const {},
    this.justJoinedName,
    this.errorMessage,
    this.hasMore = false,
    this.nextCursor,
    this.isLoadingMore = false,
  });

  /// Returns the initial seed state for [DiscoverBloc].
  const DiscoverState.initial() : this();

  @override
  List<Object?> get props => [
        status,
        fellowships,
        language,
        search,
        joiningIds,
        justJoinedName,
        errorMessage,
        hasMore,
        nextCursor,
        isLoadingMore,
      ];

  /// Creates a copy of this state with the provided fields replaced.
  ///
  /// To explicitly set a nullable field to null, wrap the value in a closure:
  /// ```dart
  /// state.copyWith(justJoinedName: () => null)
  /// ```
  DiscoverState copyWith({
    DiscoverStatus? status,
    List<PublicFellowshipEntity>? fellowships,
    String? Function()? language,
    String? Function()? search,
    Set<String>? joiningIds,
    String? Function()? justJoinedName,
    String? Function()? errorMessage,
    bool? hasMore,
    String? Function()? nextCursor,
    bool? isLoadingMore,
  }) {
    return DiscoverState(
      status: status ?? this.status,
      fellowships: fellowships ?? this.fellowships,
      language: language != null ? language() : this.language,
      search: search != null ? search() : this.search,
      joiningIds: joiningIds ?? this.joiningIds,
      justJoinedName:
          justJoinedName != null ? justJoinedName() : this.justJoinedName,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      hasMore: hasMore ?? this.hasMore,
      nextCursor: nextCursor != null ? nextCursor() : this.nextCursor,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}
