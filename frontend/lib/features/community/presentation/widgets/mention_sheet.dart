import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/fellowship_entity.dart';
import '../../domain/entities/fellowship_member_entity.dart';
import 'discipler_badges.dart';

/// A single row in the `@mention` picker sheet — either the Discipler AI
/// helper or a fellowship mentor.
class MentionCandidate {
  /// The `@Handle` token inserted into the composer text.
  final String handle;

  /// The account this handle refers to, or null for the Discipler helper.
  ///
  /// Sent to the backend so the mention push reaches the right person:
  /// display names are neither unique nor stable, so resolving the handle
  /// back to an account server-side would be guesswork.
  final String? userId;

  /// Display name shown in the row.
  final String display;

  /// Secondary line shown under [display].
  final String subtitle;

  /// True when this row represents the Discipler AI helper.
  final bool isDiscipler;

  /// Avatar image URL, or null to fall back to the initial/AI icon.
  final String? avatarUrl;

  const MentionCandidate({
    required this.handle,
    this.userId,
    required this.display,
    required this.subtitle,
    required this.isDiscipler,
    this.avatarUrl,
  });
}

/// Opens a bottom sheet listing mentionable targets: the Discipler AI helper
/// (when [disciplerAllowed]), then mentors, then everyone else in the
/// fellowship.
///
/// [members] may be empty while the member list is still loading, in which
/// case only [mentors] are offered.
///
/// Returns the selected [MentionCandidate], or `null` if dismissed.
Future<MentionCandidate?> showMentionSheet(
  BuildContext context, {
  required bool disciplerAllowed,
  required List<FellowshipMentorEntity> mentors,
  List<FellowshipMemberEntity> members = const [],
  String? currentUserId,
}) {
  final l10n = AppLocalizations.of(context)!;
  final candidates = <MentionCandidate>[
    if (disciplerAllowed)
      MentionCandidate(
        handle: '@Discipler',
        display: l10n.disciplerName,
        subtitle: l10n.disciplerMentionSubtitle,
        isDiscipler: true,
      ),
    for (final mentor in mentors)
      MentionCandidate(
        handle: '@${mentor.displayName.replaceAll(RegExp(r'\s+'), '.')}',
        userId: mentor.userId,
        display: mentor.displayName,
        subtitle: l10n.mentorLabel,
        isDiscipler: false,
        avatarUrl: mentor.avatarUrl,
      ),
    // Everyone else. Mentors are already listed above, and tagging yourself
    // notifies nobody, so both are skipped here.
    for (final member in members)
      if (member.role != 'mentor' &&
          member.userId != currentUserId &&
          !mentors.any((m) => m.userId == member.userId))
        MentionCandidate(
          handle: '@${member.displayName.replaceAll(RegExp(r'\s+'), '.')}',
          userId: member.userId,
          display: member.displayName,
          subtitle: l10n.memberLabel,
          isDiscipler: false,
          avatarUrl: member.avatarUrl,
        ),
  ];

  return showModalBottomSheet<MentionCandidate>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _MentionSheet(candidates: candidates),
  );
}

class _MentionSheet extends StatelessWidget {
  final List<MentionCandidate> candidates;

  const _MentionSheet({required this.candidates});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: context.appBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            if (candidates.isEmpty)
              const SizedBox.shrink()
            else
              ...candidates.map(
                (c) => ListTile(
                  leading: c.isDiscipler
                      ? const DisciplerAvatar(radius: 18)
                      : CircleAvatar(
                          radius: 18,
                          backgroundColor: context.appPrimary.withAlpha(36),
                          backgroundImage:
                              c.avatarUrl != null && c.avatarUrl!.isNotEmpty
                                  ? NetworkImage(c.avatarUrl!)
                                  : null,
                          child: c.avatarUrl == null || c.avatarUrl!.isEmpty
                              ? Text(
                                  c.display.isNotEmpty
                                      ? c.display[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w700,
                                    color: context.appPrimary,
                                  ),
                                )
                              : null,
                        ),
                  title: Row(
                    children: [
                      Flexible(
                        child: Text(
                          c.display,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                            color: context.appTextPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (c.isDiscipler) ...[
                        const SizedBox(width: 6),
                        const DisciplerAiChip(),
                      ],
                    ],
                  ),
                  subtitle: Text(
                    c.subtitle,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: context.appTextTertiary,
                    ),
                  ),
                  onTap: () => Navigator.of(context).pop(c),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
