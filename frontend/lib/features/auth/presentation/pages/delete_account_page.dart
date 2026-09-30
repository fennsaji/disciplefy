import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/widgets/settings_group.dart';

/// Public page explaining how to delete a Disciplefy account.
///
/// Required by Google Play Store to provide a publicly accessible URL
/// at https://app.disciplefy.in/delete-account.
/// Accessible without authentication. The English copy is intentional: the
/// page is reviewed by Google and linked from the Play listing.
class DeleteAccountPage extends StatelessWidget {
  const DeleteAccountPage({super.key});

  /// Address deletion requests are sent to.
  static const String contactEmail = 'contact@disciplefy.in';

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final red = SettingsToneColors.of(context, SettingsTone.red);

    return Scaffold(
      backgroundColor: palette.page,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(onBack: context.canPop() ? () => context.pop() : null),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Intro ──────────────────────────────────────────────
                    Text(
                      'Delete Your Disciplefy Account',
                      style: AppFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: palette.text,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Learn how to permanently delete your account and what happens to your data.',
                      style: AppFonts.inter(
                        fontSize: 14,
                        color: palette.muted,
                        height: 1.5,
                      ),
                    ),

                    // ── Permanent deletion warning ─────────────────────────
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: red.fill,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: red.foreground.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.warning_amber_rounded,
                                  color: red.foreground, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Permanent Deletion',
                                  style: AppFonts.poppins(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: red.foreground,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Account deletion is immediate and permanent. Once confirmed, your data cannot be recovered. There is no grace period or undo option.',
                            style: AppFonts.inter(
                              fontSize: 13.5,
                              color: palette.text,
                              height: 1.55,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── How to delete ──────────────────────────────────────
                    const _Eyebrow('How to Delete Your Account'),
                    _Card(
                      child: Column(
                        children: [
                          for (var i = 0; i < _deleteSteps.length; i++)
                            _NumberedStep(
                              number: i + 1,
                              text: _deleteSteps[i],
                              isLast: i == _deleteSteps.length - 1,
                            ),
                        ],
                      ),
                    ),

                    // ── What gets deleted ──────────────────────────────────
                    const _Eyebrow('What Gets Deleted'),
                    _Card(
                      child: Column(
                        children: [
                          for (var i = 0; i < _deletedItems.length; i++)
                            _DeletedItem(
                              text: _deletedItems[i],
                              isLast: i == _deletedItems.length - 1,
                            ),
                        ],
                      ),
                    ),

                    // ── What is kept ───────────────────────────────────────
                    const _Eyebrow('What Is Kept'),
                    _Card(
                      child: Text(
                        'Study guide content may be retained in anonymised form — your name and personal details are removed, but generated guide text may remain as shared content to benefit other users.',
                        style: AppFonts.inter(
                          fontSize: 14,
                          color: palette.muted,
                          height: 1.6,
                        ),
                      ),
                    ),

                    // ── Contact ────────────────────────────────────────────
                    const _Eyebrow('Questions?'),
                    _Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'If you have questions about account deletion or your data, contact us at:',
                            style: AppFonts.inter(
                              fontSize: 14,
                              color: palette.muted,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.mail_outline_rounded,
                                  size: 18, color: palette.accentIcon),
                              const SizedBox(width: 8),
                              Flexible(
                                child: SelectableText(
                                  contactEmail,
                                  style: AppFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: palette.accentIcon,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // ── Direct deletion request CTA ────────────────────────
                    const SizedBox(height: 28),
                    SettingsButton(
                      key: const ValueKey('delete-account-request'),
                      label: 'Request Account Deletion',
                      icon: Icons.delete_forever_rounded,
                      kind: SettingsButtonKind.destructive,
                      onPressed: _launchDeletionEmail,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Opens an email to request deletion if you no longer have the app',
                      textAlign: TextAlign.center,
                      style: AppFonts.inter(
                        fontSize: 12,
                        color: palette.muted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Mail link that requests deletion, for people without the app.
  static Uri get deletionEmailUri {
    const subject = 'Account Deletion Request';
    const body =
        'Hello,\n\nI would like to request the permanent deletion of my Disciplefy account and all associated data.\n\nRegistered email: \nReason (optional): \n\nThank you.';
    return Uri.parse(
      'mailto:$contactEmail'
      '?subject=${Uri.encodeComponent(subject)}'
      '&body=${Uri.encodeComponent(body)}',
    );
  }

  Future<void> _launchDeletionEmail() async {
    final uri = deletionEmailUri;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  static const List<String> _deleteSteps = [
    'Open the Disciplefy app on your device.',
    'Tap the Settings icon (bottom navigation or profile menu).',
    'Scroll down to the "Account Actions" section.',
    'Tap "Delete Account".',
    'Confirm the deletion in the dialog that appears.',
  ];

  static const List<String> _deletedItems = [
    'Profile — name, picture, and preferences',
    'All study guides and reading history',
    'Memory verses and review progress',
    'Subscription and payment records',
    'Fellowship memberships and posts',
    'Learning path progress',
    'All personal notes and reflections',
    'Google Calendar connection and access (if previously granted)',
  ];
}

// ── Helper widgets ────────────────────────────────────────────────────────────

/// Back arrow (only when there is somewhere to go back to) and the page title.
class _TopBar extends StatelessWidget {
  final VoidCallback? onBack;

  const _TopBar({required this.onBack});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return SizedBox(
      height: 64,
      child: Row(
        children: [
          if (onBack != null) ...[
            const SizedBox(width: 4),
            IconButton(
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              icon: Icon(Icons.arrow_back, color: palette.text, size: 22),
              onPressed: onBack,
            ),
            const SizedBox(width: 2),
          ] else
            const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Delete Account',
              maxLines: 2,
              style: AppFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: palette.text,
                height: 1.25,
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }
}

/// Gold tracked section label.
class _Eyebrow extends StatelessWidget {
  final String text;

  const _Eyebrow(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 24, 2, 8),
      child: Semantics(
        header: true,
        child: Text(
          text.toUpperCase(),
          style: AppFonts.inter(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
            color: ReaderPalette.of(context).gold,
          ),
        ),
      ),
    );
  }
}

/// Flat card: palette card fill with a hairline border.
class _Card extends StatelessWidget {
  final Widget child;

  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.hairline),
      ),
      child: child,
    );
  }
}

class _NumberedStep extends StatelessWidget {
  final int number;
  final String text;
  final bool isLast;

  const _NumberedStep({
    required this.number,
    required this.text,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: palette.raised,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: AppFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: palette.gold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                text,
                style: AppFonts.inter(
                  fontSize: 14,
                  color: palette.text,
                  height: 1.45,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeletedItem extends StatelessWidget {
  final String text;
  final bool isLast;

  const _DeletedItem({required this.text, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final red = SettingsToneColors.of(context, SettingsTone.red).foreground;
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(Icons.close_rounded, size: 16, color: red),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppFonts.inter(
                fontSize: 14,
                color: palette.text,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
