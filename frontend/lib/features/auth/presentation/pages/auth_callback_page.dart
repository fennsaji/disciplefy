import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
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

    // Process authorization code
    if (widget.code != null) {
      context.read<AuthBloc>().add(
        GoogleOAuthCallbackRequested(
          code: widget.code!,
          state: widget.state,
        ),
      );
    } else {
      _handleMissingCode();
    }
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
  Widget build(BuildContext context) => BlocListener<AuthBloc, auth_states.AuthState>(
      listener: (context, state) {
        if (state is auth_states.AuthenticatedState) {
          // Success - navigate to home
          context.go('/');
        } else if (state is auth_states.AuthErrorState) {
          // Error - show message and redirect to login
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
          if (widget.code != null) _buildDebugItem('Code', '${widget.code!.substring(0, 20)}...'),
          if (widget.state != null) _buildDebugItem('State', widget.state!),
          if (widget.error != null) _buildDebugItem('Error', widget.error!),
          if (widget.errorDescription != null) _buildDebugItem('Error Description', widget.errorDescription!),
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