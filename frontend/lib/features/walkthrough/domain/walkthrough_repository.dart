// frontend/lib/features/walkthrough/domain/walkthrough_repository.dart

import 'walkthrough_screen.dart';

abstract class WalkthroughRepository {
  /// Returns true if the user has already seen this screen's walkthrough.
  Future<bool> hasSeen(WalkthroughScreen screen);

  /// Marks a screen as seen. Writes to Hive immediately, then fires-and-forgets
  /// a Supabase upsert. For anonymous users, writes to Hive only.
  Future<void> markSeen(WalkthroughScreen screen);

  /// Clears all seen flags. Awaits Supabase update before returning.
  /// Throws on Supabase failure so caller can show error to user.
  Future<void> resetAll();

  /// Merges remote walkthrough_seen array into local Hive cache (union).
  /// No-op for anonymous users. Falls back silently on network error.
  Future<void> syncFromRemote();

  /// Called after anonymous → full account conversion.
  /// Migrates local Hive state to Supabase as initial remote value.
  Future<void> migrateToRemote();
}
