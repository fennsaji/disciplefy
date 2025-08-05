import 'package:equatable/equatable.dart';

class UserEntity extends Equatable {
  final String id;
  final String? email;
  final String? name;
  final String? avatarUrl;
  final String authProvider;
  final String languagePreference;
  final String themePreference;
  final bool isAnonymous;
  final DateTime createdAt;
  final DateTime? lastSignInAt;

  const UserEntity({
    required this.id,
    this.email,
    this.name,
    this.avatarUrl,
    required this.authProvider,
    required this.languagePreference,
    required this.themePreference,
    required this.isAnonymous,
    required this.createdAt,
    this.lastSignInAt,
  });

  @override
  List<Object?> get props => [
        id,
        email,
        name,
        avatarUrl,
        authProvider,
        languagePreference,
        themePreference,
        isAnonymous,
        createdAt,
        lastSignInAt,
      ];

  UserEntity copyWith({
    String? id,
    String? email,
    String? name,
    String? avatarUrl,
    String? authProvider,
    String? languagePreference,
    String? themePreference,
    bool? isAnonymous,
    DateTime? createdAt,
    DateTime? lastSignInAt,
  }) =>
      UserEntity(
        id: id ?? this.id,
        email: email ?? this.email,
        name: name ?? this.name,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        authProvider: authProvider ?? this.authProvider,
        languagePreference: languagePreference ?? this.languagePreference,
        themePreference: themePreference ?? this.themePreference,
        isAnonymous: isAnonymous ?? this.isAnonymous,
        createdAt: createdAt ?? this.createdAt,
        lastSignInAt: lastSignInAt ?? this.lastSignInAt,
      );
}
