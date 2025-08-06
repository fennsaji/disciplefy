import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Helper class for debugging authentication issues
class DebugHelper {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  /// Prints all stored authentication data for debugging
  static Future<void> printStoredAuthData() async {
    if (!kDebugMode) return;

    print('🔍 [DEBUG] === STORED AUTH DATA ===');

    try {
      final authToken = await _secureStorage.read(key: 'auth_token');
      final userType = await _secureStorage.read(key: 'user_type');
      final userId = await _secureStorage.read(key: 'user_id');
      final onboardingCompleted =
          await _secureStorage.read(key: 'onboarding_completed');

      print(
          '🔑 Auth Token: ${authToken != null ? "${authToken.substring(0, 20)}..." : "null"}');
      print('👤 User Type: $userType');
      print('🆔 User ID: $userId');
      print('✅ Onboarding: $onboardingCompleted');
    } catch (e) {
      print('❌ [DEBUG] Error reading stored data: $e');
    }

    print('🔍 [DEBUG] === END AUTH DATA ===');
  }

  /// Validates a JWT token structure without verification
  static Map<String, dynamic>? parseJWTPayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        print(
            '❌ [DEBUG] Invalid JWT structure - expected 3 parts, got ${parts.length}');
        return null;
      }

      // Decode the payload (second part)
      String payload = parts[1];

      // Add padding if necessary for base64 decoding
      switch (payload.length % 4) {
        case 0:
          break;
        case 2:
          payload += '==';
          break;
        case 3:
          payload += '=';
          break;
        default:
          print('❌ [DEBUG] Invalid base64 string length');
          return null;
      }

      final decodedBytes = base64.decode(payload);
      final decodedString = utf8.decode(decodedBytes);
      final Map<String, dynamic> payloadMap = json.decode(decodedString);

      print('✅ [DEBUG] JWT payload parsed successfully');
      print('🔍 [DEBUG] JWT fields: ${payloadMap.keys.toList()}');
      print('👤 [DEBUG] Subject (user): ${payloadMap['sub']}');
      print('🔒 [DEBUG] Role: ${payloadMap['role']}');
      print('🎭 [DEBUG] Is Anonymous: ${payloadMap['is_anonymous']}');
      print(
          '⏰ [DEBUG] Expires: ${DateTime.fromMillisecondsSinceEpoch((payloadMap['exp'] ?? 0) * 1000)}');

      return payloadMap;
    } catch (e) {
      print('❌ [DEBUG] JWT parsing error: $e');
      return null;
    }
  }

  /// Tests the full authentication flow
  static Future<void> testAuthFlow() async {
    if (!kDebugMode) return;

    print('🧪 [DEBUG] === TESTING AUTH FLOW ===');

    // 1. Check current stored data
    await printStoredAuthData();

    // 2. Validate JWT if present
    final token = await _secureStorage.read(key: 'auth_token');
    if (token != null) {
      parseJWTPayload(token);
    }

    print('🧪 [DEBUG] === END AUTH TEST ===');
  }

  /// Clears all authentication data for testing
  static Future<void> clearAuthData() async {
    if (!kDebugMode) return;

    print('🧹 [DEBUG] Clearing all auth data...');
    await _secureStorage.deleteAll();
    print('✅ [DEBUG] Auth data cleared');
  }

  /// Logs the Supabase response structure
  static void logSupabaseResponse(Map<String, dynamic> response) {
    if (!kDebugMode) return;

    print('📄 [DEBUG] === SUPABASE RESPONSE ===');
    print(
        '🔑 Access Token: ${response['access_token'] != null ? "Present" : "Missing"}');
    print(
        '🔄 Refresh Token: ${response['refresh_token'] != null ? "Present" : "Missing"}');
    print('⏰ Expires In: ${response['expires_in']}');
    print('⏰ Expires At: ${response['expires_at']}');
    print('🏷️ Token Type: ${response['token_type']}');

    final user = response['user'];
    if (user != null && user is Map<String, dynamic>) {
      print('👤 User ID: ${user['id']}');
      print('📧 Email: ${user['email']}');
      print('📱 Phone: ${user['phone']}');
      print('🎭 Is Anonymous: ${user['is_anonymous']}');
      print('🔒 Role: ${user['role']}');
      print('📅 Created: ${user['created_at']}');
    } else {
      print('❌ User object: Missing or invalid');
    }

    print('📄 [DEBUG] === END RESPONSE ===');
  }
}
