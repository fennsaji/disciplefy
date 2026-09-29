import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/tokens/domain/entities/token_usage_history.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/widgets/ledger_widgets.dart';

/// One usage entry as a ledger line: icon tile, "Study guide · Standard · EN",
/// the content and when/where the credits came from, and the amount spent.
class UsageHistoryListItem extends StatelessWidget {
  final TokenUsageHistory usage;

  const UsageHistoryListItem({
    super.key,
    required this.usage,
  });

  bool get _isFollowUp =>
      usage.operationType == 'follow_up_question' ||
      usage.featureName == 'study_followup';

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);

    final kind = _isFollowUp
        ? context.tr(TranslationKeys.ledgerFollowUp)
        : usage.operationType == 'study_generation' ||
                usage.featureName == 'study_generate'
            ? context.tr(TranslationKeys.ledgerStudyGuide)
            : usage.featureDisplayName;
    final title = [
      kind,
      if (usage.studyMode != null) usage.studyModeDisplay,
      if (usage.language.isNotEmpty) usage.languageDisplay,
    ].join(' · ');

    final String source;
    if (usage.usedDailyTokens && usage.usedPurchasedTokens) {
      source = context.tr(TranslationKeys.ledgerDailyPlusPurchased,
          {'count': usage.purchasedTokensUsed});
    } else if (usage.usedPurchasedTokens) {
      source = context.tr(TranslationKeys.ledgerFromPurchased);
    } else {
      source = context.tr(TranslationKeys.ledgerFromDaily);
    }

    final hasContent = (usage.contentTitle?.isNotEmpty ?? false) ||
        (usage.contentReference?.isNotEmpty ?? false);
    final subtitle = [
      if (hasContent) usage.displayTitle,
      _formatTimestamp(context, usage.createdAt),
      source,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LedgerIconTile(
            icon: _isFollowUp
                ? Icons.chat_bubble_outline_rounded
                : Icons.menu_book_outlined,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.inter(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: palette.text,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.inter(
                    fontSize: 12.5,
                    color: palette.muted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '−${usage.tokenCost}',
              style: AppFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: palette.text,
                fontFeatures: kLedgerTabular,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// "Today · 9:14 AM", "Yesterday · …" or "Sep 27 · …".
  String _formatTimestamp(BuildContext context, DateTime timestamp) {
    final local = timestamp.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final time = DateFormat.jm().format(local);
    final diff = today.difference(day).inDays;
    if (diff == 0) {
      return '${context.tr(TranslationKeys.ledgerToday)} · $time';
    }
    if (diff == 1) {
      return '${context.tr(TranslationKeys.ledgerYesterday)} · $time';
    }
    final date = local.year == now.year
        ? DateFormat('MMM d').format(local)
        : DateFormat('MMM d, y').format(local);
    return '$date · $time';
  }
}
