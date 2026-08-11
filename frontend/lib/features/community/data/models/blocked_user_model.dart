import '../../domain/entities/blocked_user_entity.dart';

/// Data-layer representation of a blocked user, parsed from the
/// `fellowship-blocks` GET response.
class BlockedUserModel extends BlockedUserEntity {
  const BlockedUserModel({
    required super.userId,
    required super.displayName,
    super.avatarUrl,
    required super.blockedAt,
  });

  factory BlockedUserModel.fromJson(Map<String, dynamic> json) =>
      BlockedUserModel(
        userId: json['user_id'] as String,
        displayName: (json['display_name'] as String?) ?? 'Unknown Member',
        avatarUrl: json['avatar_url'] as String?,
        blockedAt:
            DateTime.tryParse(json['blocked_at'] as String? ?? '')?.toLocal() ??
                DateTime.now(),
      );
}
