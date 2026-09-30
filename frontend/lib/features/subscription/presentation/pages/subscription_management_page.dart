import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/router/app_routes.dart';
import 'package:disciplefy_bible_study/core/services/pricing_service.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/subscription/domain/entities/subscription.dart';
import 'package:disciplefy_bible_study/features/subscription/presentation/bloc/subscription_bloc.dart';
import 'package:disciplefy_bible_study/features/subscription/presentation/bloc/subscription_event.dart';
import 'package:disciplefy_bible_study/features/subscription/presentation/bloc/subscription_state.dart';
import 'package:disciplefy_bible_study/features/subscription/presentation/widgets/cancel_subscription_sheet.dart';
import 'package:disciplefy_bible_study/features/tokens/domain/entities/token_status.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/bloc/token_bloc.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/bloc/token_state.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/widgets/ledger_widgets.dart';
import 'package:disciplefy_bible_study/shared/widgets/app_snackbar.dart';

/// Subscription Management Page (quiet ledger)
///
/// Allows users to view and manage their subscription including:
/// - Current subscription status
/// - Next billing date and amount
/// - Cancel subscription (immediate or at cycle end)
/// - View subscription history
class SubscriptionManagementPage extends StatefulWidget {
  const SubscriptionManagementPage({super.key});

  @override
  State<SubscriptionManagementPage> createState() =>
      _SubscriptionManagementPageState();
}

class _SubscriptionManagementPageState
    extends State<SubscriptionManagementPage> {
  @override
  void initState() {
    super.initState();
    // Load active subscription when page opens
    context.read<SubscriptionBloc>().add(const GetActiveSubscription());
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Scaffold(
      backgroundColor: palette.page,
      appBar: LedgerTopBar(
        title: context.tr(TranslationKeys.subscriptionTitle),
        actions: [
          LedgerBarAction(
            icon: Icons.refresh_rounded,
            tooltip: context.tr(TranslationKeys.subscriptionRefresh),
            onPressed: () {
              context.read<SubscriptionBloc>().add(const RefreshSubscription());
            },
          ),
        ],
      ),
      body: BlocBuilder<TokenBloc, TokenState>(
        builder: (context, tokenState) {
          // Get user plan info for Standard trial detection
          TokenStatus? tokenStatus;
          if (tokenState is TokenLoaded) {
            tokenStatus = tokenState.tokenStatus;
          }

          // Check if user is Standard trial (no subscription yet)
          // Use UserSubscriptionStatus from SubscriptionBloc if available,
          // otherwise fall back to TokenStatus plan check.
          final subState = context.read<SubscriptionBloc>().state;
          DateTime? trialEndDate;
          bool isTrialActive = false;
          if (subState is UserSubscriptionStatusLoaded) {
            isTrialActive = subState.subscriptionStatus.isTrialActive;
            trialEndDate = subState.subscriptionStatus.trialEndDate;
          }
          final isStandardTrialUser = tokenStatus != null &&
              tokenStatus.userPlan == UserPlan.standard &&
              isTrialActive;

          return BlocConsumer<SubscriptionBloc, SubscriptionState>(
            listener: (context, state) {
              if (state is SubscriptionCancelled) {
                // Show cancellation success message
                showAppSnackBar(
                  context,
                  state.message,
                  tone: AppSnackTone.warning,
                );
              } else if (state is SubscriptionResumed) {
                // Show resumption success message
                showAppSnackBar(
                  context,
                  state.message,
                  tone: AppSnackTone.success,
                );
              } else if (state is SubscriptionError) {
                // Show error message
                showAppSnackBar(
                  context,
                  context.tr(TranslationKeys.commonErrorTryAgain),
                  tone: AppSnackTone.error,
                );
              }
            },
            builder: (context, state) {
              if (state is SubscriptionLoading &&
                  (state.operation == 'fetching' ||
                      state.operation == 'cancelling' ||
                      state.operation == 'resuming')) {
                return const LedgerLoading();
              }

              if (state is SubscriptionLoaded) {
                if (state.activeSubscription == null) {
                  // Show Standard trial view for Standard users in trial period
                  if (isStandardTrialUser) {
                    return _buildStandardTrialView(trialEndDate);
                  }
                  return _buildNoSubscriptionView();
                }
                return _buildSubscriptionView(state.activeSubscription!, state);
              }

              if (state is SubscriptionError &&
                  state.previousSubscription != null) {
                return _buildSubscriptionView(
                    state.previousSubscription!, state);
              }

              // Default: check for Standard trial user
              if (isStandardTrialUser) {
                return _buildStandardTrialView(trialEndDate);
              }
              return _buildNoSubscriptionView();
            },
          );
        },
      ),
    );
  }

  Widget _buildNoSubscriptionView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LedgerMessage(
              icon: Icons.workspace_premium_outlined,
              title: context.tr(TranslationKeys.subscriptionNoActive),
              body: context.tr(TranslationKeys.subscriptionUpgradePrompt),
            ),
            SizedBox(
              width: double.infinity,
              child: LedgerPrimaryButton(
                label: context.tr(TranslationKeys.subscriptionUpgradeButton),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build view for Standard plan users in trial period (no subscription yet)
  Widget _buildStandardTrialView(DateTime? trialEndDate) {
    final palette = ReaderPalette.of(context);
    final daysRemaining = trialEndDate?.difference(DateTime.now()).inDays ?? 0;

    // Get Standard plan features
    final features = [
      context.tr(TranslationKeys.pricingStandardFeature1),
      context.tr(TranslationKeys.pricingStandardFeature2),
      context.tr(TranslationKeys.pricingStandardFeature3),
      context.tr(TranslationKeys.pricingStandardFeature4),
      context.tr(TranslationKeys.pricingStandardFeature5),
    ];

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _PlanHeader(
          planName: 'Standard Plan',
          status: 'Free Trial Active',
          tone: LedgerTone.accent,
        ),
        const SizedBox(height: 10),
        LedgerNotice(
          icon: Icons.calendar_today_outlined,
          text: 'Free until ${_formatTrialDate(trialEndDate)}',
          detail: '$daysRemaining days remaining',
        ),
        LedgerSectionLabel(context.tr(TranslationKeys.subscriptionPlanDetails)),
        Text(
          context.tr(TranslationKeys.subscriptionIncludedFeatures),
          style: AppFonts.inter(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: palette.muted,
          ),
        ),
        const SizedBox(height: 6),
        for (final feature in features) LedgerCheckRow(feature),
        const LedgerSectionLabel('After Trial Period'),
        Text(
          'After ${_formatTrialDate(trialEndDate)}, you can continue using Standard features for just ${sl<PricingService>().getFormattedPricePerMonth('standard')}. We\'ll remind you before the trial ends.',
          style: AppFonts.inter(
            fontSize: 14,
            color: palette.muted,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  String _formatTrialDate(DateTime? date) {
    if (date == null) return 'the trial end date';
    return DateFormat('MMMM d, y').format(date);
  }

  Widget _buildSubscriptionView(
      Subscription subscription, SubscriptionState state) {
    return RefreshIndicator(
      onRefresh: () async {
        context.read<SubscriptionBloc>().add(const RefreshSubscription());
        await Future.delayed(const Duration(seconds: 1));
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // Status
          _buildStatusCard(subscription),

          // Billing Information
          _buildBillingInfo(subscription),

          // Payment History link
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: LedgerLink(
              label: context.tr(TranslationKeys.myPlanViewPaymentHistory),
              leadingIcon: Icons.receipt_long_outlined,
              onTap: () => context.push(AppRoutes.subscriptionPaymentHistory),
            ),
          ),

          // Plan Details
          _buildPlanDetails(subscription),

          const LedgerHairline(verticalMargin: 18),

          // Action Buttons
          _buildActionButtons(subscription, state),
        ],
      ),
    );
  }

  Widget _buildStatusCard(Subscription subscription) {
    final isActive = subscription.isActive;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PlanHeader(
          planName: _formattedPlanType(subscription),
          status: subscription.status.displayName,
          detail: subscription.status.description,
          tone: isActive ? LedgerTone.success : LedgerTone.warning,
        ),
        if (subscription.isEndingSoon) ...[
          const SizedBox(height: 10),
          LedgerNotice(
            icon: Icons.warning_amber_rounded,
            tone: LedgerTone.warning,
            text: context.tr(TranslationKeys.subscriptionEndsIn).replaceAll(
                '{days}', subscription.daysRemainingInPeriod.toString()),
          ),
        ],
      ],
    );
  }

  Widget _buildBillingInfo(Subscription subscription) {
    final dateFormat = DateFormat('MMM d, y');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LedgerSectionLabel(context.tr(TranslationKeys.subscriptionBillingInfo)),
        LedgerRow(
          label: context.tr(TranslationKeys.subscriptionAmount),
          value:
              '₹${subscription.amountRupees.toStringAsFixed(0)}${context.tr(TranslationKeys.subscriptionPerMonth)}',
        ),
        if (subscription.nextBillingAt != null) ...[
          LedgerRow(
            label: context.tr(TranslationKeys.subscriptionNextBilling),
            value: dateFormat.format(subscription.nextBillingAt!),
          ),
          LedgerRow(
            label: context.tr(TranslationKeys.subscriptionDaysUntilBilling),
            value:
                '${subscription.daysUntilNextBilling ?? '-'} ${context.tr(TranslationKeys.subscriptionDays)}',
          ),
        ],
        if (subscription.currentPeriodEnd != null)
          LedgerRow(
            label: context.tr(TranslationKeys.subscriptionCurrentPeriodEnds),
            value: dateFormat.format(subscription.currentPeriodEnd!),
          ),
      ],
    );
  }

  /// Format plan type nicely (premium_monthly -> Premium, standard -> Standard,
  /// plus -> Plus). Defensive: handles empty or malformed planType.
  String _formattedPlanType(Subscription subscription) {
    String formattedPlanType = 'Premium';
    final planType = subscription.planType.toLowerCase();
    if (planType.isNotEmpty) {
      final parts = planType.split('_');
      final firstPart = parts.first;
      if (firstPart.isNotEmpty) {
        formattedPlanType = firstPart[0].toUpperCase() + firstPart.substring(1);
      }
    }
    return formattedPlanType;
  }

  Widget _buildPlanDetails(Subscription subscription) {
    final planType = subscription.planType.toLowerCase();
    final isStandardPlan = planType.contains('standard');
    final isPlusPlan = planType.contains('plus');
    final palette = ReaderPalette.of(context);

    // Get features based on plan type
    final features = isStandardPlan
        ? [
            context.tr(TranslationKeys.pricingStandardFeature1),
            context.tr(TranslationKeys.pricingStandardFeature2),
            context.tr(TranslationKeys.pricingStandardFeature3),
            context.tr(TranslationKeys.pricingStandardFeature4),
            context.tr(TranslationKeys.pricingStandardFeature5),
          ]
        : isPlusPlan
            ? [
                '50 daily tokens (all study modes)',
                '10 follow-ups per guide',
                '10 Discipler conversations/month',
                '10 active memory verses',
                '3 practice sessions per verse per day',
                'All 8 practice modes',
              ]
            : [
                context.tr(TranslationKeys.pricingPremiumFeature1),
                context.tr(TranslationKeys.pricingPremiumFeature2),
                context.tr(TranslationKeys.pricingPremiumFeature3),
                context.tr(TranslationKeys.pricingPremiumFeature4),
                context.tr(TranslationKeys.pricingPremiumFeature5),
              ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LedgerSectionLabel(context.tr(TranslationKeys.subscriptionPlanDetails)),
        Text(
          context.tr(TranslationKeys.subscriptionIncludedFeatures),
          style: AppFonts.inter(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: palette.muted,
          ),
        ),
        const SizedBox(height: 6),
        for (final feature in features) LedgerCheckRow(feature),
      ],
    );
  }

  Widget _buildActionButtons(
      Subscription subscription, SubscriptionState state) {
    final isLoading = state is SubscriptionLoading &&
        (state.operation == 'cancelling' || state.operation == 'resuming');

    // Paused subscriptions (Google Play) — direct user to Google Play to resume.
    if (subscription.status == SubscriptionStatus.paused) {
      return _buildPausedSubscriptionUI(subscription.provider);
    }

    // IAP subscriptions (Google Play / App Store) are managed through the respective app store.
    // We cannot cancel/resume IAP subscriptions via API — direct users to the store instead.
    // Use subscription.provider to check, NOT platform detection, so that a Razorpay subscriber
    // opening the app on Android is not incorrectly shown "Manage in Google Play".
    if (subscription.isIAPSubscription) {
      return _buildManageInStoreButton(subscription.provider);
    }

    // Check if subscription has pending cancellation (scheduled to cancel at end of cycle)
    final isCancelledButActive =
        subscription.status == SubscriptionStatus.pending_cancellation;

    if (isCancelledButActive) {
      // Show "Continue Subscription" button for cancelled-but-active subscriptions
      return LedgerPrimaryButton(
        label: context.tr(TranslationKeys.subscriptionContinueButton),
        icon: Icons.restart_alt_rounded,
        loading: isLoading,
        onPressed: () {
          context.read<SubscriptionBloc>().add(const ResumeSubscription());
        },
      );
    }

    if (!subscription.canCancel) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LedgerSecondaryButton(
          key: const Key('subscription_cancel_at_end'),
          label: context.tr(TranslationKeys.subscriptionCancelAtEnd),
          destructive: true,
          loading: isLoading,
          onPressed: () => _showCancelDialog(subscription, false),
        ),
        const SizedBox(height: 6),
        TextButton(
          key: const Key('subscription_cancel_now'),
          onPressed:
              isLoading ? null : () => _showCancelDialog(subscription, true),
          style: TextButton.styleFrom(
            foregroundColor: context.appError,
            minimumSize: const Size.fromHeight(44),
            shape: const StadiumBorder(),
          ),
          child: Text(
            context.tr(TranslationKeys.subscriptionCancelImmediately),
            style: AppFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: context.appError,
            ),
          ),
        ),
      ],
    );
  }

  /// Builds a button that opens the platform's subscription management page.
  /// Used for Google Play and App Store subscriptions where cancellation
  /// cannot be done via API — users must manage them in the store.
  Widget _buildManageInStoreButton(String subscriptionProvider) {
    final isAndroid = subscriptionProvider == 'google_play';
    final storeLabel =
        isAndroid ? 'Manage in Google Play' : 'Manage in App Store';
    final storeIcon = isAndroid ? Icons.shop_rounded : Icons.apple_rounded;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LedgerNotice(
          icon: Icons.info_outline_rounded,
          tone: LedgerTone.neutral,
          text:
              'To cancel or modify your subscription, please manage it through ${isAndroid ? 'Google Play' : 'the App Store'}.',
        ),
        const SizedBox(height: 12),
        LedgerPrimaryButton(
          label: storeLabel,
          icon: storeIcon,
          onPressed: () => _openStoreSubscriptions(isAndroid),
        ),
      ],
    );
  }

  /// Builds the UI shown when a subscription is paused (e.g. via Google Play).
  /// Directs the user to Google Play to resume their subscription.
  Widget _buildPausedSubscriptionUI(String subscriptionProvider) {
    final isAndroid = subscriptionProvider == 'google_play';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LedgerNotice(
          icon: Icons.pause_circle_outline_rounded,
          tone: LedgerTone.warning,
          text:
              'Your subscription is paused. Manage it in ${isAndroid ? 'Google Play' : 'the App Store'} to resume.',
        ),
        const SizedBox(height: 12),
        LedgerPrimaryButton(
          label: isAndroid ? 'Resume in Google Play' : 'Resume in App Store',
          icon: isAndroid ? Icons.shop_rounded : Icons.apple_rounded,
          onPressed: () => _openStoreSubscriptions(isAndroid),
        ),
      ],
    );
  }

  Future<void> _openStoreSubscriptions(bool isAndroid) async {
    final Uri uri = isAndroid
        ? Uri.parse(
            'https://play.google.com/store/account/subscriptions?package=com.disciplefy.bible_study',
          )
        : Uri.parse('https://apps.apple.com/account/subscriptions');

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        showAppSnackBar(
          context,
          context.tr(
            isAndroid
                ? TranslationKeys.payFeedbackStoreOpenFailedAndroid
                : TranslationKeys.payFeedbackStoreOpenFailedIos,
          ),
          tone: AppSnackTone.warning,
        );
      }
    }
  }

  /// Confirms the cancellation in the cancel sheet; [immediate] picks the
  /// option pre-selected from the button the user tapped.
  Future<void> _showCancelDialog(
      Subscription subscription, bool immediate) async {
    final choice = await CancelSubscriptionSheet.show(
      context,
      planName: _formattedPlanType(subscription),
      accessUntil: DateFormat('MMM d').format(
        subscription.currentPeriodEnd ??
            subscription.nextBillingAt ??
            DateTime.now().add(const Duration(days: 30)),
      ),
      allowImmediate: true,
      initialChoice:
          immediate ? CancelChoice.immediately : CancelChoice.endOfCycle,
    );
    if (choice == null || !mounted) return;
    _cancelSubscription(choice == CancelChoice.endOfCycle);
  }

  void _cancelSubscription(bool cancelAtCycleEnd) {
    context.read<SubscriptionBloc>().add(
          CancelSubscription(
            cancelAtCycleEnd: cancelAtCycleEnd,
            reason: cancelAtCycleEnd
                ? 'User requested cancellation at cycle end'
                : 'User requested immediate cancellation',
          ),
        );
  }
}

/// Plan name with a status pill and an optional muted description, on the
/// card fill — the one raised block of the page.
class _PlanHeader extends StatelessWidget {
  final String planName;
  final String status;
  final String? detail;
  final LedgerTone tone;

  const _PlanHeader({
    required this.planName,
    required this.status,
    required this.tone,
    this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Container(
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
              Icon(Icons.workspace_premium_outlined,
                  size: 24, color: palette.gold),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  planName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: palette.text,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(child: LedgerStatusPill(label: status, tone: tone)),
            ],
          ),
          if (detail != null && detail!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              detail!,
              style: AppFonts.inter(
                fontSize: 13.5,
                color: palette.muted,
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
