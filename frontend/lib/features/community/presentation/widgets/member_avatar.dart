import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';

/// A fellowship member's profile picture, falling back to their initials on a
/// solid colour circle.
///
/// Shared by the post card, the comments sheet and the fellowship cards: the
/// sheet used to draw its own initials-only circle, so a member with a photo
/// appeared as a letter the moment they commented — the same person, two
/// different faces on one screen. The fallback colour is derived from the
/// name, so a member keeps the same colour everywhere.
class MemberAvatar extends StatelessWidget {
  /// Used for the fallback initials and colour when there is no picture.
  final String displayName;

  /// No longer affects rendering: the fallback colour now comes from
  /// [displayName] so a member looks the same on every screen. Kept so
  /// existing callers compile; new callers should omit it.
  final Color? accentColor;

  /// Remote picture, or null/empty when the member has none.
  final String? avatarUrl;

  final double radius;

  const MemberAvatar({
    super.key,
    required this.displayName,
    this.accentColor,
    this.avatarUrl,
    this.radius = 20,
  });

  static const List<Color> _palette = [
    Color(0xFF6D28D9), // violet
    Color(0xFF0E7490), // teal
    Color(0xFFBE123C), // crimson
    Color(0xFF4F46E5), // indigo
    Color(0xFF047857), // green
    Color(0xFFB45309), // amber
    Color(0xFF1D4ED8), // blue
    Color(0xFFA21CAF), // magenta
  ];

  /// Up to two initials: first letters of the first two words.
  static String initialsOf(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    final first = String.fromCharCode(parts[0].runes.first);
    if (parts.length == 1) return first.toUpperCase();
    final second = String.fromCharCode(parts[1].runes.first);
    return '$first$second'.toUpperCase();
  }

  /// Stable fallback colour for [name] (not `String.hashCode`, which changes
  /// between runs).
  static Color colorFor(String name) {
    var hash = 0;
    for (final unit in name.trim().toLowerCase().codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return _palette[hash % _palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final hasPicture = avatarUrl != null && avatarUrl!.isNotEmpty;
    final initials = initialsOf(displayName);
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 2;
    final decodeSize = (radius * 2 * dpr).round();

    return CircleAvatar(
      radius: radius,
      backgroundColor: colorFor(displayName),
      backgroundImage: hasPicture
          ? ResizeImage(NetworkImage(avatarUrl!),
              width: decodeSize, policy: ResizeImagePolicy.fit)
          : null,
      onBackgroundImageError: hasPicture ? (_, __) {} : null,
      child: hasPicture
          ? null
          : Text(
              initials,
              maxLines: 1,
              style: AppFonts.inter(
                // Keeps the letters proportional at any radius callers use.
                fontSize: radius * (initials.length > 1 ? 0.62 : 0.75),
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
    );
  }
}
