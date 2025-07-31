import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

import '../error/exceptions.dart';
import 'api_auth_helper.dart';

/// Centralized HTTP service with automatic 401 error handling and token refresh
class HttpService {
  static const int _maxRetries = 1;
  final http.Client _httpClient;
  bool _isDisposed = false;
  
  /// Stream controller for authentication failure events
  static final StreamController<String> _authFailureController = 
      StreamController<String>.broadcast();
  
  /// Stream of authentication failure events
  static Stream<String> get authFailureStream => _authFailureController.stream;

  HttpService({http.Client? httpClient}) 
      : _httpClient = httpClient ?? http.Client();

  /// Make an authenticated HTTP GET request with automatic 401 handling
  Future<http.Response> get(String url, {Map<String, String>? headers}) async => await _makeRequest(
      () => _httpClient.get(Uri.parse(url), headers: headers),
      url,
    );

  /// Make an authenticated HTTP POST request with automatic 401 handling
  Future<http.Response> post(String url, {Map<String, String>? headers, String? body}) async => await _makeRequest(
      () => _httpClient.post(Uri.parse(url), headers: headers, body: body),
      url,
    );

  /// Make an authenticated HTTP PUT request with automatic 401 handling
  Future<http.Response> put(String url, {Map<String, String>? headers, String? body}) async => await _makeRequest(
      () => _httpClient.put(Uri.parse(url), headers: headers, body: body),
      url,
    );

  /// Make an authenticated HTTP DELETE request with automatic 401 handling
  Future<http.Response> delete(String url, {Map<String, String>? headers}) async => await _makeRequest(
      () => _httpClient.delete(Uri.parse(url), headers: headers),
      url,
    );

  /// Core request method with automatic 401 handling and retry logic
  Future<http.Response> _makeRequest(
    Future<http.Response> Function() requestFunction,
    String url,
  ) async {
    if (_isDisposed) {
      throw const NetworkException(
        message: 'HTTP client has been disposed',
        code: 'CLIENT_DISPOSED',
      );
    }
    int retryCount = 0;
    
    while (retryCount <= _maxRetries) {
      try {
        final response = await requestFunction()
            .timeout(const Duration(seconds: 10));
        
        // Handle 401 Unauthorized
        if (response.statusCode == 401) {
          print('🔐 [HTTP] 401 Unauthorized received for: $url');
          
          // Only attempt refresh if we have a session and haven't exceeded retries
          if (retryCount < _maxRetries && ApiAuthHelper.isAuthenticated) {
            print('🔐 [HTTP] Attempting token refresh...');
            
            final refreshed = await _refreshToken();
            if (refreshed) {
              print('🔐 [HTTP] Token refresh successful, retrying request...');
              retryCount++;
              continue; // Retry the request
            } else {
              print('🔐 [HTTP] Token refresh failed, logging out user...');
              await _handleAuthenticationFailure();
              throw const AuthenticationException(
                message: 'Session expired. Please login again.',
                code: 'SESSION_EXPIRED',
              );
            }
          } else {
            print('🔐 [HTTP] No valid session or max retries reached, logging out...');
            await _handleAuthenticationFailure();
            throw const AuthenticationException(
              message: 'Authentication required. Please login.',
              code: 'AUTHENTICATION_REQUIRED',
            );
          }
        }
        
        return response;
      } catch (e) {
        if (e is AuthenticationException) {
          rethrow;
        }
        
        // For non-auth errors, don't retry
        if (retryCount == 0) {
          throw NetworkException(
            message: 'Request failed: $e',
            code: 'REQUEST_FAILED',
          );
        }
        
        retryCount++;
      }
    }
    
    // This should never be reached, but just in case
    throw const NetworkException(
      message: 'Request failed after retries',
      code: 'REQUEST_FAILED',
    );
  }

  /// Attempt to refresh the authentication token
  Future<bool> _refreshToken() async {
    try {
      final supabase = Supabase.instance.client;
      final currentSession = supabase.auth.currentSession;
      
      if (currentSession == null) {
        print('🔐 [HTTP] No current session to refresh');
        return false;
      }
      
      // Check if token is close to expiry (within 5 minutes)
      final now = DateTime.now();
      final expiryTime = DateTime.fromMillisecondsSinceEpoch(
        currentSession.expiresAt! * 1000
      );
      
      if (expiryTime.isAfter(now.add(const Duration(minutes: 5)))) {
        print('🔐 [HTTP] Token is still valid, no refresh needed');
        return true;
      }
      
      // Attempt to refresh the session
      final response = await supabase.auth.refreshSession();
      
      if (response.session != null) {
        print('🔐 [HTTP] Token refresh successful');
        ApiAuthHelper.logAuthState();
        return true;
      } else {
        print('🔐 [HTTP] Token refresh failed');
        return false;
      }
    } catch (e) {
      print('🔐 [HTTP] Token refresh error: $e');
      return false;
    }
  }

  /// Handle authentication failure by clearing session and data
  Future<void> _handleAuthenticationFailure() async {
    try {
      print('🔐 [HTTP] Handling authentication failure...');
      
      // Notify the app about the authentication failure through the stream
      _authFailureController.add('Session expired or invalid');
      
      // Sign out from Supabase
      await Supabase.instance.client.auth.signOut();
      
      // Clear any cached data
      await _clearUserData();
      
      print('🔐 [HTTP] Authentication failure handled');
    } catch (e) {
      print('🔐 [HTTP] Error during authentication failure handling: $e');
    }
  }

  /// Clear user-specific data from local storage
  Future<void> _clearUserData() async {
    try {
      // Clear any Hive boxes or other local storage
      // Add specific data clearing logic here as needed
      print('🔐 [HTTP] User data cleared');
    } catch (e) {
      print('🔐 [HTTP] Error clearing user data: $e');
    }
  }

  /// Create headers with authentication
  Future<Map<String, String>> createHeaders({
    Map<String, String>? additionalHeaders,
  }) async {
    final headers = await ApiAuthHelper.getAuthHeaders();
    
    if (additionalHeaders != null) {
      headers.addAll(additionalHeaders);
    }
    
    return headers;
  }

  /// Dispose HTTP client
  void dispose() {
    if (!_isDisposed) {
      _httpClient.close();
      _isDisposed = true;
    }
  }
  
  /// Dispose static resources
  static void disposeStatic() {
    _authFailureController.close();
  }
}

/// Singleton instance of HttpService
class HttpServiceProvider {
  static HttpService? _instance;
  
  static HttpService get instance {
    _instance ??= HttpService();
    return _instance!;
  }
  
  static void dispose() {
    _instance?.dispose();
    _instance = null;
    HttpService.disposeStatic();
  }
}