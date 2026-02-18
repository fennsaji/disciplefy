import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/auth_flow_service.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../bloc/auth_state.dart' as auth_states;
import '../../../../core/utils/logger.dart';

/// OAuth callback handler page
/// Processes authorization codes from OAuth providers (Google, Apple)
class AuthCallbackPage extends StatefulWidget {
  final String? code;
  final String? state;
  final String? error;
  final String? errorDescription;

  const AuthCallbackPage({
    super.key,
    this.code,
    this.state,
    this.error,
    this.errorDescription,
  });

  @override
  State<AuthCallbackPage> createState() => _AuthCallbackPageState();
}

class _AuthCallbackPageState extends State<AuthCallbackPage> {
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _processOAuthCallback();
    });
  }

  void _processOAuthCallback() {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    // Check for OAuth error first
    if (widget.error != null) {
      _handleOAuthError();
      return;
    }

    // INFO: With native Supabase PKCE flow, this Flutter callback route should NOT be reached
    // If we're here, it means either: 1) Fallback from error, 2) Legacy OAuth flow, or 3) Misconfiguration
    Logger.debug(
        'ℹ️ [AUTH CALLBACK] Flutter callback page reached - checking for session...');
    Logger.debug(
        'ℹ️ [AUTH CALLBACK] Native PKCE should bypass this route entirely');

    // Instead of processing custom callbacks, just check session and redirect
    _checkSupabaseSessionAndRedirect();
  }

  void _checkSupabaseSessionAndRedirect() async {
    Logger.warning(
        '🔍 [AUTH CALLBACK] 🔍 Checking Supabase session for PKCE flow...');
    Logger.warning(
        '🔍 [AUTH CALLBACK] ⚠️ WARNING: This Flutter callback should NOT be reached with corrected PKCE');
    Logger.warning(
        '🔍 [AUTH CALLBACK] ⚠️ Expected: Google → 127.0.0.1:54321/auth/v1/callback → Supabase handles natively');
    Logger.warning(
        '🔍 [AUTH CALLBACK] ⚠️ Actual: Google → localhost:59641/auth/callback → Flutter app (INCORRECT)');

    // For corrected PKCE flow, session should already be established by Supabase
    final session = Supabase.instance.client.auth.currentSession;

    if (session != null) {
      Logger.debug(
          '🔍 [AUTH CALLBACK] ✅ Session found despite incorrect callback routing');
      Logger.debug('🔍 [AUTH CALLBACK] - User: ${session.user.email}');
      Logger.debug(
          '🔍 [AUTH CALLBACK] - Provider: ${session.user.appMetadata['provider'] ?? 'unknown'}');
      Logger.debug(
          '🔍 [AUTH CALLBACK] - This suggests OAuth worked but configuration needs fixing');

      // Session exists, trigger authentication success
      context.read<AuthBloc>().add(const SessionCheckRequested());

      // Check if user needs language selection before redirecting
      _checkLanguageSelectionAndRedirect();
    } else {
      Logger.error('🔍 [AUTH CALLBACK] ❌ No session found - PKCE flow failed');
      Logger.debug('🔍 [AUTH CALLBACK] ❌ This indicates configuration issues:');
      Logger.error(
          '🔍 [AUTH CALLBACK] ❌ 1. Google OAuth redirect URI mismatch');
      Logger.error(
          '🔍 [AUTH CALLBACK] ❌ 2. Supabase config.toml not updated correctly');
      Logger.error(
          '🔍 [AUTH CALLBACK] ❌ 3. Supabase server not running on 127.0.0.1:54321');

      // Wait briefly to see if session gets established
      Logger.debug(
          '🔍 [AUTH CALLBACK] ⏳ Waiting 3 seconds for delayed session establishment...');
      await Future.delayed(const Duration(seconds: 3));

      final laterSession = Supabase.instance.client.auth.currentSession;
      if (laterSession != null) {
        Logger.debug(
            '🔍 [AUTH CALLBACK] ✅ Session established after delay - proceeding');
        context.read<AuthBloc>().add(const SessionCheckRequested());
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            context.go('/');
          }
        });
      } else {
        _showErrorAndRedirect(
            'PKCE OAuth flow failed. Check configuration and Supabase server status.');
      }
    }
  }

  void _handleMissingSession() {
    _showErrorAndRedirect('Authentication session could not be established');
  }

  void _handleOAuthError() {
    String errorMessage = 'Authentication failed';

    if (widget.error == 'access_denied') {
      errorMessage = 'Authentication cancelled by user';
    } else if (widget.errorDescription != null) {
      errorMessage = widget.errorDescription!;
    } else if (widget.error != null) {
      errorMessage = 'Error: ${widget.error}';
    }

    _showErrorAndRedirect(errorMessage);
  }

  void _handleMissingCode() {
    _showErrorAndRedirect('No authorization code received from OAuth provider');
  }

  void _showErrorAndRedirect(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );

    // Redirect to login after showing error
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        context.go('/login');
      }
    });
  }

  @override
  Widget build(BuildContext context) =>
      BlocListener<AuthBloc, auth_states.AuthState>(
        listener: (context, state) {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          Logger.debug(
              '🔍 [AUTH CALLBACK] 📊 State change detected at: $timestamp');
          Logger.debug(
              '🔍 [AUTH CALLBACK] 📊 State type: ${state.runtimeType}');

          if (state is auth_states.AuthenticatedState) {
            // Success - navigate to home
            Logger.debug(
                '🔍 [AUTH CALLBACK] ✅ Authentication successful, navigating to home...');
            Logger.debug(
                '🔍 [AUTH CALLBACK] - User: ${state.user.email ?? "Anonymous"}');
            Logger.debug('🔍 [AUTH CALLBACK] - User ID: ${state.user.id}');
            Logger.debug(
                '🔍 [AUTH CALLBACK] - Is Anonymous: ${state.isAnonymous}');
            Logger.debug('🔍 [AUTH CALLBACK] - Timestamp: $timestamp');

            // Add a small delay to ensure storage operations complete
            Logger.debug(
                '🔍 [AUTH CALLBACK] ⏱️ Adding 100ms delay for storage completion...');
            Future.delayed(const Duration(milliseconds: 100), () {
              Logger.debug(
                  '🔍 [AUTH CALLBACK] - About to call context.go("/")');
              // Clear any URL fragments and navigate to home
              // This ensures OAuth callback properly redirects regardless of preserved fragments
              context.go('/');
              Logger.debug(
                  '🔍 [AUTH CALLBACK] - context.go("/") completed at: ${DateTime.now().millisecondsSinceEpoch}');
            });
          } else if (state is auth_states.AuthErrorState) {
            // Error - show message and redirect to login
            Logger.error(
                '🔍 [AUTH CALLBACK] ❌ Authentication failed: ${state.message}');
            _showErrorAndRedirect(state.message);
          }
        },
        child: Scaffold(
          backgroundColor: AppTheme.backgroundColor,
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Loading animation
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const CircularProgressIndicator(
                        color: AppTheme.primaryColor,
                        strokeWidth: 3,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Processing text
                    Text(
                      _getProcessingText(),
                      style: AppFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 16),

                    // Status message
                    Text(
                      _getStatusMessage(),
                      style: AppFonts.inter(
                        fontSize: 14,
                        color: AppTheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 48),

                    // Debug info (only in debug mode)
                    if (_shouldShowDebugInfo()) _buildDebugInfo(),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

  String _getProcessingText() {
    if (widget.error != null) {
      return 'Authentication Error';
    } else if (widget.code != null) {
      return 'Signing you in...';
    } else {
      return 'Processing...';
    }
  }

  String _getStatusMessage() {
    if (widget.error != null) {
      return 'We encountered an issue during authentication. You\'ll be redirected to try again.';
    } else if (widget.code != null) {
      return 'We\'re completing your Google sign-in. This should only take a moment.';
    } else {
      return 'Please wait while we process your authentication request.';
    }
  }

  bool _shouldShowDebugInfo() {
    // Only show debug info in debug mode and if there are parameters
    return false; // Set to true for debugging
  }

  Widget _buildDebugInfo() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.primaryColor.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Debug Info:',
              style: AppFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            if (widget.code != null)
              _buildDebugItem('Code', '${widget.code!.substring(0, 20)}...'),
            if (widget.state != null) _buildDebugItem('State', widget.state!),
            if (widget.error != null) _buildDebugItem('Error', widget.error!),
            if (widget.errorDescription != null)
              _buildDebugItem('Error Description', widget.errorDescription!),
          ],
        ),
      );

  Widget _buildDebugItem(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$label: ',
              style: AppFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppTheme.onSurfaceVariant,
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: AppFonts.inter(
                  fontSize: 11,
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );

  void _checkLanguageSelectionAndRedirect() async {
    try {
      // Check if user needs language selection
      final shouldShowLanguageSelection =
          await AuthFlowService.shouldShowLanguageSelection();

      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          if (shouldShowLanguageSelection) {
            context.go('/language-selection');
          } else {
            context.go('/');
          }
        }
      });
    } catch (e) {
      Logger.debug('Error checking language selection: $e');
      // Fallback to home on error
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          context.go('/');
        }
      });
    }
  }
}
