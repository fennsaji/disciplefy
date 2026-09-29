import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/services/pricing_service.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/widgets/settings_sheet.dart';
import 'package:disciplefy_bible_study/features/subscription/domain/entities/user_subscription_status.dart';
import 'package:disciplefy_bible_study/features/subscription/presentation/bloc/subscription_bloc.dart';
import 'package:disciplefy_bible_study/features/subscription/presentation/bloc/subscription_event.dart';
import 'package:disciplefy_bible_study/features/subscription/presentation/bloc/subscription_state.dart';
import 'package:disciplefy_bible_study/features/subscription/presentation/widgets/subscription_legal_links.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/widgets/ledger_widgets.dart';

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
        final palette = ReaderPalette.of(context);
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: mediaQuery.size.height * 0.85),
          child: SettingsSheetFrame(
            children: [
              LedgerSectionLabel(
                'Standard Plan',
                padding: const EdgeInsets.only(bottom: 8),
              ),
              Text(
                widget.status.needsSubscription
                    ? 'Continue your spiritual journey'
                    : 'Subscribe before trial ends',
                style: AppFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: palette.text,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.end,
                spacing: 4,
                children: [
                  Text(
                    sl<PricingService>().getFormattedPrice('standard'),
                    style: AppFonts.poppins(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      color: palette.text,
                      height: 1.1,
                      fontFeatures: kLedgerTabular,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Text(
                      '/month',
                      style: AppFonts.inter(fontSize: 14, color: palette.muted),
                    ),
                  ),
                ],
              ),
              const LedgerHairline(verticalMargin: 14),
              _buildFeatureItem(
                context,
                Icons.menu_book_outlined,
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
              const SizedBox(height: 8),

              // Error message
              if (_errorMessage != null) ...[
                LedgerNotice(
                  icon: Icons.error_outline_rounded,
                  tone: LedgerTone.error,
                  text: _errorMessage!,
                ),
                const SizedBox(height: 12),
              ],

              // Subscribe button
              LedgerPrimaryButton(
                label: 'Subscribe Now',
                loading: _isLoading,
                onPressed: _handleSubscribe,
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
                style: AppFonts.inter(fontSize: 12.5, color: palette.muted),
              ),
              const SizedBox(height: 4),
              Text(
                'Cancel anytime. No commitments.',
                textAlign: TextAlign.center,
                style: AppFonts.inter(fontSize: 12.5, color: palette.dim),
              ),
            ],
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
    final palette = ReaderPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: palette.accentIcon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppFonts.inter(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: palette.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: AppFonts.inter(
                    fontSize: 13,
                    color: palette.muted,
                    height: 1.4,
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
