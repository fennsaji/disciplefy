import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/features/tokens/domain/entities/purchase_statistics.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/widgets/ledger_widgets.dart';

/// Purchase summary in the K2 ledger: purchases, credits bought and total
/// spent as three stat tiles.
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
    return LedgerStatRow(
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
    );
  }
}
