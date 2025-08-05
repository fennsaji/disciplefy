import 'package:equatable/equatable.dart';
import '../../domain/entities/user_profile_entity.dart';

/// States for user profile BLoC
/// Immutable states following BLoC pattern
abstract class UserProfileState extends Equatable {
  @override
  List<Object?> get props => [];
}

/// Initial state when BLoC is created
class UserProfileInitial extends UserProfileState {}

/// Loading state during async operations
class UserProfileLoading extends UserProfileState {}

/// State when profile is successfully loaded
class UserProfileLoaded extends UserProfileState {
  final UserProfileEntity profile;
  final bool isAdmin;

  UserProfileLoaded({
    required this.profile,
    this.isAdmin = false,
  });

  @override
  List<Object> get props => [profile, isAdmin];

  /// Creates a copy with updated values
  UserProfileLoaded copyWith({
    UserProfileEntity? profile,
    bool? isAdmin,
  }) =>
      UserProfileLoaded(
        profile: profile ?? this.profile,
        isAdmin: isAdmin ?? this.isAdmin,
      );
}

/// State when profile update is successful
class UserProfileUpdateSuccess extends UserProfileState {
  final UserProfileEntity updatedProfile;

  UserProfileUpdateSuccess({required this.updatedProfile});

  @override
  List<Object> get props => [updatedProfile];
}

/// State when profile deletion is successful
class UserProfileDeleteSuccess extends UserProfileState {}

/// State when language preference is updated
class LanguagePreferenceUpdated extends UserProfileState {
  final String newLanguage;

  LanguagePreferenceUpdated({required this.newLanguage});

  @override
  List<Object> get props => [newLanguage];
}

/// State when theme preference is updated
class ThemePreferenceUpdated extends UserProfileState {
  final String newTheme;

  ThemePreferenceUpdated({required this.newTheme});

  @override
  List<Object> get props => [newTheme];
}

/// Error state with detailed error information
class UserProfileError extends UserProfileState {
  final String message;
  final String? errorCode;

  UserProfileError({
    required this.message,
    this.errorCode,
  });

  @override
  List<Object?> get props => [message, errorCode];
}

/// Empty state when no profile exists
class UserProfileEmpty extends UserProfileState {
  final String userId;

  UserProfileEmpty({required this.userId});

  @override
  List<Object> get props => [userId];
}
