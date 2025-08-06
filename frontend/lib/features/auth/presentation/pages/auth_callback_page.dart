import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../bloc/auth_state.dart' as auth_states;

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
    print(
        'ℹ️ [AUTH CALLBACK] Flutter callback page reached - checking for session...');
    print('ℹ️ [AUTH CALLBACK] Native PKCE should bypass this route entirely');

    // Instead of processing custom callbacks, just check session and redirect
    _checkSupabaseSessionAndRedirect();
  }

  void _checkSupabaseSessionAndRedirect() async {
    print('🔍 [AUTH CALLBACK] 🔍 Checking Supabase session for PKCE flow...');
    print(
        '🔍 [AUTH CALLBACK] ⚠️ WARNING: This Flutter callback should NOT be reached with corrected PKCE');
    print(
        '🔍 [AUTH CALLBACK] ⚠️ Expected: Google → 127.0.0.1:54321/auth/v1/callback → Supabase handles natively');
    print(
        '🔍 [AUTH CALLBACK] ⚠️ Actual: Google → localhost:59641/auth/callback → Flutter app (INCORRECT)');

    // For corrected PKCE flow, session should already be established by Supabase
    final session = Supabase.instance.client.auth.currentSession;

    if (session != null) {
      print(
          '🔍 [AUTH CALLBACK] ✅ Session found despite incorrect callback routing');
      print('🔍 [AUTH CALLBACK] - User: ${session.user.email}');
      print(
          '🔍 [AUTH CALLBACK] - Provider: ${session.user.appMetadata['provider'] ?? 'unknown'}');
      print(
          '🔍 [AUTH CALLBACK] - This suggests OAuth worked but configuration needs fixing');

      // Session exists, trigger authentication success and redirect
      context.read<AuthBloc>().add(const SessionCheckRequested());

      // Redirect to home since session is established
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          context.go('/');
        }
      });
    } else {
      print('🔍 [AUTH CALLBACK] ❌ No session found - PKCE flow failed');
      print('🔍 [AUTH CALLBACK] ❌ This indicates configuration issues:');
      print('🔍 [AUTH CALLBACK] ❌ 1. Google OAuth redirect URI mismatch');
      print(
          '🔍 [AUTH CALLBACK] ❌ 2. Supabase config.toml not updated correctly');
      print(
          '🔍 [AUTH CALLBACK] ❌ 3. Supabase server not running on 127.0.0.1:54321');

      // Wait briefly to see if session gets established
      print(
          '🔍 [AUTH CALLBACK] ⏳ Waiting 3 seconds for delayed session establishment...');
      await Future.delayed(const Duration(seconds: 3));

      final laterSession = Supabase.instance.client.auth.currentSession;
      if (laterSession != null) {
        print(
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
          print('🔍 [AUTH CALLBACK] 📊 State change detected at: $timestamp');
          print('🔍 [AUTH CALLBACK] 📊 State type: ${state.runtimeType}');

          if (state is auth_states.AuthenticatedState) {
            // Success - navigate to home
            print(
                '🔍 [AUTH CALLBACK] ✅ Authentication successful, navigating to home...');
            print(
                '🔍 [AUTH CALLBACK] - User: ${state.user.email ?? "Anonymous"}');
            print('🔍 [AUTH CALLBACK] - User ID: ${state.user.id}');
            print('🔍 [AUTH CALLBACK] - Is Anonymous: ${state.isAnonymous}');
            print('🔍 [AUTH CALLBACK] - Timestamp: $timestamp');

            // Add a small delay to ensure storage operations complete
            print(
                '🔍 [AUTH CALLBACK] ⏱️ Adding 100ms delay for storage completion...');
            Future.delayed(const Duration(milliseconds: 100), () {
              print('🔍 [AUTH CALLBACK] - About to call context.go("/")');
              // Clear any URL fragments and navigate to home
              // This ensures OAuth callback properly redirects regardless of preserved fragments
              context.go('/');
              print(
                  '🔍 [AUTH CALLBACK] - context.go("/") completed at: ${DateTime.now().millisecondsSinceEpoch}');
            });
          } else if (state is auth_states.AuthErrorState) {
            // Error - show message and redirect to login
            print(
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
                      style: GoogleFonts.inter(
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
                      style: GoogleFonts.inter(
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
              style: GoogleFonts.inter(
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
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppTheme.onSurfaceVariant,
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
}
