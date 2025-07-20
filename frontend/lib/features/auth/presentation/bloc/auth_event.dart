import 'package:equatable/equatable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Base class for all authentication events
/// Follows the BLoC pattern with immutable events
abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Event to initialize authentication state on app start
class AuthInitializeRequested extends AuthEvent {
  const AuthInitializeRequested();
}

/// Event to request Google OAuth sign-in
class GoogleSignInRequested extends AuthEvent {
  const GoogleSignInRequested();
}

/// Event to request anonymous sign-in
class AnonymousSignInRequested extends AuthEvent {
  const AnonymousSignInRequested();
}

/// Event to request sign-out
class SignOutRequested extends AuthEvent {
  const SignOutRequested();
}

/// Event triggered when authentication state changes externally
/// (e.g., from Supabase auth state stream)
class AuthStateChanged extends AuthEvent {
  final AuthState supabaseAuthState;

  const AuthStateChanged(this.supabaseAuthState);

  @override
  List<Object?> get props => [supabaseAuthState];
}

/// Event to request account deletion
class DeleteAccountRequested extends AuthEvent {
  const DeleteAccountRequested();
}

/// Event to process Google OAuth callback with authorization code
class GoogleOAuthCallbackRequested extends AuthEvent {
  final String code;
  final String? state;

  const GoogleOAuthCallbackRequested({
    required this.code,
    this.state,
  });

  @override
  List<Object?> get props => [code, state];
}

/// Event to update user profile preferences
class UpdateUserProfileRequested extends AuthEvent {
  final String languagePreference;
  final String themePreference;

  const UpdateUserProfileRequested({
    required this.languagePreference,
    this.themePreference = 'light',
  });

  @override
  List<Object?> get props => [languagePreference, themePreference];
}

/// Event to handle token refresh failure and force logout
class TokenRefreshFailed extends AuthEvent {
  final String reason;

  const TokenRefreshFailed({
    required this.reason,
  });

  @override
  List<Object?> get props => [reason];
}

/// Event to force logout and clear all data
class ForceLogoutRequested extends AuthEvent {
  final String reason;

  const ForceLogoutRequested({
    required this.reason,
  });

  @override
  List<Object?> get props => [reason];
}