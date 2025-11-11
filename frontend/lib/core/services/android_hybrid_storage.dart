import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Simple hybrid storage for Android - SecureStorage + SharedPreferences fallback
///
/// Problem: Android Keystore can be cleared by OS, causing unexpected logouts
/// Solution: Dual storage - if SecureStorage fails, fall back to SharedPreferences
///
/// KISS Principle: No complex validation, no aggressive cleanup, just basic fallback
class AndroidHybridStorage extends LocalStorage {
  static const String _secureKey = 'supabase.session';
  static const String _prefsKey = 'supabase.session.backup';

  final FlutterSecureStorage _secure;
  final SharedPreferences _prefs;

  AndroidHybridStorage._({
    required FlutterSecureStorage secure,
    required SharedPreferences prefs,
  })  : _secure = secure,
        _prefs = prefs;

  /// Create instance - must be called in main() after SharedPreferences.getInstance()
  static Future<AndroidHybridStorage> create() async {
    final prefs = await SharedPreferences.getInstance();
    const secure = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    );

    if (kDebugMode) {
      print('✅ [ANDROID STORAGE] Hybrid storage initialized');
    }

    return AndroidHybridStorage._(secure: secure, prefs: prefs);
  }

  @override
  Future<void> initialize() async {
    // No initialization needed - storage is ready on creation
    if (kDebugMode) {
      print('✅ [ANDROID STORAGE] Storage ready');
    }
  }

  @override
  Future<void> persistSession(String sessionString) async {
    // Write to BOTH storages for redundancy
    try {
      await _secure.write(key: _secureKey, value: sessionString);
      if (kDebugMode) print('✅ [ANDROID STORAGE] Saved to SecureStorage');
    } catch (e) {
      if (kDebugMode) {
        print('⚠️  [ANDROID STORAGE] SecureStorage write failed: $e');
      }
    }

    try {
      await _prefs.setString(_prefsKey, sessionString);
      if (kDebugMode) print('✅ [ANDROID STORAGE] Saved to SharedPreferences');
    } catch (e) {
      if (kDebugMode) {
        print('⚠️  [ANDROID STORAGE] SharedPreferences write failed: $e');
      }
    }
  }

  Future<String?> _readSession() async {
    // Try SecureStorage first
    try {
      final session = await _secure.read(key: _secureKey);
      if (session != null && session.isNotEmpty) {
        if (kDebugMode) print('✅ [ANDROID STORAGE] Found in SecureStorage');
        return session;
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️  [ANDROID STORAGE] SecureStorage read failed: $e');
      }
    }

    // Fallback to SharedPreferences
    try {
      final session = _prefs.getString(_prefsKey);
      if (session != null && session.isNotEmpty) {
        if (kDebugMode) {
          print('✅ [ANDROID STORAGE] Recovered from SharedPreferences');
        }

        // Try to restore to SecureStorage for next time
        try {
          await _secure.write(key: _secureKey, value: session);
        } catch (_) {}

        return session;
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️  [ANDROID STORAGE] SharedPreferences read failed: $e');
      }
    }

    if (kDebugMode) print('❌ [ANDROID STORAGE] No session found');
    return null;
  }

  @override
  Future<void> removePersistedSession() async {
    // Remove from both storages
    try {
      await _secure.delete(key: _secureKey);
    } catch (e) {
      if (kDebugMode) {
        print('⚠️  [ANDROID STORAGE] SecureStorage delete failed: $e');
      }
    }

    try {
      await _prefs.remove(_prefsKey);
    } catch (e) {
      if (kDebugMode) {
        print('⚠️  [ANDROID STORAGE] SharedPreferences delete failed: $e');
      }
    }

    if (kDebugMode) print('✅ [ANDROID STORAGE] Session removed');
  }

  @override
  Future<bool> hasAccessToken() async {
    final session = await _readSession();
    return session != null && session.isNotEmpty;
  }

  @override
  Future<String?> accessToken() async {
    // Return the full session JSON string (not just the token)
    // Supabase expects the complete session to restore authentication
    return _readSession();
  }
}
