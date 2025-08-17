import '../../domain/entities/user_profile_entity.dart';

/// Data model for user profile with JSON serialization
class UserProfileModel extends UserProfileEntity {
  const UserProfileModel({
    required super.id,
    required super.languagePreference,
    required super.themePreference,
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
    bool? isAdmin,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfileModel(
      id: id ?? this.id,
      languagePreference: languagePreference ?? this.languagePreference,
      themePreference: themePreference ?? this.themePreference,
      isAdmin: isAdmin ?? this.isAdmin,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
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
