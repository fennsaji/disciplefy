import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
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
  @override
  void initState() {
    super.initState();
    // Load token status when page opens
    context.read<TokenBloc>().add(const GetTokenStatus());
  }

  void _showPurchaseDialog(TokenStatus tokenStatus) {
    showDialog(
      context: context,
      builder: (context) => TokenPurchaseDialog(
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
          // Handle order creation success
        },
        onPaymentSuccess: (response) {
          // Confirm payment
          context.read<TokenBloc>().add(
                ConfirmPayment(
                  paymentId: response.paymentId ?? '',
                  orderId: response.orderId ?? '',
                  signature: response.signature ?? '',
                  tokenAmount: 0, // TODO: Get from context
                ),
              );
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
      body: BlocBuilder<TokenBloc, TokenState>(
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
          }

          return const Center(
            child: Text('Loading token information...'),
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
