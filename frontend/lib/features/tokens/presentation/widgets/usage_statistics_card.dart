import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/tokens/domain/entities/usage_statistics.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/widgets/ledger_widgets.dart';

/// Usage summary in the ledger: three stat tiles, the share of daily
/// credits as a gold bar with the daily / purchased split, the most used
/// feature, language and mode, and the last usage date.
class UsageStatisticsCard extends StatelessWidget {
  final UsageStatistics statistics;

  const UsageStatisticsCard({
    super.key,
    required this.statistics,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final dailyShare = statistics.dailyTokensPercentage.clamp(0.0, 100.0);
    final hasMostUsed = statistics.mostUsedFeature != null ||
        statistics.mostUsedLanguage != null ||
        statistics.mostUsedMode != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LedgerStatRow(
          tiles: [
            LedgerStatTile(
              centered: true,
              value: '${statistics.totalTokens}',
              label: context.tr(TranslationKeys.ledgerCreditsUsed),
            ),
            LedgerStatTile(
              centered: true,
              value: '${statistics.totalOperations}',
              label: context.tr(TranslationKeys.ledgerStudies),
            ),
            LedgerStatTile(
              centered: true,
              value: statistics.averageTokensPerOperation.toStringAsFixed(0),
              label: context.tr(TranslationKeys.ledgerAvgPerStudy),
            ),
          ],
        ),
        if (statistics.totalTokens > 0) ...[
          const SizedBox(height: 18),
          LedgerRow(
            label: context.tr(TranslationKeys.ledgerDailyCredits),
            value: '${dailyShare.toStringAsFixed(0)}%',
          ),
          const SizedBox(height: 4),
          Semantics(
            label:
                '${context.tr(TranslationKeys.ledgerDailyCredits)} ${dailyShare.toStringAsFixed(0)}%',
            excludeSemantics: true,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: dailyShare / 100,
                minHeight: 7,
                backgroundColor: palette.raised,
                valueColor: AlwaysStoppedAnimation<Color>(palette.gold),
              ),
            ),
          ),
        ],
        if (statistics.totalTokens > 0) ...[
          const SizedBox(height: 6),
          LedgerRow(
            label: context.tr('tokens.stats.daily_tokens'),
            value: '${statistics.dailyTokensConsumed}',
          ),
          LedgerRow(
            label:
                '${context.tr('tokens.stats.purchased_tokens')} · ${statistics.purchasedTokensPercentage.toStringAsFixed(0)}%',
            value: '${statistics.purchasedTokensConsumed}',
          ),
        ],
        if (hasMostUsed) ...[
          LedgerSectionLabel(
            context.tr(TranslationKeys.ledgerMostUsed),
            padding: const EdgeInsets.only(top: 14, bottom: 2),
          ),
          if (statistics.mostUsedFeature != null)
            LedgerRow(
              label: context.tr('tokens.stats.feature'),
              value: _featureLabel(context, statistics),
            ),
          if (statistics.mostUsedLanguage != null)
            LedgerRow(
              label: context.tr('tokens.stats.language'),
              value: _languageLabel(statistics),
            ),
          if (statistics.mostUsedMode != null)
            LedgerRow(
              label: context.tr('tokens.stats.study_mode'),
              value: _modeLabel(context, statistics),
            ),
        ],
        if (statistics.lastUsageDate != null) ...[
          const SizedBox(height: 4),
          LedgerRow(
            label: context.tr('tokens.stats.last_usage'),
            value: DateFormat('MMM d, y')
                .format(statistics.lastUsageDate!.toLocal()),
          ),
        ],
      ],
    );
  }
}

/// Muted one-liner shown when the usage summary could not be loaded.
class UsageStatisticsError extends StatelessWidget {
  const UsageStatisticsError({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Row(
      children: [
        Icon(Icons.error_outline_rounded, size: 18, color: palette.dim),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            context.tr(TranslationKeys.ledgerStatsError),
            style: AppFonts.inter(fontSize: 13.5, color: palette.muted),
          ),
        ),
      ],
    );
  }
}

// Feature, language and mode values come from the server as codes;
// show them in the app language instead of fixed English names.
String _featureLabel(BuildContext context, UsageStatistics stats) {
  switch (stats.mostUsedFeature) {
    case 'study_generate':
    case 'continue_learning':
      return context.tr('tokens.stats.feature_lessons');
    case 'study_followup':
      return context.tr('tokens.stats.feature_follow_ups');
    default:
      return stats.mostUsedFeatureDisplay;
  }
}

String _languageLabel(UsageStatistics stats) {
  switch (stats.mostUsedLanguage) {
    case 'en':
      return 'English';
    case 'hi':
      return 'हिन्दी';
    case 'ml':
      return 'മലയാളം';
    default:
      return stats.mostUsedLanguageDisplay;
  }
}

String _modeLabel(BuildContext context, UsageStatistics stats) {
  switch (stats.mostUsedMode) {
    case 'quick':
      return context.tr(TranslationKeys.studyModeQuickShortName);
    case 'standard':
      return context.tr(TranslationKeys.studyModeStandardShortName);
    case 'deep':
      return context.tr(TranslationKeys.studyModeDeepShortName);
    case 'lectio':
      return context.tr(TranslationKeys.studyModeLectioShortName);
    case 'sermon':
      return context.tr(TranslationKeys.studyModeSermonShortName);
    default:
      return stats.mostUsedModeDisplay;
  }
}
