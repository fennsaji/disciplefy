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
  Widget build(BuildContext context) => CircleAvatar(
        radius: radius,
        backgroundColor: context.appPrimary,
        child: Icon(
          Icons.auto_awesome_rounded,
          color: Colors.white,
          size: radius,
        ),
      );
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
