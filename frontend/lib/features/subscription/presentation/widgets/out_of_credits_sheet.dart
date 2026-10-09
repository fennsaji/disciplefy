import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/router/app_routes.dart';
import 'package:disciplefy_bible_study/core/services/activation_analytics.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/tokens/domain/entities/token_status.dart';
import 'package:disciplefy_bible_study/shared/widgets/popup.dart';

/// Bottom sheet shown when a study costs more credits than the user has.
///
/// The "left today" number is [TokenStatus.totalTokens], the same value the
/// header balance pill shows, so the two never disagree.
class OutOfCreditsSheet extends StatelessWidget {
  final TokenStatus status;
  final int needed;

  const OutOfCreditsSheet({
    super.key,
    required this.status,
    required this.needed,
  });

  static Future<void> show(
    BuildContext context, {
    required TokenStatus status,
    required int needed,
  }) {
    ActivationAnalytics.maybeTrack(NuxEvent.creditWarningShown,
        {'needed': needed, 'have': status.totalTokens});
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => OutOfCreditsSheet(status: status, needed: needed),
    );
  }

  static const double _buttonHeight = 40;

  /// Closes the sheet, then navigates, using the router captured up front
  /// because the sheet's own context is gone after the pop.
  void _go(BuildContext context, void Function(GoRouter router) navigate) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    navigate(router);
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final labelStyle = AppFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: palette.text,
    );

    return PopupSheet(
      children: [
        PopupHeader(
          icon: const PopupIconCircle(
            icon: Icons.toll_outlined,
            tone: PopupTone.gold,
          ),
          eyebrow: context.tr(TranslationKeys.creditsOutEyebrow),
          title: context.tr(TranslationKeys.creditsOutTitle),
          body: context.tr(TranslationKeys.creditsOutBody),
        ),
        const SizedBox(height: 14),
        Text(
          context.tr(TranslationKeys.creditsOutNeed, {
            'need': needed,
            'have': status.totalTokens,
          }),
          textAlign: TextAlign.center,
          style: AppFonts.inter(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: palette.gold,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: _buttonHeight,
          child: FilledButton(
            onPressed: () => _go(
              context,
              (router) => status.canPurchaseTokens
                  ? router.push(AppRoutes.tokenPurchase, extra: status)
                  : router.push(AppRoutes.myPlan),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: palette.ctaFill,
              foregroundColor: palette.ctaInk,
              minimumSize: const Size.fromHeight(_buttonHeight),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              shape: const StadiumBorder(),
              elevation: 0,
            ),
            child: Text(
              context.tr(TranslationKeys.creditsGet),
              textAlign: TextAlign.center,
              style: labelStyle.copyWith(fontSize: 15, color: palette.ctaInk),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // The small secondary pill (32), as the design.
        SizedBox(
          height: 32,
          child: OutlinedButton(
            onPressed: () => _go(
              context,
              (router) => router.push('/saved?tab=saved&source=generate'),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: palette.text,
              side: BorderSide(color: palette.outline),
              minimumSize: const Size.fromHeight(32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              shape: const StadiumBorder(),
            ),
            child: Text(
              context.tr(TranslationKeys.creditsViewSaved),
              textAlign: TextAlign.center,
              style: labelStyle,
            ),
          ),
        ),
        const SizedBox(height: 4),
        PopupTextButton(
          label: context.tr(TranslationKeys.creditsMaybeLater),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
