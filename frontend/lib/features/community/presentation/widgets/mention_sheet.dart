import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/fellowship_entity.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/fellowship_member_entity.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/community_text_field.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/discipler_badges.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/member_avatar.dart';

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
  String initialQuery = '',
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
    builder: (sheetContext) =>
        _MentionSheet(candidates: candidates, initialQuery: initialQuery),
  );
}

/// Filters [candidates] by a typed query, matching the display name or the
/// handle. The Discipler helper always sorts first among the matches.
///
/// Matching ignores case and the dots that replace spaces in handles, so
/// "sa", "Saji" and "@Fenn.Sa" all find "Fenn Ignatius Saji".
List<MentionCandidate> filterMentionCandidates(
  List<MentionCandidate> candidates,
  String query,
) {
  final needle =
      query.replaceAll('@', '').replaceAll('.', '').trim().toLowerCase();
  if (needle.isEmpty) return candidates;
  return candidates.where((c) {
    final display = c.display.replaceAll('.', '').toLowerCase();
    final handle =
        c.handle.replaceAll('@', '').replaceAll('.', '').toLowerCase();
    return display.contains(needle) || handle.contains(needle);
  }).toList();
}

class _MentionSheet extends StatefulWidget {
  final List<MentionCandidate> candidates;

  /// The partial word already typed after `@` in the composer.
  final String initialQuery;

  const _MentionSheet({required this.candidates, this.initialQuery = ''});

  @override
  State<_MentionSheet> createState() => _MentionSheetState();
}

class _MentionSheetState extends State<_MentionSheet> {
  late final TextEditingController _search =
      TextEditingController(text: widget.initialQuery);
  late String _query = widget.initialQuery;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = ReaderPalette.of(context);
    final matches = filterMentionCandidates(widget.candidates, _query);
    return Padding(
      // Lift the sheet above the keyboard the search field opens.
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      // A Material, not a decorated box: the rows are ListTiles, which paint
      // their ink splashes on the nearest Material ancestor.
      child: Material(
        color: palette.card,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          side: BorderSide(color: palette.hairline),
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
          // A fellowship can have more members than fit on screen. Without a
          // bound the list overflowed and the sheet clipped its own top,
          // hiding Discipler — the row people reach for most.
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: palette.outline,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: TextField(
                    controller: _search,
                    autofocus: true,
                    onChanged: (value) => setState(() => _query = value),
                    style: AppFonts.inter(fontSize: 15, color: palette.text),
                    decoration: communityInputDecoration(
                      context,
                      pill: true,
                      hintText: l10n.mentionSearchHint,
                      prefixIcon: Icon(Icons.alternate_email_rounded,
                          size: 18, color: palette.muted),
                    ),
                  ),
                ),
                if (matches.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 24, horizontal: 16),
                    child: Text(
                      l10n.mentionNoMatches,
                      textAlign: TextAlign.center,
                      style: AppFonts.inter(fontSize: 14, color: palette.muted),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: matches.length,
                      itemBuilder: (context, index) =>
                          _MentionRow(candidate: matches[index]),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MentionRow extends StatelessWidget {
  final MentionCandidate candidate;

  const _MentionRow({required this.candidate});

  @override
  Widget build(BuildContext context) {
    final c = candidate;
    final palette = ReaderPalette.of(context);
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      minVerticalPadding: 10,
      leading: c.isDiscipler
          ? const DisciplerAvatar()
          : MemberAvatar(
              displayName: c.display,
              avatarUrl: c.avatarUrl,
            ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              c.display,
              style: AppFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: palette.text,
              ),
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
        style: AppFonts.inter(fontSize: 13, color: palette.muted),
      ),
      onTap: () => Navigator.of(context).pop(c),
    );
  }
}
