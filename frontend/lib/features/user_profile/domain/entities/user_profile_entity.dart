import 'package:equatable/equatable.dart';

/// User profile entity containing user preferences and metadata
class UserProfileEntity extends Equatable {
  final String id;
  final String languagePreference;
  final String themePreference;
  final bool isAdmin;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserProfileEntity({
    required this.id,
    required this.languagePreference,
    required this.themePreference,
    required this.isAdmin,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create a copy of this entity with updated fields
  UserProfileEntity copyWith({
    String? id,
    String? languagePreference,
    String? themePreference,
    bool? isAdmin,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfileEntity(
      id: id ?? this.id,
      languagePreference: languagePreference ?? this.languagePreference,
      themePreference: themePreference ?? this.themePreference,
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

  /// Create entity from map (for API responses)
  factory UserProfileEntity.fromMap(Map<String, dynamic> map) {
    return UserProfileEntity(
      id: map['id'] as String,
      languagePreference: map['language_preference'] as String? ?? 'en',
      themePreference: map['theme_preference'] as String? ?? 'light',
      isAdmin: map['is_admin'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  /// Convert entity to map (for API requests)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'language_preference': languagePreference,
      'theme_preference': themePreference,
      'is_admin': isAdmin,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
        id,
        languagePreference,
        themePreference,
        isAdmin,
        createdAt,
        updatedAt,
      ];
}
