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
