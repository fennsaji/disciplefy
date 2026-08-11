import 'package:equatable/equatable.dart';

/// A user the current user has blocked.
///
/// Blocks are global and mutual: neither party sees the other's posts or
/// comments in any fellowship.
class BlockedUserEntity extends Equatable {
  /// Supabase auth UID of the blocked user.
  final String userId;

  /// Display name resolved server-side; 'Unknown Member' when unavailable.
  final String displayName;

  /// Avatar URL, or null when the user has none.
  final String? avatarUrl;

  /// When the block was created.
  final DateTime blockedAt;

  const BlockedUserEntity({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    required this.blockedAt,
  });

  @override
  List<Object?> get props => [userId, displayName, avatarUrl, blockedAt];
}
