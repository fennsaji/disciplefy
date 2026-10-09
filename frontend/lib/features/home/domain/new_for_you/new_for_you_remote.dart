import 'package:disciplefy_bible_study/features/home/domain/new_for_you/new_for_you_scheduler.dart';

/// The server's copy of the "New for you" state after a sync.
class NewForYouSync {
  /// The merged state. Its retired kinds include every feature the person
  /// has tried, worked out on the server from their data.
  final NewForYouState state;

  /// When the person started (account or guest creation), or null.
  final DateTime? startedAt;

  const NewForYouSync({required this.state, this.startedAt});
}

/// Keeps the "New for you" state on the server, per signed-in user, so it
/// follows them across sessions and devices.
abstract class NewForYouRemote {
  /// Merges [local] into the signed-in user's server copy and returns the
  /// result. Throws when the server cannot be reached.
  Future<NewForYouSync> sync(NewForYouState local);
}
