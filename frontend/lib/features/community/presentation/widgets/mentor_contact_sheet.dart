import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/fellowship_member_entity.dart';
import '../utils/mentor_contact_helpers.dart';

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
    return Container(
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
            Text(
              l10n.messageMentorTitle,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.appTextPrimary,
              ),
            ),
            const SizedBox(height: 12),
            for (final mentor in mentors)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                // Identity on its own line above the actions: a mentor who
                // offers both channels would otherwise squeeze their own name
                // out of a single row.
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: context.appPrimary.withAlpha(36),
                          backgroundImage: mentor.avatarUrl != null &&
                                  mentor.avatarUrl!.isNotEmpty
                              ? NetworkImage(mentor.avatarUrl!)
                              : null,
                          child: mentor.avatarUrl == null ||
                                  mentor.avatarUrl!.isEmpty
                              ? Text(
                                  mentor.displayName.isNotEmpty
                                      ? mentor.displayName[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w700,
                                    color: context.appPrimary,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            mentor.displayName,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w600,
                              color: context.appTextPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: context.appPrimary.withAlpha(30),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            l10n.mentorLabel,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: context.appPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(left: 46),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (mentor.mentorWhatsapp != null &&
                              mentor.mentorWhatsapp!.isNotEmpty)
                            OutlinedButton.icon(
                              onPressed: () {
                                Navigator.of(context).pop();
                                launchMentorContact(
                                  parentContext,
                                  contactType: 'whatsapp',
                                  contactValue: mentor.mentorWhatsapp!,
                                  fellowshipName: fellowshipName,
                                );
                              },
                              icon: const Icon(Icons.chat_bubble_outline,
                                  size: 16),
                              label: Text(l10n.contactWhatsapp),
                            ),
                          if (mentor.mentorEmail != null &&
                              mentor.mentorEmail!.isNotEmpty)
                            OutlinedButton.icon(
                              onPressed: () {
                                Navigator.of(context).pop();
                                launchMentorContact(
                                  parentContext,
                                  contactType: 'email',
                                  contactValue: mentor.mentorEmail!,
                                  fellowshipName: fellowshipName,
                                );
                              },
                              icon: const Icon(Icons.email_outlined, size: 16),
                              label: Text(l10n.contactEmail),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
