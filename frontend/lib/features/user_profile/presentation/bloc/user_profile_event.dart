import 'package:equatable/equatable.dart';
import '../../domain/entities/user_profile_entity.dart';

/// Events for user profile BLoC
/// Handles all user profile related actions
abstract class UserProfileEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

/// Event to load user profile data
class LoadUserProfileEvent extends UserProfileEvent {
  final String userId;

  LoadUserProfileEvent({required this.userId});

  @override
  List<Object> get props => [userId];
}

/// Event to update user profile
class UpdateUserProfileEvent extends UserProfileEvent {
  final UserProfileEntity profile;

  UpdateUserProfileEvent({required this.profile});

  @override
  List<Object> get props => [profile];
}

/// Event to delete user profile
class DeleteUserProfileEvent extends UserProfileEvent {
  final String userId;

  DeleteUserProfileEvent({required this.userId});

  @override
  List<Object> get props => [userId];
}

/// Event to update language preference
class UpdateLanguagePreferenceEvent extends UserProfileEvent {
  final String userId;
  final String languageCode;

  UpdateLanguagePreferenceEvent({
    required this.userId,
    required this.languageCode,
  });

  @override
  List<Object> get props => [userId, languageCode];
}

/// Event to update theme preference
class UpdateThemePreferenceEvent extends UserProfileEvent {
  final String userId;
  final String theme;

  UpdateThemePreferenceEvent({
    required this.userId,
    required this.theme,
  });

  @override
  List<Object> get props => [userId, theme];
}

/// Event to check admin status
class CheckAdminStatusEvent extends UserProfileEvent {
  final String userId;

  CheckAdminStatusEvent({required this.userId});

  @override
  List<Object> get props => [userId];
}
