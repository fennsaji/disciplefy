import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Service for handling authentication operations.
class AuthService {
  // API Configuration
  static const String _baseUrl = 'http://127.0.0.1:54321';
  static const String _supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0';
  
  // Secure storage instance
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  
  /// Storage keys
  static const String _authTokenKey = 'auth_token';
  static const String _userTypeKey = 'user_type';
  static const String _userIdKey = 'user_id';
  static const String _onboardingCompletedKey = 'onboarding_completed';

  /// Creates an anonymous guest session.
  /// 
  /// Returns the access token on success, throws an exception on failure.
  static Future<String> createGuestSession() async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/v1/signup'),
      headers: {
        'Content-Type': 'application/json',
        'apikey': _supabaseAnonKey,
      },
      body: json.encode({}),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = json.decode(response.body);
      
      if (responseData.containsKey('access_token')) {
        return responseData['access_token'];
      } else {
        throw Exception('No access token received from server');
      }
    } else {
      final Map<String, dynamic> errorData = json.decode(response.body);
      final String errorMessage = errorData['error_description'] ?? 
                                 errorData['message'] ?? 
                                 'Failed to create guest session';
      throw Exception(errorMessage);
    }
  }

  /// Stores authentication data securely.
  static Future<void> storeAuthData({
    required String accessToken,
    required String userType,
    String? userId,
  }) async {
    await _secureStorage.write(key: _authTokenKey, value: accessToken);
    await _secureStorage.write(key: _userTypeKey, value: userType);
    
    if (userId != null) {
      await _secureStorage.write(key: _userIdKey, value: userId);
    }
    
    await _secureStorage.write(key: _onboardingCompletedKey, value: 'true');
  }

  /// Retrieves the stored auth token.
  static Future<String?> getAuthToken() async {
    return await _secureStorage.read(key: _authTokenKey);
  }

  /// Retrieves the user type (guest, google, etc.).
  static Future<String?> getUserType() async {
    return await _secureStorage.read(key: _userTypeKey);
  }

  /// Retrieves the user ID.
  static Future<String?> getUserId() async {
    return await _secureStorage.read(key: _userIdKey);
  }

  /// Checks if onboarding has been completed.
  static Future<bool> isOnboardingCompleted() async {
    final completed = await _secureStorage.read(key: _onboardingCompletedKey);
    return completed == 'true';
  }

  /// Checks if the user is authenticated (has a valid token).
  static Future<bool> isAuthenticated() async {
    final token = await getAuthToken();
    return token != null && token.isNotEmpty;
  }

  /// Signs out the user by clearing all stored data.
  static Future<void> signOut() async {
    await _secureStorage.deleteAll();
  }
}