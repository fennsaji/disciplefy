/// Domain-level repository interface for authentication session management
/// Abstracts Supabase authentication operations from domain layer
abstract class AuthSessionRepository {
  /// Sign out the current user and clear the session
  Future<void> signOut();

  /// Get the current authentication state
  bool get isSignedIn;

  /// Clear authentication session data
  Future<void> clearSession();
}
