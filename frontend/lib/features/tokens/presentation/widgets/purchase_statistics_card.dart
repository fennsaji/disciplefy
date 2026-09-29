import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/features/tokens/domain/entities/purchase_statistics.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/widgets/ledger_widgets.dart';

/// Purchase summary in the ledger: purchases, credits bought and total
/// spent as three stat tiles, then the average price per credit and the
/// first / last purchase dates.
class PurchaseStatisticsCard extends StatelessWidget {
  final PurchaseStatistics statistics;

  const PurchaseStatisticsCard({
    super.key,
    required this.statistics,
  });

  @override
  Widget build(BuildContext context) {
    final spent = statistics.totalSpent == statistics.totalSpent.roundToDouble()
        ? '₹${statistics.totalSpent.toStringAsFixed(0)}'
        : statistics.formattedTotalSpent;
    final dateFormat = DateFormat('MMM d, y');
    final perCredit = statistics.totalTokens > 0
        ? '₹${(statistics.totalSpent / statistics.totalTokens).toStringAsFixed(2)}'
        : '₹0.00';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LedgerSectionLabel(
          context.tr('tokens.stats.purchase_summary'),
          padding: const EdgeInsets.only(top: 4, bottom: 8),
        ),
        LedgerStatRow(
          tiles: [
            LedgerStatTile(
              centered: true,
              value: '${statistics.totalPurchases}',
              label: context.tr(TranslationKeys.ledgerPurchasesCount),
            ),
            LedgerStatTile(
              centered: true,
              value: '${statistics.totalTokens}',
              label: context.tr(TranslationKeys.ledgerCredits),
            ),
            LedgerStatTile(
              centered: true,
              value: spent,
              label: context.tr(TranslationKeys.ledgerSpent),
            ),
          ],
        ),
        const SizedBox(height: 10),
        LedgerRow(
          label: context.tr('tokens.stats.avg_per_token'),
          value: perCredit,
        ),
        if (statistics.firstPurchaseDate != null)
          LedgerRow(
            label: context.tr('tokens.stats.since'),
            value: dateFormat.format(statistics.firstPurchaseDate!.toLocal()),
          ),
        if (statistics.lastPurchaseDate != null)
          LedgerRow(
            label: context.tr('tokens.stats.last_purchase'),
            value: dateFormat.format(statistics.lastPurchaseDate!.toLocal()),
          ),
      ],
    );
  }
}
