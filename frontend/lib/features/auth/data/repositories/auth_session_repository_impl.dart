import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/repositories/auth_session_repository.dart';

/// Implementation of AuthSessionRepository that wraps Supabase authentication
/// Isolates Supabase SDK from domain layer following Clean Architecture
class AuthSessionRepositoryImpl implements AuthSessionRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  @override
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
      if (kDebugMode) {
        print('🔐 [AUTH SESSION] ✅ User signed out successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('🔐 [AUTH SESSION] ❌ Error signing out: $e');
      }
      rethrow;
    }
  }

  @override
  bool get isSignedIn => _supabase.auth.currentUser != null;

  @override
  Future<void> clearSession() async {
    try {
      await _supabase.auth.signOut();
      if (kDebugMode) {
        print('🔐 [AUTH SESSION] ✅ Session cleared successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('🔐 [AUTH SESSION] ❌ Error clearing session: $e');
      }
      rethrow;
    }
  }
}
