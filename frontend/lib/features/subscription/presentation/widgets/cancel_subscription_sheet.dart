import 'package:flutter/material.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/widgets/settings_group.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/widgets/settings_sheet.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/widgets/ledger_widgets.dart';

/// How the user chose to cancel in [CancelSubscriptionSheet].
enum CancelChoice { endOfCycle, immediately }

/// Bottom sheet that confirms a subscription cancellation:
/// a red eyebrow, "Keep studying until …?", the two ways to cancel as radio
/// rows, and Keep plan / Confirm cancel.
///
/// Resolves with the confirmed [CancelChoice], or null when the user keeps
/// the plan. When [allowImmediate] is false only the end-of-cycle option is
/// offered and the radio list is hidden.
class CancelSubscriptionSheet extends StatefulWidget {
  final String planName;
  final String accessUntil;
  final bool allowImmediate;
  final CancelChoice initialChoice;

  const CancelSubscriptionSheet({
    super.key,
    required this.planName,
    required this.accessUntil,
    this.allowImmediate = false,
    this.initialChoice = CancelChoice.endOfCycle,
  });

  static Future<CancelChoice?> show(
    BuildContext context, {
    required String planName,
    required String accessUntil,
    bool allowImmediate = false,
    CancelChoice initialChoice = CancelChoice.endOfCycle,
  }) =>
      showSettingsSheet<CancelChoice>(
        context: context,
        builder: (_) => CancelSubscriptionSheet(
          planName: planName,
          accessUntil: accessUntil,
          allowImmediate: allowImmediate,
          initialChoice: initialChoice,
        ),
      );

  @override
  State<CancelSubscriptionSheet> createState() =>
      _CancelSubscriptionSheetState();
}

class _CancelSubscriptionSheetState extends State<CancelSubscriptionSheet> {
  late CancelChoice _choice =
      widget.allowImmediate ? widget.initialChoice : CancelChoice.endOfCycle;

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final red = LedgerToneColors.of(context, LedgerTone.error);
    final args = {'plan': widget.planName, 'date': widget.accessUntil};

    return SettingsSheetFrame(
      children: [
        LedgerSectionLabel(
          context.tr(TranslationKeys.ledgerCancelEyebrow, args),
          color: red.foreground,
          padding: const EdgeInsets.only(bottom: 10),
        ),
        Text(
          context.tr(TranslationKeys.ledgerCancelTitle, args),
          style: AppFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: palette.text,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          context.tr(TranslationKeys.ledgerCancelBody, args),
          style: AppFonts.inter(
            fontSize: 14,
            color: palette.muted,
            height: 1.5,
          ),
        ),
        if (widget.allowImmediate) ...[
          const SizedBox(height: 16),
          _ChoiceTile(
            key: const Key('cancel_choice_end'),
            title: context.tr(TranslationKeys.ledgerCancelEnd),
            subtitle: context.tr(TranslationKeys.ledgerCancelEndSub, args),
            selected: _choice == CancelChoice.endOfCycle,
            onTap: () => setState(() => _choice = CancelChoice.endOfCycle),
          ),
          const SizedBox(height: 10),
          _ChoiceTile(
            key: const Key('cancel_choice_now'),
            title: context.tr(TranslationKeys.ledgerCancelNow),
            subtitle: context.tr(TranslationKeys.ledgerCancelNowSub, args),
            selected: _choice == CancelChoice.immediately,
            onTap: () => setState(() => _choice = CancelChoice.immediately),
          ),
        ],
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: LedgerSecondaryButton(
                key: const Key('cancel_keep_plan'),
                label: context.tr(TranslationKeys.ledgerKeepPlan),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: LedgerSecondaryButton(
                key: const Key('cancel_confirm'),
                destructive: true,
                label: context.tr(TranslationKeys.ledgerConfirmCancel),
                onPressed: () => Navigator.of(context).pop(_choice),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Radio option: gold ring and wash when selected, raised fill otherwise.
class _ChoiceTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final ring = palette.selectedFill;
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      child: Material(
        color: selected
            ? ring.withValues(alpha: palette.isDark ? 0.16 : 0.07)
            : palette.raised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: selected ? ring : Colors.transparent,
            width: 1.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                SettingsRadioMark(selected: selected),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: palette.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppFonts.inter(
                          fontSize: 12.5,
                          color: palette.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
