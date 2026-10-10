import 'dart:async';

import 'package:equatable/equatable.dart';

/// Events of the All paths page.
sealed class AllPathsEvent extends Equatable {
  const AllPathsEvent();

  @override
  List<Object?> get props => [];
}

/// The page opened: list the first page and every category.
class AllPathsOpened extends AllPathsEvent {
  final String language;

  /// Category chip selected on open; "All" when null.
  final String? category;

  const AllPathsOpened({required this.language, this.category});

  @override
  List<Object?> get props => [language, category];
}

/// The content language changed: the list is dropped and listed again.
class AllPathsLanguageChanged extends AllPathsEvent {
  final String language;

  const AllPathsLanguageChanged(this.language);

  @override
  List<Object?> get props => [language];
}

/// A category chip was tapped ("All" when [category] is null). Clears any
/// search: a search covers every path.
class AllPathsCategorySelected extends AllPathsEvent {
  final String? category;

  const AllPathsCategorySelected(this.category);

  @override
  List<Object?> get props => [category];
}

/// The (debounced) search text changed; empty lists the paths again.
class AllPathsSearchChanged extends AllPathsEvent {
  final String query;

  const AllPathsSearchChanged(this.query);

  @override
  List<Object?> get props => [query];
}

/// The list neared its end. A page that failed is only asked again when
/// [retry] is set (the footer's Retry), never by scrolling.
class AllPathsMoreRequested extends AllPathsEvent {
  final bool retry;

  const AllPathsMoreRequested({this.retry = false});

  @override
  List<Object?> get props => [retry];
}

/// Pull-to-refresh, or back from a path whose progress changed: the list
/// stays on screen until the fresh first page replaces it. [done] completes
/// when the refresh has finished either way.
class AllPathsRefreshed extends AllPathsEvent {
  final Completer<void>? done;

  const AllPathsRefreshed({this.done});
}

/// Retry after the first page failed.
class AllPathsRetried extends AllPathsEvent {
  const AllPathsRetried();
}
