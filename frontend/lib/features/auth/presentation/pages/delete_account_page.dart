import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_colors.dart';

/// Public page explaining how to delete a Disciplefy account.
///
/// Required by Google Play Store to provide a publicly accessible URL
/// at https://app.disciplefy.in/delete-account.
/// Accessible without authentication.
class DeleteAccountPage extends StatelessWidget {
  const DeleteAccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final cardColor = isDark ? AppColors.darkSurface : Colors.white;
    final scaffoldBg =
        isDark ? AppColors.darkScaffold : AppColors.lightScaffold;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: scaffoldBg,
        elevation: 0,
        leading: context.canPop()
            ? IconButton(
                icon: Icon(Icons.arrow_back_ios_new,
                    size: 20, color: colorScheme.onSurface),
                onPressed: () => context.pop(),
              )
            : null,
        title: Text(
          'Delete Account',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────────────
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.menu_book_rounded,
                        size: 40,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Delete Your Disciplefy Account',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Learn how to permanently delete your account and what happens to your data.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // ── How to Delete ────────────────────────────────────────────
              _SectionCard(
                color: cardColor,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionTitle(
                      icon: Icons.delete_forever_rounded,
                      label: 'How to Delete Your Account',
                      colorScheme: colorScheme,
                    ),
                    const SizedBox(height: 16),
                    ..._deleteSteps.asMap().entries.map(
                          (entry) => _NumberedStep(
                            number: entry.key + 1,
                            text: entry.value,
                            colorScheme: colorScheme,
                            theme: theme,
                          ),
                        ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── What Gets Deleted ────────────────────────────────────────
              _SectionCard(
                color: cardColor,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionTitle(
                      icon: Icons.delete_outline_rounded,
                      label: 'What Gets Deleted',
                      colorScheme: colorScheme,
                    ),
                    const SizedBox(height: 16),
                    ..._deletedItems.map(
                      (item) => _BulletItem(
                        text: item,
                        color: colorScheme.error,
                        theme: theme,
                        colorScheme: colorScheme,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── What Is Kept ─────────────────────────────────────────────
              _SectionCard(
                color: cardColor,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionTitle(
                      icon: Icons.info_outline_rounded,
                      label: 'What Is Kept',
                      colorScheme: colorScheme,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Study guide content may be retained in anonymised form — your name and personal details are removed, but AI-generated guide text may remain as shared content to benefit other users.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Retention Warning ────────────────────────────────────────
              _SectionCard(
                color: colorScheme.error.withOpacity(0.06),
                borderColor: colorScheme.error.withOpacity(0.3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: colorScheme.error, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Permanent Deletion',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colorScheme.error,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Account deletion is immediate and permanent. Once confirmed, your data cannot be recovered. There is no grace period or undo option.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.error.withOpacity(0.85),
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Contact ──────────────────────────────────────────────────
              _SectionCard(
                color: cardColor,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionTitle(
                      icon: Icons.mail_outline_rounded,
                      label: 'Questions?',
                      colorScheme: colorScheme,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'If you have questions about account deletion or your data, contact us at:',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'contact@disciplefy.com',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Direct Deletion Request CTA ──────────────────────────────
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _launchDeletionEmail(),
                  icon: const Icon(Icons.delete_forever_rounded),
                  label: const Text('Request Account Deletion'),
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.error,
                    foregroundColor: colorScheme.onError,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Opens an email to request deletion if you no longer have the app',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchDeletionEmail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'contact@disciplefy.com',
      queryParameters: {
        'subject': 'Account Deletion Request',
        'body':
            'Hello,\n\nI would like to request the permanent deletion of my Disciplefy account and all associated data.\n\nRegistered email: \nReason (optional): \n\nThank you.',
      },
    );
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
  ];
}

// ── Helper widgets ────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final Widget child;
  final Color color;
  final Color? borderColor;

  const _SectionCard({
    required this.child,
    required this.color,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: borderColor != null ? Border.all(color: borderColor!) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String label;
  final ColorScheme colorScheme;

  const _SectionTitle({
    required this.icon,
    required this.label,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
        ),
      ],
    );
  }
}

class _NumberedStep extends StatelessWidget {
  final int number;
  final String text;
  final ColorScheme colorScheme;
  final ThemeData theme;

  const _NumberedStep({
    required this.number,
    required this.text,
    required this.colorScheme,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BulletItem extends StatelessWidget {
  final String text;
  final Color color;
  final ThemeData theme;
  final ColorScheme colorScheme;

  const _BulletItem({
    required this.text,
    required this.color,
    required this.theme,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
