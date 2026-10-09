import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/router/app_routes.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/bloc/token_bloc.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/bloc/token_state.dart';
import 'package:disciplefy_bible_study/shared/widgets/popup.dart';

/// Soft paywall dialog shown at usage thresholds (80%, 100%), in the popup
/// popup style shared with the insufficient-credits dialog.
class SoftPaywallDialog extends StatelessWidget {
  final int percentage;
  final int tokensRemaining;
  final String userPlan;

  const SoftPaywallDialog({
    required this.percentage,
    required this.tokensRemaining,
    this.userPlan = 'free',
    super.key,
  });

  /// Show the soft paywall dialog
  static Future<void> show(
    BuildContext context, {
    required int percentage,
    required int tokensRemaining,
    int streakDays = 0, // kept for API compatibility, no longer used
    String userPlan = 'free',
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => SoftPaywallDialog(
        percentage: percentage,
        tokensRemaining: tokensRemaining,
        userPlan: userPlan,
      ),
    );
  }

  /// Returns a localized "resets in X hours" string based on time until midnight.
  String _resetKey(BuildContext context) {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final diff = tomorrow.difference(now);
    final hours = diff.inHours;
    final minutes = diff.inMinutes;

    if (minutes < 60) {
      return context.tr(TranslationKeys.tokenSoftPaywallResetSoon);
    }
    if (hours == 1) {
      return context.tr(TranslationKeys.tokenSoftPaywallResetHour);
    }
    return context.tr(
      TranslationKeys.tokenSoftPaywallResetHours,
      {'hours': '$hours'},
    );
  }

  @override
  Widget build(BuildContext context) {
    final resetTime = _resetKey(context);

    final String title;
    final String message;
    final IconData titleIcon;

    if (percentage >= 100) {
      title = context.tr(TranslationKeys.tokenSoftPaywallUsedTitle);
      message = context.tr(
        TranslationKeys.tokenSoftPaywallUsedMessage,
        {'resetTime': resetTime},
      );
      titleIcon = Icons.nightlight_round;
    } else {
      title = context.tr(TranslationKeys.tokenSoftPaywallLowTitle);
      message = context.tr(
        TranslationKeys.tokenSoftPaywallLowMessage,
        {
          'count': '$tokensRemaining',
          'resetTime': resetTime,
        },
      );
      titleIcon = Icons.battery_2_bar_rounded;
    }

    final palette = ReaderPalette.of(context);
    return PopupDialog(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PopupHeader(
          icon: PopupIconCircle(
            icon: titleIcon,
            tone: percentage >= 100 ? PopupTone.accent : PopupTone.gold,
          ),
          eyebrow: context.tr(TranslationKeys.popupCreditsEyebrow),
          title: title,
          body: message,
        ),
        const SizedBox(height: 22),
        PopupPrimaryButton(
          key: const Key('soft_paywall_see_plans'),
          label: context.tr(TranslationKeys.tokenSoftPaywallSeePlans),
          onPressed: () {
            final router = GoRouter.of(context);
            Navigator.of(context).pop();
            // Land on the cheapest plan that lifts this limit, not the top of the
            // page where Free — the plan they already have — sits.
            router.push(AppRoutes.pricing,
                extra: const {'preselectedPlan': 'standard'});
          },
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            key: const Key('soft_paywall_purchase'),
            onPressed: () {
              final router = GoRouter.of(context);
              final tokenState = context.read<TokenBloc>().state;
              final tokenStatus =
                  tokenState is TokenLoaded ? tokenState.tokenStatus : null;
              Navigator.of(context).pop();
              router.push(AppRoutes.tokenPurchase, extra: tokenStatus);
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: palette.text,
              side: BorderSide(color: palette.outline),
              minimumSize: const Size.fromHeight(48),
              shape: const StadiumBorder(),
            ),
            child: Text(
              context.tr(TranslationKeys.tokenSoftPaywallPurchase),
              textAlign: TextAlign.center,
              style: AppFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: palette.text,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        PopupTextButton(
          key: const Key('soft_paywall_later'),
          label: context.tr(TranslationKeys.tokenSoftPaywallMaybeLater),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
