import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/ui_constants.dart';
import '../../domain/entities/daily_verse_entity.dart';

/// Action buttons for daily verse (Copy, Share, Refresh).
///
/// Provides common verse interaction options with proper
/// user feedback and accessibility support.
class VerseActionButtons extends StatelessWidget {
  final DailyVerseEntity verse;
  final VoidCallback? onRefresh;

  const VerseActionButtons({
    super.key,
    required this.verse,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(top: UIConstants.spacingLg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionButton(
            context: context,
            icon: Icons.copy,
            label: 'Copy',
            onTap: () => _copyVerse(context),
            theme: theme,
          ),
          _buildActionButton(
            context: context,
            icon: Icons.share,
            label: 'Share',
            onTap: () => _shareVerse(context),
            theme: theme,
          ),
          _buildActionButton(
            context: context,
            icon: Icons.refresh,
            label: 'Refresh',
            onTap: onRefresh,
            theme: theme,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    required ThemeData theme,
  }) =>
      Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: UIConstants.actionButtonSpacing,
              vertical: UIConstants.actionButtonPadding,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: theme.colorScheme.primary,
                  size: UIConstants.iconSizeSm,
                ),
                const SizedBox(height: UIConstants.spacingXs),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: UIConstants.fontSizeSm,
                    fontWeight: UIConstants.fontWeightMedium,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  void _copyVerse(BuildContext context) {
    final verseText = '${verse.getVerseText(VerseLanguage.english)} - ${verse.reference}';
    Clipboard.setData(ClipboardData(text: verseText));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Verse copied to clipboard'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  void _shareVerse(BuildContext context) {
    final verseText = '${verse.getVerseText(VerseLanguage.english)} - ${verse.reference}';

    // This would typically use share_plus package
    // For now, just copy to clipboard as fallback
    Clipboard.setData(ClipboardData(text: verseText));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Verse ready to share (copied to clipboard)'),
        backgroundColor: Theme.of(context).colorScheme.secondary,
      ),
    );
  }
}
