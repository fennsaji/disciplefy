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

/// State when OTP has been sent to phone or email
class OTPSentState extends AuthState {
  final String identifier; // phone number or email
  final String method; // 'phone' or 'email'
  final String message;

  const OTPSentState({
    required this.identifier,
    required this.method,
    required this.message,
  });

  @override
  List<Object?> get props => [identifier, method, message];
}

/// State when OTP verification is in progress
class OTPVerifyingState extends AuthState {
  final String identifier;
  final String method;

  const OTPVerifyingState({
    required this.identifier,
    required this.method,
  });

  @override
  List<Object?> get props => [identifier, method];
}

/// State when user needs to complete their profile (first-time users)
class ProfileIncompleteState extends AuthState {
  final User user;
  final bool isFirstTime;
  final String? tempProfilePicturePath;

  const ProfileIncompleteState({
    required this.user,
    required this.isFirstTime,
    this.tempProfilePicturePath,
  });

  @override
  List<Object?> get props => [user, isFirstTime, tempProfilePicturePath];

  /// Helper methods
  String get userId => user.id;
  String? get email => user.email;
  String? get phone => user.phone;
}

/// State when profile picture is being uploaded
class ProfilePictureUploadingState extends AuthState {
  final String userId;
  final double progress; // 0.0 to 1.0

  const ProfilePictureUploadingState({
    required this.userId,
    this.progress = 0.0,
  });

  @override
  List<Object?> get props => [userId, progress];
}

/// State when profile completion is in progress
class ProfileCompletingState extends AuthState {
  final String userId;

  const ProfileCompletingState({required this.userId});

  @override
  List<Object?> get props => [userId];
}
