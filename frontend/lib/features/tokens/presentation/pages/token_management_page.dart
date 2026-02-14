import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_fonts.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/extensions/translation_extension.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/payment_service.dart';
import '../bloc/token_bloc.dart';
import '../bloc/token_event.dart';
import '../bloc/token_state.dart';
import '../widgets/token_balance_widget.dart';
import '../widgets/current_plan_section.dart';
import '../widgets/token_actions_section.dart';
import '../widgets/usage_info_section.dart';
import '../widgets/plan_comparison_section.dart';
import '../../domain/entities/token_status.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart' as auth_states;
import '../../../subscription/presentation/bloc/subscription_bloc.dart';
import '../../../subscription/presentation/bloc/subscription_state.dart';
import '../../../subscription/presentation/bloc/subscription_event.dart';
import '../../../subscription/domain/entities/subscription.dart';

/// Token Management Page
///
/// Provides comprehensive token management including:
/// - Current token status and balance
/// - Purchase tokens functionality
/// - Plan upgrade options
/// - Usage history and analytics
/// - Token reset information
class TokenManagementPage extends StatefulWidget {
  const TokenManagementPage({super.key});

  @override
  State<TokenManagementPage> createState() => _TokenManagementPageState();
}

class _TokenManagementPageState extends State<TokenManagementPage>
    with WidgetsBindingObserver, RouteAware {
  // Payment confirmation guard to prevent duplicate calls
  final Set<String> _processingPayments = <String>{};

  @override
  void initState() {
    super.initState();
    // Add lifecycle observer to detect when app resumes
    WidgetsBinding.instance.addObserver(this);
    // Load token status when page opens
    context.read<TokenBloc>().add(const GetTokenStatus());
    // Load subscription status to check if user has active/cancelled subscription
    context.read<SubscriptionBloc>().add(const GetActiveSubscription());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh subscription data when returning to this page
    // This ensures we always have the latest subscription status
    if (ModalRoute.of(context)?.isCurrent == true) {
      debugPrint(
          '[TokenManagement] Page became visible - refreshing subscription and token status');
      context.read<SubscriptionBloc>().add(const RefreshSubscription());
      context.read<TokenBloc>().add(const RefreshTokenStatus());
    }
  }

  @override
  void dispose() {
    // Remove lifecycle observer
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // When app resumes, refresh token status and subscription status
    if (state == AppLifecycleState.resumed) {
      debugPrint(
          '[TokenManagement] App resumed - refreshing token and subscription status');
      context.read<TokenBloc>().add(const RefreshTokenStatus());
      context.read<SubscriptionBloc>().add(const RefreshSubscription());
    }
  }

  /// Get user email from auth state with fallback
  String _getUserEmail() {
    final authState = context.read<AuthBloc>().state;
    if (authState is auth_states.AuthenticatedState) {
      // Try auth email first, then profile email
      final email = authState.email ??
          authState.profile?['email'] as String? ??
          'nil@email.com';
      debugPrint('[TokenManagement] User email: $email');
      return email;
    }
    debugPrint('[TokenManagement] No auth state - using fallback email');
    return 'nil@email.com';
  }

  /// Get user phone from auth state with fallback
  String _getUserPhone() {
    final authState = context.read<AuthBloc>().state;
    if (authState is auth_states.AuthenticatedState) {
      // Try to get phone from profile or user metadata
      final phone = authState.profile?['phone'] as String? ??
          authState.user.userMetadata?['phone'] as String? ??
          authState.user.phone ??
          '+1234567890';
      debugPrint('[TokenManagement] User phone: $phone');
      return phone;
    }
    debugPrint('[TokenManagement] No auth state - using fallback phone');
    return '+1234567890';
  }

  void _showPurchaseDialog(TokenStatus tokenStatus) async {
    // Navigate to token purchase page
    debugPrint('[TokenManagementPage] Navigating to token purchase page');

    final result =
        await context.push(AppRoutes.tokenPurchase, extra: tokenStatus);

    // If purchase was successful (page returned true), refresh token status
    if (result == true && mounted) {
      debugPrint(
          '[TokenManagementPage] Purchase successful, refreshing token status');
      context.read<TokenBloc>().add(const RefreshTokenStatus());

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tokens purchased successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _upgradeToStandard() {
    // TODO: Implement upgrade to standard plan
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Plan upgrade coming soon!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// Opens payment gateway for the given order
  Future<void> _openPaymentGateway(
      String orderId, int tokenAmount, double amount, String keyId) async {
    try {
      debugPrint(
          '[TokenManagementPage] Opening payment gateway for order: $orderId');

      await PaymentService().openCheckout(
        orderId: orderId,
        amount: amount,
        description: '$tokenAmount tokens for Disciplefy Bible Study',
        userEmail: _getUserEmail(), // ✅ Get from authenticated user
        userPhone: _getUserPhone(), // ✅ Get from authenticated user
        keyId: keyId,
        onSuccess: (response) {
          debugPrint(
              '[TokenManagementPage] Payment gateway success - triggering confirmation');

          final paymentId = response.paymentId ?? '';
          final orderId = response.orderId ?? '';

          // Prevent duplicate confirmation calls
          if (_processingPayments.contains(paymentId)) {
            debugPrint(
                '[TokenManagementPage] ⚠️ Payment $paymentId already being processed - ignoring duplicate');
            return;
          }

          // Mark payment as being processed
          _processingPayments.add(paymentId);
          debugPrint(
              '[TokenManagementPage] 🔒 Payment $paymentId marked as processing');

          // Get current token amount from BLoC state
          final currentState = context.read<TokenBloc>().state;
          int tokenAmount = 50; // Default minimum

          // Extract token amount from TokenOrderCreated state
          if (currentState is TokenOrderCreated) {
            tokenAmount = currentState.tokensToPurchase;
          }

          debugPrint(
              '[TokenManagementPage] Payment success - confirming with $tokenAmount tokens');

          // Confirm payment
          context.read<TokenBloc>().add(
                ConfirmPayment(
                  paymentId: paymentId,
                  orderId: orderId,
                  signature: response.signature ?? '',
                  tokenAmount: tokenAmount,
                ),
              );
        },
        onError: (response) {
          debugPrint(
              '[TokenManagementPage] Payment gateway error: ${response.message}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Payment failed: ${response.message}'),
              backgroundColor: Colors.red,
            ),
          );
        },
      );
    } catch (e) {
      debugPrint('[TokenManagementPage] Error opening payment gateway: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening payment: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _upgradeToPremium() {
    // Navigate to premium upgrade page
    context.push(AppRoutes.premiumUpgrade);
  }

  void _manageSubscription() {
    // Navigate to subscription management page
    context.push(AppRoutes.subscriptionManagement);
  }

  void _viewPlanDetails() {
    // Navigate to subscription management page (same as manage)
    context.push(AppRoutes.subscriptionManagement);
  }

  void _resumeSubscription() {
    // Dispatch resume subscription event
    context.read<SubscriptionBloc>().add(const ResumeSubscription());
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        // Token BLoC listener for purchase success
        BlocListener<TokenBloc, TokenState>(
          listener: (context, state) {
            // Handle purchase success - refresh token status immediately
            if (state is TokenPurchaseSuccess) {
              debugPrint(
                  '[TokenManagementPage] TokenPurchaseSuccess received - refreshing token status');
              // Immediately refresh to get the latest balance
              context.read<TokenBloc>().add(const RefreshTokenStatus());
            }
          },
        ),
        // Subscription BLoC listener
        BlocListener<SubscriptionBloc, SubscriptionState>(
          listener: (context, state) {
            // Handle subscription resume success
            if (state is SubscriptionResumed) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.result.message),
                  backgroundColor: Colors.green,
                ),
              );
              // Refresh token status to update UI
              context.read<TokenBloc>().add(const RefreshTokenStatus());
              // Refresh subscription to clear pending_cancellation flag
              context.read<SubscriptionBloc>().add(const RefreshSubscription());
            }
            // Handle subscription resume error
            else if (state is SubscriptionError &&
                state.operation == 'resuming') {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.failure.message),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
        ),
      ],
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;

          // Handle Android back button - navigate back to generate study page
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            context.go('/generate-study');
          }
        },
        child: Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            elevation: 0,
            title: Text(
              context.tr('tokens.management.title'),
              style: AppFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            centerTitle: true,
            leading: IconButton(
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  context.go('/generate-study');
                }
              },
              icon: Icon(
                Icons.arrow_back,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            actions: [
              IconButton(
                onPressed: () {
                  context.push('/token-management/purchase-history');
                },
                icon: Icon(
                  Icons.history,
                  color: Theme.of(context).colorScheme.primary,
                ),
                tooltip: context.tr('tokens.management.view_history'),
              ),
              IconButton(
                onPressed: () {
                  context.read<TokenBloc>().add(const RefreshTokenStatus());
                },
                icon: Icon(
                  Icons.refresh,
                  color: Theme.of(context).colorScheme.primary,
                ),
                tooltip: context.tr('tokens.management.refresh_status'),
              ),
            ],
          ),
          body: BlocBuilder<TokenBloc, TokenState>(
            builder: (context, state) {
              // If state is not token-related, trigger token refresh
              // but only if this page is currently visible (not in background)
              if (state is PurchaseHistoryLoaded ||
                  state is PurchaseStatisticsLoaded ||
                  state is PurchaseHistoryError) {
                // Only trigger refresh if this page is currently visible
                if (ModalRoute.of(context)?.isCurrent == true) {
                  // Use post-frame callback to avoid calling add during build
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    context.read<TokenBloc>().add(const GetTokenStatus());
                  });
                }
              }

              if (state is TokenLoading) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              } else if (state is TokenError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        context.tr('tokens.management.load_error'),
                        style: AppFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onBackground,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        state.errorMessage,
                        style: AppFonts.inter(
                          fontSize: 14,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.7),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          context
                              .read<TokenBloc>()
                              .add(const RefreshTokenStatus());
                        },
                        child: Text(context.tr('common.retry')),
                      ),
                    ],
                  ),
                );
              } else if (state is TokenLoaded) {
                return _buildTokenManagement(state.tokenStatus);
              } else if (state is TokenPurchaseSuccess) {
                // Show updated balance immediately from purchase success state
                // while refresh is in progress
                return _buildTokenManagement(state.updatedTokenStatus);
              }

              // Handle any other unexpected states
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(context.tr('tokens.management.loading')),
                  ],
                ),
              );
            },
          ),
        ), // PopScope child: Scaffold
      ), // PopScope
    ); // MultiBlocListener
  }

  Widget _buildTokenManagement(TokenStatus tokenStatus) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: BlocBuilder<SubscriptionBloc, SubscriptionState>(
        builder: (context, subscriptionState) {
          // Check if subscription has pending cancellation
          bool isCancelledButActive = false;
          bool hasActiveSubscription = false;
          String? subscriptionPlanType;

          if (subscriptionState is SubscriptionLoaded &&
              subscriptionState.activeSubscription != null) {
            final sub = subscriptionState.activeSubscription!;
            // Check if subscription is in pending_cancellation status
            isCancelledButActive =
                sub.status == SubscriptionStatus.pending_cancellation;
            // Check if user has active subscription (any status that counts as active)
            hasActiveSubscription = sub.status == SubscriptionStatus.active ||
                sub.status == SubscriptionStatus.authenticated ||
                sub.status == SubscriptionStatus.created ||
                sub.status == SubscriptionStatus.pending_cancellation;
            subscriptionPlanType = sub.planType.toLowerCase();
          }

          // Determine if we should show manage subscription button
          // - Premium users: always show if they have an active subscription
          // - Standard users: show only if they have an active Standard subscription
          final bool showManageSubscription =
              (tokenStatus.userPlan == UserPlan.premium &&
                      hasActiveSubscription) ||
                  (tokenStatus.userPlan == UserPlan.standard &&
                      hasActiveSubscription &&
                      subscriptionPlanType?.contains('standard') == true);

          // Trial end date for Standard plan
          final trialEndDate = DateTime(2026, 3, 31);
          final isTrialActive = DateTime.now().isBefore(trialEndDate);

          // Standard user in trial (no subscription yet)
          final isStandardTrialUser =
              tokenStatus.userPlan == UserPlan.standard &&
                  isTrialActive &&
                  !hasActiveSubscription;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Token Balance Widget
              TokenBalanceWidget(
                tokenStatus: tokenStatus,
                showDetails: true,
                showRefreshButton: true,
                onRefresh: () {
                  context.read<TokenBloc>().add(const RefreshTokenStatus());
                },
              ),

              const SizedBox(height: 24),

              // Current Plan Section - now with unified "My Plan" button
              CurrentPlanSection(
                tokenStatus: tokenStatus,
                onMyPlan: () => context.push(AppRoutes.myPlan),
                isTrialActive: isStandardTrialUser,
                trialEndDate: isStandardTrialUser ? trialEndDate : null,
                isCancelledButActive: isCancelledButActive,
              ),

              const SizedBox(height: 24),

              // Actions Section
              TokenActionsSection(
                tokenStatus: tokenStatus,
                onPurchase: () => _showPurchaseDialog(tokenStatus),
                onUpgrade: tokenStatus.userPlan == UserPlan.free
                    ? _upgradeToStandard
                    : _upgradeToPremium,
                onViewHistory: () =>
                    context.push('/token-management/purchase-history'),
                onViewUsageHistory: () =>
                    context.push('/token-management/usage-history'),
              ),

              const SizedBox(height: 24),

              // Usage Information
              UsageInfoSection(tokenStatus: tokenStatus),

              const SizedBox(height: 24),

              // Plan Comparison
              PlanComparisonSection(tokenStatus: tokenStatus),
            ],
          );
        },
      ),
    );
  }
}
