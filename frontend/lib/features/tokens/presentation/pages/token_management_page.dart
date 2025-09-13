import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/payment_service.dart';
import '../bloc/token_bloc.dart';
import '../bloc/token_event.dart';
import '../bloc/token_state.dart';
import '../widgets/token_balance_widget.dart';
import '../widgets/token_purchase_dialog.dart';
import '../widgets/current_plan_section.dart';
import '../widgets/token_actions_section.dart';
import '../widgets/usage_info_section.dart';
import '../widgets/plan_comparison_section.dart';
import '../../domain/entities/token_status.dart';

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

class _TokenManagementPageState extends State<TokenManagementPage> {
  // Payment confirmation guard to prevent duplicate calls
  final Set<String> _processingPayments = <String>{};

  @override
  void initState() {
    super.initState();
    // Load token status when page opens
    context.read<TokenBloc>().add(const GetTokenStatus());
  }

  void _showPurchaseDialog(TokenStatus tokenStatus) {
    showDialog(
      context: context,
      builder: (context) => BlocListener<TokenBloc, TokenState>(
        listener: (context, state) {
          if (state is TokenPurchaseSuccess) {
            // Payment confirmed successfully, close dialog
            debugPrint(
                '[TokenManagementPage] Payment confirmed, closing dialog');

            // Clean up processing payments set
            _processingPayments.clear();
            debugPrint(
                '[TokenManagementPage] 🧹 Processing payments cleared after success');

            Navigator.of(context).pop();

            // Show success message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Successfully purchased ${state.tokensPurchased} tokens!'),
                backgroundColor: Colors.green,
              ),
            );
          } else if (state is TokenError &&
              state.operation == 'payment_confirmation') {
            // Payment confirmation failed
            debugPrint(
                '[TokenManagementPage] Payment confirmation failed: ${state.failure.message}');

            // Clean up processing payments set on error
            _processingPayments.clear();
            debugPrint(
                '[TokenManagementPage] 🧹 Processing payments cleared after error');

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Payment confirmation failed: ${state.failure.message}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: TokenPurchaseDialog(
          tokenStatus: tokenStatus,
          // savedPaymentMethods defaults to const []
          // paymentPreferences defaults to null - TODO: Load payment preferences
          userEmail: 'user@example.com', // TODO: Get from auth
          userPhone: '+1234567890', // TODO: Get from auth
          onCreateOrder: (tokenAmount) {
            // Create payment order
            context.read<TokenBloc>().add(
                  CreatePaymentOrder(
                    tokenAmount: tokenAmount,
                  ),
                );
          },
          onOrderCreated: (orderId, tokenAmount, amount) {
            // Handle order creation success by opening payment gateway
            debugPrint(
                '[TokenManagementPage] Order created: $orderId for $tokenAmount tokens (₹$amount)');

            // Get the keyId from current BLoC state
            final currentState = context.read<TokenBloc>().state;
            String? keyId;
            if (currentState is TokenOrderCreated) {
              keyId = currentState.keyId;
            }

            // Open payment gateway with the created order
            _openPaymentGateway(orderId, tokenAmount, amount,
                keyId ?? 'rzp_test_RFzzBvMdQzOOyA');
          },
          onPaymentSuccess: (response) {
            debugPrint(
                '[TokenManagementPage] Payment success callback - already handled in _openPaymentGateway');
            // Payment confirmation is now handled in _openPaymentGateway method
          },
          onPaymentFailure: (response) {
            // Handle payment failure
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Payment failed: ${response.message}'),
                backgroundColor: Colors.red,
              ),
            );
          },
          onCancel: () {
            Navigator.of(context).pop();
          },
        ),
      ),
    );
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
        userEmail: 'user@example.com', // TODO: Get from auth
        userPhone: '+1234567890', // TODO: Get from auth
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
    // TODO: Implement upgrade to premium plan
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Premium upgrade coming soon!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: Text(
          'Token Management',
          style: GoogleFonts.playfairDisplay(
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
            tooltip: 'View purchase history',
          ),
          IconButton(
            onPressed: () {
              context.read<TokenBloc>().add(const RefreshTokenStatus());
            },
            icon: Icon(
              Icons.refresh,
              color: Theme.of(context).colorScheme.primary,
            ),
            tooltip: 'Refresh token status',
          ),
        ],
      ),
      body: BlocConsumer<TokenBloc, TokenState>(
        listener: (context, state) {
          // If we encounter a purchase-related state but need token info,
          // refresh the token status to get back to TokenLoaded state
          if (state is PurchaseHistoryLoaded ||
              state is PurchaseStatisticsLoaded ||
              state is PurchaseHistoryError) {
            // Only refresh if we don't already have token data from a previous TokenLoaded state
            context.read<TokenBloc>().add(const GetTokenStatus());
          }
        },
        builder: (context, state) {
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
                    'Failed to load token information',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onBackground,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.errorMessage,
                    style: GoogleFonts.inter(
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
                      context.read<TokenBloc>().add(const RefreshTokenStatus());
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          } else if (state is TokenLoaded) {
            return _buildTokenManagement(state.tokenStatus);
          } else if (state is PurchaseHistoryLoaded ||
              state is PurchaseStatisticsLoaded ||
              state is PurchaseHistoryError) {
            // Show loading while we refresh token status
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Refreshing token information...'),
                ],
              ),
            );
          }

          // Handle any other unexpected states
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading token information...'),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTokenManagement(TokenStatus tokenStatus) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
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

          // Current Plan Section
          CurrentPlanSection(
            tokenStatus: tokenStatus,
            onUpgrade: tokenStatus.userPlan == UserPlan.free
                ? _upgradeToStandard
                : _upgradeToPremium,
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
          ),

          const SizedBox(height: 24),

          // Usage Information
          UsageInfoSection(tokenStatus: tokenStatus),

          const SizedBox(height: 24),

          // Plan Comparison
          PlanComparisonSection(tokenStatus: tokenStatus),
        ],
      ),
    );
  }
}
