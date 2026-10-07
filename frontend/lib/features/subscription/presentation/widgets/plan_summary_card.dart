import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/services/language_preference_service.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/core/utils/logger.dart';
import 'package:disciplefy_bible_study/features/study_generation/data/repositories/token_cost_repository.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_mode.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/widgets/ledger_widgets.dart';

/// Credits one follow-up question costs. Fixed on the backend
/// (`study-followup`), the same in every language.
const int kFollowUpCredits = 5;

/// The study depths named in a "what a study costs" line, in order.
const List<StudyMode> kCostLineModes = [
  StudyMode.quick,
  StudyMode.standard,
  StudyMode.deep,
  StudyMode.lectio,
  StudyMode.sermon,
];

/// "Quick Read 10 · Standard 20 · Deep Dive 30", from the depths present in
/// [costs]; adds "Follow-up N" when [followUp] is given. Empty when there is
/// nothing to list.
String studyCostsLine(
  BuildContext context,
  Map<StudyMode, int> costs, {
  int? followUp,
}) {
  final parts = <String>[
    for (final mode in kCostLineModes)
      if (costs[mode] case final cost?)
        '${context.tr('study_mode.${mode.name}.short_name')} $cost',
    if (followUp != null)
      '${context.tr(TranslationKeys.creditsFollowUp)} $followUp',
  ];
  return parts.join(' · ');
}

/// Credit cost of [modes] in the user's study content language, from the
/// backend's cost table. Depths that fail to load are left out; an empty map
/// means no costs are known (callers fall back to the general line).
Future<Map<StudyMode, int>> loadStudyCosts({
  List<StudyMode> modes = const [
    StudyMode.quick,
    StudyMode.standard,
    StudyMode.deep,
  ],
}) async {
  if (!sl.isRegistered<TokenCostRepository>()) return {};
  try {
    final language = sl.isRegistered<LanguagePreferenceService>()
        ? (await sl<LanguagePreferenceService>().getStudyContentLanguage()).code
        : 'en';
    final costs = <StudyMode, int>{};
    for (final mode in modes) {
      final result =
          await sl<TokenCostRepository>().getTokenCost(language, mode.value);
      result.fold(
        (failure) => Logger.warning(
            'Plan: no cost for ${mode.name} in $language',
            tag: 'PLAN'),
        (cost) => costs[mode] = cost,
      );
    }
    return costs;
  } catch (e) {
    Logger.error('Plan: study costs failed to load', error: e);
    return {};
  }
}

/// intl locale for the app language ('hi' and 'ml' localized, else English).
String _intlLocale() {
  final code = sl.isRegistered<TranslationService>()
      ? sl<TranslationService>().currentLanguage.code
      : 'en';
  return switch (code) {
    'hi' => 'hi_IN',
    'ml' => 'ml_IN',
    _ => 'en_US',
  };
}

/// Formats with the app language's locale, falling back to English when that
/// locale's date symbols are not loaded.
String _localized(DateFormat Function(String locale) build, DateTime value) {
  final locale = _intlLocale();
  try {
    return _clean(build(locale).format(value));
  } catch (e) {
    Logger.debug('PlanSummaryCard: no date symbols for $locale ($e)');
    return _clean(build('en_US').format(value));
  }
}

/// intl's Malayalam month names carry a zero-width non-joiner that breaks the
/// conjunct in "ഒക്ടോബർ", and its times put a narrow no-break space before
/// AM/PM; both read better as plain text.
String _clean(String formatted) =>
    formatted.replaceAll('\u200c', '').replaceAll('\u202f', ' ');

/// "March 31, 2027" in the app language.
String formatPlanDate(DateTime date) =>
    _localized((locale) => DateFormat.yMMMMd(locale), date);

/// "5:30 AM" in the app language.
String formatPlanTime(DateTime time) =>
    _localized((locale) => DateFormat.jm(locale), time);

/// The one summary of the user's plan: name, trial or renewal, how it is
/// billed, today's credits and what a study costs.
class PlanSummaryCard extends StatelessWidget {
  final String planName;
  final bool isTrial;

  /// End of a free trial. The Trial tag shows only together with this date.
  final DateTime? trialEnds;

  /// Next renewal of a paid plan.
  final DateTime? renewsOn;

  /// Store or gateway that bills the plan ("Google Play"); null when nothing
  /// is billed (trial, free, system grants, web without a store).
  final String? providerLabel;

  /// Credits left today and the daily allowance (≤ 0 means unlimited).
  final int left;
  final int dailyLimit;
  final DateTime? resetsAt;

  /// Credit cost per study depth for the content language.
  final Map<StudyMode, int> costs;

  const PlanSummaryCard({
    super.key,
    required this.planName,
    required this.isTrial,
    this.trialEnds,
    this.renewsOn,
    this.providerLabel,
    required this.left,
    required this.dailyLimit,
    required this.resetsAt,
    required this.costs,
  });

  bool get _unlimited => dailyLimit <= 0;

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final showTrial = isTrial && trialEnds != null;
    final costLine = studyCostsLine(context, costs);

    return Container(
      key: const Key('plan_summary_card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: palette.gold.withValues(alpha: palette.isDark ? 0.32 : 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  planName,
                  style: AppFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: palette.text,
                    height: 1.2,
                  ),
                ),
              ),
              if (showTrial) ...[
                const SizedBox(width: 8),
                LedgerStatusPill(
                  label: context.tr(TranslationKeys.myPlanTrialPill),
                  tone: LedgerTone.gold,
                ),
              ],
            ],
          ),
          if (showTrial)
            _line(
              context,
              context.tr(TranslationKeys.planTrialUntil,
                  {'date': formatPlanDate(trialEnds!)}),
              color: palette.gold,
            )
          else if (!isTrial && renewsOn != null)
            _line(
              context,
              context.tr(TranslationKeys.planRenewsOn,
                  {'date': formatPlanDate(renewsOn!)}),
              color: palette.gold,
            ),
          if (!isTrial && providerLabel != null)
            _line(
              context,
              context.tr(
                  TranslationKeys.planBilledVia, {'provider': providerLabel}),
              color: palette.muted,
            ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: palette.raised,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                LedgerRing(
                  progress: _unlimited ? 1 : left / dailyLimit,
                  size: 72,
                  strokeWidth: 5,
                  child: _unlimited
                      ? Icon(Icons.all_inclusive_rounded,
                          size: 26, color: palette.gold)
                      : Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '$left',
                                  style: AppFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: palette.text,
                                    height: 1.1,
                                    fontFeatures: kLedgerTabular,
                                  ),
                                ),
                                Text(
                                  context.tr(TranslationKeys.ledgerOfTotal,
                                      {'total': dailyLimit}),
                                  maxLines: 1,
                                  style: AppFonts.inter(
                                      fontSize: 12, color: palette.muted),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _unlimited
                            ? context.tr(TranslationKeys.ledgerUnlimitedTitle)
                            : context
                                .tr(TranslationKeys.planLeftToday, {'n': left}),
                        style: AppFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: palette.text,
                          height: 1.3,
                        ),
                      ),
                      if (!_unlimited && resetsAt != null)
                        _detail(
                          context,
                          context.tr(TranslationKeys.planResetsAt,
                              {'time': formatPlanTime(resetsAt!.toLocal())}),
                        ),
                      if (costLine.isNotEmpty) _detail(context, costLine),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _line(BuildContext context, String text, {required Color color}) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        text,
        style: AppFonts.inter(fontSize: 13.5, color: color, height: 1.4),
      ),
    );
  }

  Widget _detail(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Text(
        text,
        style: AppFonts.inter(
          fontSize: 12.5,
          color: ReaderPalette.of(context).muted,
          height: 1.4,
          fontFeatures: kLedgerTabular,
        ),
      ),
    );
  }
}
