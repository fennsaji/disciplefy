import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/core/utils/logger.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/widgets/settings_group.dart';

/// Top card of Settings: avatar, name, email and an edit-name action.
class SettingsProfileCard extends StatelessWidget {
  final String name;
  final String email;
  final String? photoUrl;
  final String editTooltip;
  final VoidCallback onEditName;

  const SettingsProfileCard({
    super.key,
    required this.name,
    required this.email,
    required this.editTooltip,
    required this.onEditName,
    this.photoUrl,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 6, 16),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.hairline),
      ),
      child: Row(
        children: [
          SettingsAvatar(name: name, photoUrl: photoUrl),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: palette.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.inter(fontSize: 12.5, color: palette.muted),
                ),
              ],
            ),
          ),
          // Nothing else in the app lets a user set their name: an
          // email/password signup that skipped the name field, or an account
          // created before this screen existed, is stuck showing its raw
          // email — in fellowship member lists too, since those read the same
          // auth metadata this dialog writes.
          IconButton(
            tooltip: editTooltip,
            onPressed: onEditName,
            icon:
                Icon(Icons.edit_outlined, size: 20, color: palette.accentIcon),
          ),
        ],
      ),
    );
  }
}

/// 52pt gold circle with the name's initial, or the profile photo.
class SettingsAvatar extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final double size;

  const SettingsAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.size = 52,
  });

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initial =
        trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase();
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: settingsPrimaryFill(context),
        shape: BoxShape.circle,
      ),
      child: Text(
        initial,
        style: AppFonts.poppins(
          fontSize: size * 0.38,
          fontWeight: FontWeight.w600,
          color: settingsPrimaryInk(context),
        ),
      ),
    );
    if (photoUrl == null) return fallback;

    final dpr = MediaQuery.devicePixelRatioOf(context);
    return ClipOval(
      child: Image.network(
        photoUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: (size * dpr).round(),
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : fallback,
        errorBuilder: (context, error, stackTrace) {
          Logger.error('[SETTINGS] Failed to load profile picture: $error');
          return fallback;
        },
      ),
    );
  }
}
