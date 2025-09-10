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
        onPurchase: (tokenAmount) {
          // Handle purchase logic here
          context.read<TokenBloc>().add(
                PurchaseTokens(
                  tokenAmount: tokenAmount,
                  paymentMethodId:
                      'razorpay', // Will be replaced with actual payment ID
                ),
              );
        },
        onCancel: () => Navigator.of(context).pop(),
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
          onPressed: () => context.go('/generate-study'),
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
          _buildCurrentPlanSection(tokenStatus),

          const SizedBox(height: 24),

          // Actions Section
          _buildActionsSection(tokenStatus),

          const SizedBox(height: 24),

          // Usage Information
          _buildUsageInformation(tokenStatus),

          const SizedBox(height: 24),

          // Plan Comparison
          _buildPlanComparison(tokenStatus),
        ],
      ),
    );
  }

  Widget _buildCurrentPlanSection(TokenStatus tokenStatus) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getPlanIcon(tokenStatus.userPlan),
                  color: _getPlanColor(tokenStatus.userPlan),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Current Plan',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getPlanColor(tokenStatus.userPlan).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color:
                          _getPlanColor(tokenStatus.userPlan).withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    tokenStatus.userPlan.displayName,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _getPlanColor(tokenStatus.userPlan),
                    ),
                  ),
                ),
                const Spacer(),
                if (tokenStatus.userPlan != UserPlan.premium)
                  OutlinedButton(
                    onPressed: tokenStatus.userPlan == UserPlan.free
                        ? _upgradeToStandard
                        : _upgradeToPremium,
                    child: Text(
                      tokenStatus.userPlan == UserPlan.free
                          ? 'Upgrade Plan'
                          : 'Go Premium',
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _getPlanDescription(tokenStatus.userPlan),
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsSection(TokenStatus tokenStatus) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Actions',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            if (tokenStatus.canPurchaseTokens) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showPurchaseDialog(tokenStatus),
                  icon: const Icon(Icons.add_shopping_cart),
                  label: const Text('Purchase Tokens'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (tokenStatus.userPlan == UserPlan.free) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _upgradeToStandard,
                  icon: const Icon(Icons.upgrade),
                  label: const Text('Upgrade to Standard'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ),
            ] else if (tokenStatus.userPlan == UserPlan.standard) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _upgradeToPremium,
                  icon: const Icon(Icons.star),
                  label: const Text('Upgrade to Premium'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber[700],
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUsageInformation(TokenStatus tokenStatus) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Usage Information',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            if (!tokenStatus.isPremium) ...[
              _buildInfoRow('Daily Limit', '${tokenStatus.dailyLimit} tokens'),
              _buildInfoRow(
                  'Daily Available', '${tokenStatus.availableTokens} tokens'),
              _buildInfoRow(
                  'Purchased Tokens', '${tokenStatus.purchasedTokens} tokens'),
              _buildInfoRow(
                  'Total Available', '${tokenStatus.totalTokens} tokens'),
              _buildInfoRow(
                  'Used Today', '${tokenStatus.totalConsumedToday} tokens'),
              _buildInfoRow('Next Reset', tokenStatus.formattedTimeUntilReset),
            ] else ...[
              Row(
                children: [
                  Icon(
                    Icons.all_inclusive,
                    color: Colors.amber[700],
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Unlimited tokens available',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.amber[700],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Generate as many study guides as you want!',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanComparison(TokenStatus tokenStatus) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Plan Comparison',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            _buildPlanCard(
              UserPlan.free,
              'Free Plan',
              '20 daily tokens',
              'Perfect for casual Bible study',
              tokenStatus.userPlan == UserPlan.free,
            ),
            const SizedBox(height: 12),
            _buildPlanCard(
              UserPlan.standard,
              'Standard Plan',
              '100 daily tokens + purchase more',
              'Great for regular study and group leaders',
              tokenStatus.userPlan == UserPlan.standard,
            ),
            const SizedBox(height: 12),
            _buildPlanCard(
              UserPlan.premium,
              'Premium Plan',
              'Unlimited tokens',
              'Best for pastors and heavy users',
              tokenStatus.userPlan == UserPlan.premium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard(UserPlan plan, String title, String subtitle,
      String description, bool isCurrentPlan) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCurrentPlan
            ? _getPlanColor(plan).withOpacity(0.1)
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentPlan
              ? _getPlanColor(plan)
              : Theme.of(context).colorScheme.outline.withOpacity(0.2),
          width: isCurrentPlan ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _getPlanIcon(plan),
            color: _getPlanColor(plan),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    if (isCurrentPlan) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getPlanColor(plan),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Current',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _getPlanColor(plan),
                  ),
                ),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getPlanIcon(UserPlan plan) {
    switch (plan) {
      case UserPlan.free:
        return Icons.person;
      case UserPlan.standard:
        return Icons.business;
      case UserPlan.premium:
        return Icons.star;
    }
  }

  Color _getPlanColor(UserPlan plan) {
    switch (plan) {
      case UserPlan.free:
        return Colors.grey[600]!;
      case UserPlan.standard:
        return Colors.blue[600]!;
      case UserPlan.premium:
        return Colors.amber[700]!;
    }
  }

  String _getPlanDescription(UserPlan plan) {
    switch (plan) {
      case UserPlan.free:
        return 'Get 20 daily tokens to generate Bible study guides. Perfect for personal study and exploration.';
      case UserPlan.standard:
        return 'Enjoy 100 daily tokens plus the ability to purchase additional tokens. Great for group leaders and regular users.';
      case UserPlan.premium:
        return 'Unlimited token access for unlimited Bible study generation. Perfect for pastors, teachers, and heavy users.';
    }
  }
}
