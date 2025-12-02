import '../../domain/entities/user_profile_entity.dart';

/// Data model for user profile with JSON serialization
class UserProfileModel extends UserProfileEntity {
  const UserProfileModel({
    required super.id,
    required super.languagePreference,
    required super.themePreference,
    super.firstName,
    super.lastName,
    super.profilePicture,
    super.email,
    super.phone,
    super.emailVerified,
    required super.isAdmin,
    required super.createdAt,
    required super.updatedAt,
  });

  /// Create UserProfileModel from JSON
  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      id: json['id'] as String,
      languagePreference: json['language_preference'] as String? ?? 'en',
      themePreference: json['theme_preference'] as String? ?? 'light',
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      profilePicture: json['profile_picture'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      emailVerified: json['email_verified'] as bool? ?? false,
      isAdmin: json['is_admin'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Convert UserProfileModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'language_preference': languagePreference,
      'theme_preference': themePreference,
      'first_name': firstName,
      'last_name': lastName,
      'profile_picture': profilePicture,
      'email': email,
      'phone': phone,
      'email_verified': emailVerified,
      'is_admin': isAdmin,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Create UserProfileModel from UserProfileEntity
  factory UserProfileModel.fromEntity(UserProfileEntity entity) {
    return UserProfileModel(
      id: entity.id,
      languagePreference: entity.languagePreference,
      themePreference: entity.themePreference,
      firstName: entity.firstName,
      lastName: entity.lastName,
      profilePicture: entity.profilePicture,
      email: entity.email,
      phone: entity.phone,
      emailVerified: entity.emailVerified,
      isAdmin: entity.isAdmin,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  /// Convert to UserProfileEntity
  UserProfileEntity toEntity() {
    return UserProfileEntity(
      id: id,
      languagePreference: languagePreference,
      themePreference: themePreference,
      firstName: firstName,
      lastName: lastName,
      profilePicture: profilePicture,
      email: email,
      phone: phone,
      emailVerified: emailVerified,
      isAdmin: isAdmin,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Create a copy with updated fields
  @override
  UserProfileModel copyWith({
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
    return UserProfileModel(
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

  /// Create UserProfileModel from Map (for API responses)
  factory UserProfileModel.fromMap(Map<String, dynamic> map) {
    return UserProfileModel(
      id: map['id'] as String,
      languagePreference: map['language_preference'] as String? ?? 'en',
      themePreference: map['theme_preference'] as String? ?? 'light',
      firstName: map['first_name'] as String?,
      lastName: map['last_name'] as String?,
      profilePicture: map['profile_picture'] as String?,
      email: map['email'] as String?,
      phone: map['phone'] as String?,
      emailVerified: map['email_verified'] as bool? ?? false,
      isAdmin: map['is_admin'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  /// Convert UserProfileModel to Map (for API requests)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'language_preference': languagePreference,
      'theme_preference': themePreference,
      'email_verified': emailVerified,
      'is_admin': isAdmin,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Create default user profile model
  factory UserProfileModel.defaultProfile(String userId) {
    final now = DateTime.now();
    return UserProfileModel(
      id: userId,
      languagePreference: 'en',
      themePreference: 'light',
      isAdmin: false,
      createdAt: now,
      updatedAt: now,
    );
  }
}
