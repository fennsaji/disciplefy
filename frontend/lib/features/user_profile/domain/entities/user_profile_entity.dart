import 'package:equatable/equatable.dart';

/// User profile entity containing user preferences and metadata
class UserProfileEntity extends Equatable {
  final String id;
  final String languagePreference;
  final String themePreference;

  /// User's first name, null if not provided
  final String? firstName;

  /// User's last name, null if not provided
  final String? lastName;

  /// URL or path to user's profile picture, null if not set
  final String? profilePicture;

  /// User's email address, null if not provided
  final String? email;

  /// User's phone number, null if not provided
  final String? phone;

  /// Whether user's email is verified (for email/password auth users)
  final bool emailVerified;

  final bool isAdmin;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserProfileEntity({
    required this.id,
    required this.languagePreference,
    required this.themePreference,

    /// User's first name, null if not provided
    this.firstName,

    /// User's last name, null if not provided
    this.lastName,

    /// URL or path to user's profile picture, null if not set
    this.profilePicture,

    /// User's email address, null if not provided
    this.email,

    /// User's phone number, null if not provided
    this.phone,

    /// Whether user's email is verified (for email/password auth users)
    this.emailVerified = false,
    required this.isAdmin,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create a copy of this entity with updated fields
  UserProfileEntity copyWith({
    String? id,
    String? languagePreference,
    String? themePreference,
    String? firstName,
    String? lastName,
    String? profilePicture,
    String? email,
    String? phone,
    bool? emailVerified,
    bool? isAdmin,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfileEntity(
      id: id ?? this.id,
      languagePreference: languagePreference ?? this.languagePreference,
      themePreference: themePreference ?? this.themePreference,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      profilePicture: profilePicture ?? this.profilePicture,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      emailVerified: emailVerified ?? this.emailVerified,
      isAdmin: isAdmin ?? this.isAdmin,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Create default user profile
  factory UserProfileEntity.defaultProfile(String userId) {
    final now = DateTime.now();
    return UserProfileEntity(
      id: userId,
      languagePreference: 'en',
      themePreference: 'light',
      isAdmin: false,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Get full name by combining first and last name
  String? get fullName {
    if (firstName == null && lastName == null) return null;
    if (firstName == null) return lastName;
    if (lastName == null) return firstName;
    return '$firstName $lastName';
  }

  /// Get display name with fallback to email
  String get displayName {
    final name = fullName;
    if (name != null && name.isNotEmpty) return name;
    if (email != null && email!.isNotEmpty) return email!;
    return 'User';
  }

  /// Check if user has a profile picture
  bool get hasProfilePicture =>
      profilePicture != null && profilePicture!.isNotEmpty;

  @override
  List<Object?> get props => [
        id,
        languagePreference,
        themePreference,
        firstName,
        lastName,
        profilePicture,
        email,
        phone,
        emailVerified,
        isAdmin,
        createdAt,
        updatedAt,
      ];
}
