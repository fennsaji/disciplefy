import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/fellowship_member_entity.dart';
import 'package:disciplefy_bible_study/features/community/presentation/utils/mentor_contact_helpers.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/community_buttons.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/member_avatar.dart';
import 'package:disciplefy_bible_study/shared/widgets/popup.dart';

/// Opens a bottom sheet listing every mentor who has set a contact channel,
/// each with a button to WhatsApp or email them directly.
///
/// [parentContext] is used to launch the contact app and show the failure
/// snackbar — the sheet's own context is gone once it is popped.
void showMentorContactSheet(
  BuildContext parentContext, {
  required List<FellowshipMemberEntity> mentorsWithContact,
  required String fellowshipName,
}) {
  showModalBottomSheet<void>(
    useRootNavigator: true,
    context: parentContext,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _MentorContactSheet(
      mentors: mentorsWithContact,
      fellowshipName: fellowshipName,
      parentContext: parentContext,
    ),
  );
}

class _MentorContactSheet extends StatelessWidget {
  final List<FellowshipMemberEntity> mentors;
  final String fellowshipName;
  final BuildContext parentContext;

  const _MentorContactSheet({
    required this.mentors,
    required this.fellowshipName,
    required this.parentContext,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = ReaderPalette.of(context);
    return PopupSheet(
      children: [
        Text(
          l10n.messageMentorTitle,
          style: AppFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: palette.text,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 8),
        for (final mentor in mentors)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            // Identity on its own line above the actions: a mentor who
            // offers both channels would otherwise squeeze their own name
            // out of a single row.
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    MemberAvatar(
                      displayName: mentor.displayName,
                      avatarUrl: mentor.avatarUrl,
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        mentor.displayName,
                        style: AppFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: palette.text,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: palette.gold
                            .withValues(alpha: palette.isDark ? 0.18 : 0.14),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        l10n.mentorLabel,
                        style: AppFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: palette.gold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 52),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (mentor.mentorWhatsapp != null &&
                          mentor.mentorWhatsapp!.isNotEmpty)
                        CommunityRaisedPill(
                          icon: Icons.chat_bubble_outline,
                          label: l10n.contactWhatsapp,
                          onPressed: () {
                            Navigator.of(context).pop();
                            launchMentorContact(
                              parentContext,
                              contactType: 'whatsapp',
                              contactValue: mentor.mentorWhatsapp!,
                              fellowshipName: fellowshipName,
                            );
                          },
                        ),
                      if (mentor.mentorEmail != null &&
                          mentor.mentorEmail!.isNotEmpty)
                        CommunityRaisedPill(
                          icon: Icons.email_outlined,
                          label: l10n.contactEmail,
                          onPressed: () {
                            Navigator.of(context).pop();
                            launchMentorContact(
                              parentContext,
                              contactType: 'email',
                              contactValue: mentor.mentorEmail!,
                              fellowshipName: fellowshipName,
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
