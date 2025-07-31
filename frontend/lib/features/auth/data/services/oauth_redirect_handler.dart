import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/app_config.dart';
import '../../domain/entities/auth_params.dart';
import 'auth_service.dart';

/// Handler for OAuth redirect URLs and deep linking
/// Manages the OAuth callback flow for authentication
class OAuthRedirectHandler {
  static const MethodChannel _channel = MethodChannel('oauth_redirect');
  final AuthService _authService;

  OAuthRedirectHandler(this._authService) {
    _setupRedirectHandler();
  }

  /// Setup the redirect handler for OAuth callbacks
  void _setupRedirectHandler() {
    if (!kIsWeb) {
      // For mobile platforms, handle deep link callbacks
      _channel.setMethodCallHandler(_handleMethodCall);
    }
  }

  /// Handle incoming method calls from native platforms
  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'handleRedirect':
        final String url = call.arguments as String;
        await _handleRedirectUrl(url);
        break;
      default:
        throw PlatformException(
          code: 'UNIMPLEMENTED',
          message: 'Method ${call.method} is not implemented',
        );
    }
  }

  /// Handle OAuth redirect URL
  Future<void> _handleRedirectUrl(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      
      // Check if this is a valid OAuth callback scheme
      if (AppConfig.oauthRedirectSchemes.contains(uri.scheme)) {
        
        // Extract parameters from URL
        final Map<String, String> params = uri.queryParameters;
        
        // Check for OAuth parameters
        final String? code = params['code'];
        final String? state = params['state'];
        final String? error = params['error'];
        final String? errorDescription = params['error_description'];
        
        if (code != null) {
          // Process successful OAuth callback
          await _authService.processGoogleOAuthCallback(
            GoogleOAuthCallbackParams(
              code: code,
              state: state,
              error: error,
              errorDescription: errorDescription,
            ),
          );
        } else if (error != null) {
          // Handle OAuth error
          await _authService.processGoogleOAuthCallback(
            GoogleOAuthCallbackParams(
              code: '', // Required parameter, but will be ignored due to error
              state: state,
              error: error,
              errorDescription: errorDescription,
            ),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('OAuth redirect handling error: $e');
      }
    }
  }

  /// Launch OAuth URL for web platforms
  Future<void> launchOAuthUrl(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        throw Exception('Could not launch OAuth URL: $url');
      }
    } catch (e) {
      if (kDebugMode) {
        print('OAuth URL launch error: $e');
      }
      rethrow;
    }
  }

  /// Dispose resources
  void dispose() {
    // Clean up any resources if needed
  }
}