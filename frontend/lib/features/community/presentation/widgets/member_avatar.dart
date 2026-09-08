import 'package:flutter/material.dart';

/// A fellowship member's profile picture, falling back to their initial.
///
/// Shared by the post card and the comments sheet: the sheet used to draw its
/// own initials-only circle, so a member with a photo appeared as a letter the
/// moment they commented — the same person, two different faces on one screen.
class MemberAvatar extends StatelessWidget {
  /// Used for the fallback initial when there is no picture.
  final String displayName;

  /// Tint for the fallback circle and its letter.
  final Color accentColor;

  /// Remote picture, or null/empty when the member has none.
  final String? avatarUrl;

  final double radius;

  const MemberAvatar({
    super.key,
    required this.displayName,
    required this.accentColor,
    this.avatarUrl,
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    final hasPicture = avatarUrl != null && avatarUrl!.isNotEmpty;
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    return CircleAvatar(
      radius: radius,
      backgroundColor: accentColor.withAlpha(36),
      backgroundImage: hasPicture ? NetworkImage(avatarUrl!) : null,
      child: hasPicture
          ? null
          : Text(
              initial,
              style: TextStyle(
                fontFamily: 'Inter',
                // Keeps the letter proportional at any radius the callers use.
                fontSize: radius * 0.75,
                fontWeight: FontWeight.w700,
                color: accentColor,
              ),
            ),
    );
  }
}
