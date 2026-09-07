import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';

/// Small "AI" chip appended next to the Discipler display name to signal
/// AI-generated content.
class DisciplerAiChip extends StatelessWidget {
  const DisciplerAiChip({super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: context.appPrimary,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          AppLocalizations.of(context)!.disciplerAiChip,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
      );
}

/// Avatar used for the Discipler AI helper wherever a post/comment author
/// avatar would normally appear.
class DisciplerAvatar extends StatelessWidget {
  final double radius;

  const DisciplerAvatar({this.radius = 20, super.key});

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;

    // The Discipler mark is a fixed brand asset — the Disciplefy symbol in gold
    // on ink, with the AI spark and its glow held inside the disc — so it is
    // rendered as-is rather than recoloured per theme.
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: Image.asset(
          'assets/brand/discipler-avatar.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

/// Small disclosure note shown under Discipler-authored content.
class DisciplerFooterNote extends StatelessWidget {
  const DisciplerFooterNote({super.key});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(Icons.info_outline_rounded,
              size: 12, color: context.appTextTertiary),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              AppLocalizations.of(context)!.disciplerFooter,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10,
                color: context.appTextTertiary,
              ),
            ),
          ),
        ],
      );
}
