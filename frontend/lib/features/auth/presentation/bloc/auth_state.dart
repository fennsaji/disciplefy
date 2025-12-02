import 'package:equatable/equatable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/exceptions/auth_exceptions.dart';

/// Base class for all authentication states
/// Follows the BLoC pattern with immutable states
abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// Initial state before authentication is initialized
class AuthInitialState extends AuthState {
  const AuthInitialState();
}

/// State when authentication operations are in progress
class AuthLoadingState extends AuthState {
  const AuthLoadingState();
}

/// State when user is not authenticated
class UnauthenticatedState extends AuthState {
  const UnauthenticatedState();
}

/// State when user is successfully authenticated
class AuthenticatedState extends AuthState {
  final User user;
  final Map<String, dynamic>? profile;
  final bool isAnonymous;

  const AuthenticatedState({
    required this.user,
    this.profile,
    required this.isAnonymous,
  });

  @override
  List<Object?> get props => [user, profile, isAnonymous];

  /// Helper methods for common user data
  String get userId => user.id;
  String? get email => user.email;
  String? get displayName =>
      user.userMetadata?['full_name'] ?? user.userMetadata?['name'];
  String? get photoUrl =>
      user.userMetadata?['avatar_url'] ?? user.userMetadata?['picture'];

  /// Profile helpers
  String get languagePreference => profile?['language_preference'] ?? 'en';
  String get themePreference => profile?['theme_preference'] ?? 'light';
  bool get isAdmin => profile?['is_admin'] == true;
  DateTime? get profileCreatedAt => profile?['created_at'] != null
      ? DateTime.tryParse(profile!['created_at'])
      : null;
  DateTime? get profileUpdatedAt => profile?['updated_at'] != null
      ? DateTime.tryParse(profile!['updated_at'])
      : null;

  /// Creates a copy of this state with updated profile
  AuthenticatedState copyWithProfile(Map<String, dynamic>? newProfile) =>
      AuthenticatedState(
        user: user,
        profile: newProfile,
        isAnonymous: isAnonymous,
      );

  /// Checks if user needs to verify their email
  /// Returns true for email/password users who haven't verified their email yet
  /// Uses the email_verified field from user_profiles table
  bool get needsEmailVerification {
    // Anonymous users don't need verification
    if (isAnonymous) return false;

    // Check provider - Google and Apple users are pre-verified
    final provider = user.appMetadata['provider'] as String?;
    if (provider == 'google' || provider == 'apple') return false;

    // For email/password users, check the email_verified field in profile
    // This is set by a database trigger and updated when user clicks verification link
    return profile?['email_verified'] != true;
  }

  /// Helper to check if email is verified (from profile)
  bool get isEmailVerified => profile?['email_verified'] == true;
}

/// State when an authentication error occurs
class AuthErrorState extends AuthState {
  final String message;
  final String? errorCode;
  final ErrorSeverity severity;

  const AuthErrorState({
    required this.message,
    this.errorCode,
    this.severity = ErrorSeverity.error,
  });

  @override
  List<Object?> get props => [message, errorCode, severity];
}

/// State when user profile is being updated
class AuthProfileUpdatingState extends AuthState {
  const AuthProfileUpdatingState();
}

/// State when user profile update is successful
class AuthProfileUpdatedState extends AuthState {
  final String message;

  const AuthProfileUpdatedState({required this.message});

  @override
  List<Object?> get props => [message];
}

/// State when password reset email was sent successfully
class PasswordResetSentState extends AuthState {
  final String email;
  final String message;

  const PasswordResetSentState({
    required this.email,
    this.message = 'Password reset email sent. Please check your inbox.',
  });

  @override
  List<Object?> get props => [email, message];
}

/// State when verification email was sent successfully
class VerificationEmailSentState extends AuthState {
  final String email;
  final String message;

  const VerificationEmailSentState({
    required this.email,
    this.message = 'Verification email sent. Please check your inbox.',
  });

  @override
  List<Object?> get props => [email, message];
}
