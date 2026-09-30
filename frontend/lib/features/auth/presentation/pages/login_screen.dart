import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../../core/constants/app_fonts.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart' as auth_states;
import '../../../../core/services/auth_aware_navigation_service.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/widgets/terms_acceptance_checkbox.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/shared/widgets/welcome_chrome.dart';
import 'package:disciplefy_bible_study/shared/widgets/app_snackbar.dart';

/// Login screen: photo header, feature chips and Google / Apple / email
/// sign-in pills ("V1 Photo Story" design, dark and light).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Flag to prevent navigation conflicts during phone auth flow
  final bool _isPhoneAuthInProgress = false;

  @override
  void initState() {
    super.initState();
    _checkAuthenticationStatus();
  }

  /// Returns the pending deep-link redirect target, checking URL param first
  /// (works for email auth) then Hive storage (survives OAuth round-trip).
  /// Returns null if the target is not a relative path (starts with '/').
  ///
  /// Deletes the Hive key once it decides to navigate straight to the
  /// target: RouterGuard only ever consumes/deletes it when the redirect
  /// lands on home, so a direct navigation to the deep-link target itself
  /// (the normal case) left the key behind forever — every later login,
  /// including ones with no deep link involved, then replayed that stale
  /// target. Consuming it here closes that leak.
  String? _consumeRedirectTarget(BuildContext context) {
    final box = Hive.box('app_settings');

    // URL param is present for same-page flows (email auth)
    String? fromUrl;
    try {
      fromUrl = GoRouterState.of(context).uri.queryParameters['redirect'];
    } catch (_) {}
    if (fromUrl != null && fromUrl.isNotEmpty) {
      final decoded = Uri.decodeComponent(fromUrl);
      if (!decoded.startsWith('/')) return null; // reject absolute URLs
      box.delete('pending_deep_link_redirect');
      return decoded;
    }
    // Hive key is written before launching Google OAuth so it survives the
    // browser round-trip to Google and back to the OAuth callback URL.
    final fromHive = box.get('pending_deep_link_redirect') as String?;
    if (fromHive != null && fromHive.isNotEmpty) {
      final decoded = Uri.decodeComponent(fromHive);
      box.delete('pending_deep_link_redirect');
      if (!decoded.startsWith('/')) return null; // reject absolute URLs
      return decoded;
    }
    return null;
  }

  /// Check if user is already authenticated and redirect if needed
  void _checkAuthenticationStatus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = context.read<AuthBloc>().state;
      if (authState is auth_states.AuthenticatedState) {
        // Check for pending premium upgrade from pricing page
        final box = Hive.box('app_settings');
        final pendingPremiumUpgrade =
            box.get('pending_premium_upgrade', defaultValue: false);

        if (pendingPremiumUpgrade == true) {
          // Clear the flag and redirect to premium upgrade page
          box.delete('pending_premium_upgrade');
          Logger.info(
            'Authenticated user on login - redirecting to premium upgrade',
            tag: 'LOGIN_SCREEN',
            context: {
              'user_type': 'authenticated',
              'redirect_reason': 'pending_premium_upgrade',
            },
          );
          context.go(AppRoutes.premiumUpgrade);
        } else {
          Logger.info(
            'Authenticated user detected on login screen - redirecting',
            tag: 'LOGIN_SCREEN',
            context: {
              'user_type': 'authenticated',
              'redirect_reason': 'already_authenticated',
            },
          );
          final redirectTo = _consumeRedirectTarget(context);
          if (redirectTo != null) {
            context.go(redirectTo);
            return;
          }
          // Use AuthAwareNavigationService for proper stack management
          context.navigateAfterAuth();
        }
      }
      // No automatic sign-in - users must explicitly choose authentication method
    });
  }

  @override
  Widget build(BuildContext context) =>
      BlocListener<AuthBloc, auth_states.AuthState>(
        listener: (context, state) {
          if (state is auth_states.AuthenticatedState) {
            // PRIORITY: Check for pending premium upgrade from pricing page FIRST
            // This must happen before phone auth check to ensure premium redirect works
            final box = Hive.box('app_settings');
            final pendingPremiumUpgrade =
                box.get('pending_premium_upgrade', defaultValue: false);

            if (pendingPremiumUpgrade == true) {
              // Clear the flag and redirect to premium upgrade page
              box.delete('pending_premium_upgrade');
              Logger.info(
                'Authentication successful - redirecting to premium upgrade',
                tag: 'LOGIN_SCREEN',
                context: {
                  'user_type': 'authenticated',
                  'redirect_reason': 'pending_premium_upgrade',
                },
              );
              context.go(AppRoutes.premiumUpgrade);
              return;
            }

            // Check for deep link redirect (URL param or Hive, OAuth-safe)
            final redirectTo = _consumeRedirectTarget(context);
            if (redirectTo != null) {
              context.go(redirectTo);
              return;
            }

            // Check if this is a phone auth user by checking if they have a phone number
            final isPhoneAuthUser =
                state.user.phone != null && state.user.phone!.isNotEmpty;

            if (isPhoneAuthUser) {
              Logger.info(
                'Phone auth user detected - letting router handle navigation',
                tag: 'LOGIN_SCREEN',
                context: {
                  'user_type': 'phone_auth',
                  'phone': state.user.phone,
                  'skip_navigation': 'router_will_handle',
                },
              );
              // Don't navigate for phone auth users - let the router handle it
              // This prevents conflicts with OTP verification screen navigation
              return;
            }

            Logger.info(
              'Authentication successful - navigating to home',
              tag: 'LOGIN_SCREEN',
              context: {
                'user_type': 'authenticated',
                'navigation_method': 'auth_aware_service',
              },
            );
            // Use AuthAwareNavigationService for proper post-auth navigation
            context.navigateAfterAuth();
          } else if (state is auth_states.AuthErrorState) {
            Logger.error(
              'Authentication error occurred',
              tag: 'LOGIN_SCREEN',
              context: {
                'error_message': state.message,
                'is_cancelled': state.message.contains('canceled') ||
                    state.message.contains('cancelled'),
              },
            );
            // Handle different types of errors
            final theme = Theme.of(context);
            if (state.message.contains('canceled') ||
                state.message.contains('cancelled')) {
              // Show neutral snackbar for cancelled operations
              showAppSnackBar(
                context,
                context.tr(TranslationKeys.authSignInCancelled),
              );
            } else {
              // Show error message for actual errors
              showAppSnackBar(
                context,
                context.tr(TranslationKeys.commonErrorTryAgain),
                tone: AppSnackTone.error,
              );
            }
          }
        },
        child: Scaffold(
          backgroundColor: ReaderPalette.of(context).page,
          body: LayoutBuilder(
            builder: (context, constraints) {
              final topInset = MediaQuery.paddingOf(context).top;
              // Gap between the brand row and the title: generous on tall
              // screens, tight on short ones — small enough that the
              // feature descriptions still leave the sign-in buttons on
              // screen on a typical phone.
              final titleGap =
                  (constraints.maxHeight * 0.12).clamp(24.0, 180.0);
              final photoHeight = topInset + 60 + titleGap + 250;

              return SingleChildScrollView(
                child: Stack(
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: photoHeight,
                      child: const WelcomePhotoBackdrop(
                        asset: WelcomePhotos.winterSunset,
                        alignment: Alignment.bottomCenter,
                      ),
                    ),
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            24,
                            topInset + 20,
                            24,
                            MediaQuery.paddingOf(context).bottom + 20,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Brand row (logo + wordmark)
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: WelcomeBrandRow(),
                              ),
                              SizedBox(height: titleGap),

                              // Welcome text
                              _buildWelcomeText(context),

                              const SizedBox(height: 22),

                              // Features preview chips
                              _buildFeaturesSection(context),

                              const SizedBox(height: 22),

                              // Sign-in buttons
                              _buildSignInButtons(context),

                              // Consent is implicit: continuing with any
                              // sign-in method accepts the Terms and Privacy
                              // Policy shown here, recorded when a sign-in
                              // button is tapped. It sits right under the
                              // buttons so it's on screen whenever they are.
                              const SizedBox(height: 12),
                              LegalLinksLine(
                                textColor: ReaderPalette.of(context).dim,
                                linkColor: ReaderPalette.of(context).muted,
                              ),
                              const SizedBox(height: 14),
                              _buildLanguagesRow(context),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );

  /// Builds the welcome text section
  Widget _buildWelcomeText(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final isNarrow = MediaQuery.sizeOf(context).width < 360;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WelcomeTitle(
          context.tr(TranslationKeys.loginWelcome),
          fontSize: isNarrow ? 28 : 34,
        ),
        const SizedBox(height: 10),
        Text(
          context.tr(TranslationKeys.loginSubtitle),
          style: AppFonts.inter(
            fontSize: 15.5,
            height: 1.45,
            color: palette.isDark
                ? Colors.white.withValues(alpha: 0.78)
                : palette.muted,
          ),
        ),
      ],
    );
  }

  /// "What you'll get:" and a 2x2 grid of feature chips.
  Widget _buildFeaturesSection(BuildContext context) {
    final palette = ReaderPalette.of(context);

    Widget row(Widget a, Widget b) => IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: a),
              const SizedBox(width: 8),
              Expanded(child: b),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr(TranslationKeys.loginFeaturesTitle),
          style: AppFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
            color: palette.muted,
          ),
        ),
        const SizedBox(height: 10),
        row(
          _FeatureChip(
            icon: Icons.auto_awesome_outlined,
            label: context.tr(TranslationKeys.loginChipStudyGuides),
            detail:
                context.tr(TranslationKeys.loginFeatureAiStudyGuidesSubtitle),
          ),
          _FeatureChip(
            icon: Icons.wb_sunny_outlined,
            label: context.tr(TranslationKeys.loginChipDailyVerse),
            detail: context.tr(TranslationKeys.loginFeatureDailyVerseSubtitle),
          ),
        ),
        const SizedBox(height: 8),
        row(
          _FeatureChip(
            icon: Icons.mic_none_rounded,
            label: context.tr(TranslationKeys.loginChipDiscipler),
            detail:
                context.tr(TranslationKeys.loginFeatureVoiceDisciplerSubtitle),
          ),
          _FeatureChip(
            icon: Icons.psychology_outlined,
            label: context.tr(TranslationKeys.loginChipMemoryVerses),
            detail: context.tr(TranslationKeys.loginFeatureMemoryVerseSubtitle),
          ),
        ),
      ],
    );
  }

  /// Globe + "English · Hindi · Malayalam".
  Widget _buildLanguagesRow(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.language, size: 16, color: palette.muted),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              context.tr(TranslationKeys.loginLanguagesLine),
              textAlign: TextAlign.center,
              style: AppFonts.inter(fontSize: 14, color: palette.muted),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the sign-in buttons with proper state management
  Widget _buildSignInButtons(BuildContext context) =>
      BlocBuilder<AuthBloc, auth_states.AuthState>(
        builder: (context, state) {
          final isLoading = state is auth_states.AuthLoadingState;
          final isBlocked = isLoading;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Google Sign-In Button
              _buildGoogleSignInButton(context, isBlocked, isLoading),

              const SizedBox(height: 12),

              // Apple Sign-In Button — iOS only (required by App Store
              // Guideline 4.8 when other social logins are offered).
              if (!kIsWeb && Platform.isIOS) ...[
                _buildAppleSignInButton(context, isBlocked, isLoading),
                const SizedBox(height: 12),
              ],

              // Email Sign-In Button
              _buildEmailSignInButton(context, isBlocked),

              const SizedBox(height: 12),

              // Phone sign-in and guest mode are disabled: all users sign in
              // with Google, Apple or email.
            ],
          );
        },
      );

  /// Shared pill shape for the sign-in buttons.
  ButtonStyle _pillStyle({
    required Color background,
    required Color foreground,
    required BorderSide side,
  }) =>
      OutlinedButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        disabledBackgroundColor: background.withValues(
          alpha: background.a * 0.6,
        ),
        disabledForegroundColor: foreground.withValues(alpha: 0.6),
        side: side,
        shape: const StadiumBorder(),
        minimumSize: const Size.fromHeight(54),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      );

  /// Label row used inside the sign-in pills.
  Widget _pillLabel(Widget icon, String label, Color color) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icon,
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: AppFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      );

  /// Builds the Google sign-in button: a white pill with the multicolour
  /// Google mark (Google branding guidelines allow the white "light" button
  /// on either theme).
  Widget _buildGoogleSignInButton(
      BuildContext context, bool isDisabled, bool isLoading) {
    final palette = ReaderPalette.of(context);
    final textColor =
        palette.isDark ? AppColors.brandPrimaryInk : const Color(0xFF1F1F1F);

    return OutlinedButton(
      onPressed: isDisabled ? null : () => _handleGoogleSignIn(context),
      style: _pillStyle(
        background: Colors.white,
        foreground: textColor,
        side: palette.isDark
            ? BorderSide.none
            : BorderSide(color: palette.outline),
      ),
      child: isLoading
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(textColor),
              ),
            )
          : _pillLabel(
              Image.asset(
                'assets/images/google_logo_96.png',
                width: 20,
                height: 20,
              ),
              context.tr(TranslationKeys.loginContinueWithGoogle),
              textColor,
            ),
    );
  }

  /// Builds the email sign-in button (outlined pill).
  Widget _buildEmailSignInButton(BuildContext context, bool isDisabled) {
    final palette = ReaderPalette.of(context);

    return OutlinedButton(
      onPressed: isDisabled ? null : () => _handleEmailSignIn(context),
      style: _pillStyle(
        background: Colors.transparent,
        foreground: palette.text,
        side: BorderSide(color: palette.outline),
      ),
      child: _pillLabel(
        Icon(Icons.mail_outline_rounded, size: 21, color: palette.text),
        context.tr(TranslationKeys.loginContinueWithEmail),
        palette.text,
      ),
    );
  }

  /// Builds the Sign in with Apple button (iOS only): outlined white on the
  /// dark page, solid black with white label on the light page, per Apple's
  /// Human Interface Guidelines.
  Widget _buildAppleSignInButton(
      BuildContext context, bool isDisabled, bool isLoading) {
    final palette = ReaderPalette.of(context);
    final bgColor = palette.isDark ? Colors.transparent : Colors.black;
    const fgColor = Colors.white;

    return OutlinedButton(
      onPressed: isDisabled ? null : () => _handleAppleSignIn(context),
      style: _pillStyle(
        background: bgColor,
        foreground: fgColor,
        side: palette.isDark
            ? BorderSide(color: palette.outline)
            : BorderSide.none,
      ),
      child: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(fgColor),
              ),
            )
          : _pillLabel(
              const Icon(Icons.apple, color: fgColor, size: 22),
              context.tr(TranslationKeys.loginContinueWithApple),
              fgColor,
            ),
    );
  }

  /// Handles Apple sign-in button tap
  void _handleAppleSignIn(BuildContext context) {
    Hive.box('app_settings').put('terms_accepted', true);
    String? redirectTo;
    try {
      redirectTo = GoRouterState.of(context).uri.queryParameters['redirect'];
    } catch (_) {}
    if (redirectTo != null && redirectTo.isNotEmpty) {
      Hive.box('app_settings').put('pending_deep_link_redirect', redirectTo);
    }
    context.read<AuthBloc>().add(const AppleSignInRequested());
  }

  /// Handles Google sign-in button tap
  void _handleGoogleSignIn(BuildContext context) {
    Hive.box('app_settings').put('terms_accepted', true);
    // Persist redirect target before OAuth so it survives the browser round-trip
    // to Google and back (the ?redirect= URL param is lost after the callback).
    String? redirectTo;
    try {
      redirectTo = GoRouterState.of(context).uri.queryParameters['redirect'];
    } catch (_) {}
    if (redirectTo != null && redirectTo.isNotEmpty) {
      Hive.box('app_settings').put('pending_deep_link_redirect', redirectTo);
    }
    context.read<AuthBloc>().add(const GoogleSignInRequested());
  }

  /// Handles email sign-in button tap
  void _handleEmailSignIn(BuildContext context) {
    Hive.box('app_settings').put('terms_accepted', true);
    context.push(AppRoutes.emailAuth);
  }

  /// Handles phone sign-in button tap - COMMENTED OUT FOR NOW
  // void _handlePhoneSignIn(BuildContext context) {
  //   context.push(AppRoutes.phoneAuth);
  // }
}

/// One "What you'll get" chip: gold icon + short label.
class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;

  /// One-line description of the feature under its name.
  final String detail;

  const _FeatureChip({
    required this.icon,
    required this.label,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);

    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: palette.isDark
            ? Colors.white.withValues(alpha: 0.05)
            : palette.raised.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.hairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 18, color: palette.gold),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: palette.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: AppFonts.inter(
                    fontSize: 12,
                    height: 1.35,
                    color: palette.muted,
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
