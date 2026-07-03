import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import 'subscription_legal_links.dart';
import '../../domain/entities/user_subscription_status.dart';
import '../../../../core/services/pricing_service.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../bloc/subscription_bloc.dart';
import '../bloc/subscription_event.dart';
import '../bloc/subscription_state.dart';

/// Bottom sheet for Standard subscription showing benefits and subscribe button.
/// Uses BlocConsumer to react to SubscriptionCreated/Error/Loaded states directly,
/// so the URL from Razorpay is opened even though the sheet is a separate route.
class StandardSubscriptionSheet extends StatefulWidget {
  final UserSubscriptionStatus status;

  const StandardSubscriptionSheet({
    super.key,
    required this.status,
  });

  static Future<void> show(
    BuildContext context, {
    required UserSubscriptionStatus status,
  }) {
    final bloc = sl<SubscriptionBloc>();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BlocProvider.value(
        value: bloc,
        child: StandardSubscriptionSheet(status: status),
      ),
    );
  }

  @override
  State<StandardSubscriptionSheet> createState() =>
      _StandardSubscriptionSheetState();
}

class _StandardSubscriptionSheetState extends State<StandardSubscriptionSheet> {
  bool _isLoading = false;
  String? _errorMessage;
  bool _hasOpenedPayment = false;
  Timer? _pollTimer;
  int _pollCount = 0;
  static const int _maxPollCount = 120; // 10 minutes at 5s intervals

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollCount = 0;
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) {
        _pollTimer?.cancel();
        return;
      }
      _pollCount++;
      if (_pollCount > _maxPollCount) {
        _pollTimer?.cancel();
        return;
      }
      context.read<SubscriptionBloc>().add(const RefreshSubscription());
    });
  }

  void _handleSubscribe() {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    context.read<SubscriptionBloc>().add(CreateStandardSubscription());
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);

    return BlocConsumer<SubscriptionBloc, SubscriptionState>(
      listener: (context, state) {
        if (state is SubscriptionLoading) {
          setState(() {
            _isLoading = true;
            _errorMessage = null;
          });
        } else if (state is SubscriptionCreated) {
          setState(() => _isLoading = false);
          if (state.authorizationUrl.isNotEmpty) {
            _hasOpenedPayment = true;
            _launchUrl(state.authorizationUrl);
            if (kIsWeb) _startPolling();
          }
        } else if (state is SubscriptionLoaded) {
          setState(() => _isLoading = false);
          if (_hasOpenedPayment && state.activeSubscription?.isActive == true) {
            _pollTimer?.cancel();
            if (mounted) Navigator.of(context).pop();
          }
        } else if (state is SubscriptionError) {
          setState(() {
            _isLoading = false;
            _errorMessage = state.errorMessage;
          });
        } else if (state is SubscriptionInitial) {
          setState(() => _isLoading = false);
        }
      },
      builder: (context, state) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: mediaQuery.size.height * 0.85,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Drag handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color:
                              theme.colorScheme.outline.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6A4FB6), Color(0xFF8B5CF6)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.auto_awesome,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Standard Plan',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.status.needsSubscription
                                    ? 'Continue your spiritual journey'
                                    : 'Subscribe before trial ends',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Price card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3E8FF),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFD8B4FE),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            sl<PricingService>().getFormattedPrice('standard'),
                            style: theme.textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              '/month',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Features list
                    Text(
                      'What you get:',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildFeatureItem(
                      context,
                      Icons.book_outlined,
                      'In-depth Bible Studies',
                      'Get personalized study guides for any verse or topic',
                    ),
                    _buildFeatureItem(
                      context,
                      Icons.auto_stories_outlined,
                      'Unlimited Study Guides',
                      'Create as many study guides as you need',
                    ),
                    _buildFeatureItem(
                      context,
                      Icons.history_outlined,
                      'Study History',
                      'Access all your previous study guides',
                    ),
                    _buildFeatureItem(
                      context,
                      Icons.bookmark_outline,
                      'Bookmarks & Notes',
                      'Save and organize your favorite studies',
                    ),
                    const SizedBox(height: 24),

                    // Error message
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: theme.colorScheme.error,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Subscribe button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleSubscribe,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.appInteractive,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Subscribe Now',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                    const SizedBox(height: 12),

                    // Required: functional Terms of Use (EULA) + Privacy Policy links.
                    const SubscriptionLegalLinks(),
                    const SizedBox(height: 12),

                    // Trial info or cancel info
                    Text(
                      widget.status.needsSubscription
                          ? 'Your trial has ended. Subscribe to continue.'
                          : 'Free until ${widget.status.formattedTrialEndDate ?? "March 31, 2027"}',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Cancel anytime. No commitments.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFeatureItem(
    BuildContext context,
    IconData icon,
    String title,
    String description,
  ) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF3E8FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
