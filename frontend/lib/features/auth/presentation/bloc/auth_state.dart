import 'package:equatable/equatable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  String? get displayName => user.userMetadata?['full_name'] ?? user.userMetadata?['name'];
  String? get photoUrl => user.userMetadata?['avatar_url'] ?? user.userMetadata?['picture'];
  
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
  AuthenticatedState copyWithProfile(Map<String, dynamic>? newProfile) {
    return AuthenticatedState(
      user: user,
      profile: newProfile,
      isAnonymous: isAnonymous,
    );
  }
}

/// State when an authentication error occurs
class AuthErrorState extends AuthState {
  final String message;
  final String? errorCode;

  const AuthErrorState({
    required this.message,
    this.errorCode,
  });

  @override
  List<Object?> get props => [message, errorCode];
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