import 'package:equatable/equatable.dart';

/// User profile entity representing user preferences and settings
/// Immutable entity following Clean Architecture principles
class UserProfileEntity extends Equatable {
  final String id;
  final String languagePreference;
  final String themePreference;
  final bool isAdmin;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  
  const UserProfileEntity({
    required this.id,
    required this.languagePreference,
    required this.themePreference,
    this.isAdmin = false,
    this.createdAt,
    this.updatedAt,
  });
  
  /// Creates a copy with updated values
  UserProfileEntity copyWith({
    String? id,
    String? languagePreference,
    String? themePreference,
    bool? isAdmin,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => UserProfileEntity(
      id: id ?? this.id,
      languagePreference: languagePreference ?? this.languagePreference,
      themePreference: themePreference ?? this.themePreference,
      isAdmin: isAdmin ?? this.isAdmin,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  
  /// Converts to map for database operations
  Map<String, dynamic> toMap() => {
      'id': id,
      'language_preference': languagePreference,
      'theme_preference': themePreference,
      'is_admin': isAdmin,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  
  /// Creates entity from map (database result)
  factory UserProfileEntity.fromMap(Map<String, dynamic> map) => UserProfileEntity(
      id: map['id'] as String,
      languagePreference: map['language_preference'] as String? ?? 'en',
      themePreference: map['theme_preference'] as String? ?? 'light',
      isAdmin: map['is_admin'] as bool? ?? false,
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'] as String) : null,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'] as String) : null,
    );
  
  @override
  List<Object?> get props => [id, languagePreference, themePreference, isAdmin, createdAt, updatedAt];
  
  @override
  String toString() => 'UserProfileEntity(id: $id, language: $languagePreference, theme: $themePreference, admin: $isAdmin)';
}