// ============================================================================
// Web Notification Service (Refactored)
// ============================================================================
// Main orchestrator for web notification functionality
// Coordinates token management, message handling, and permissions
// Integrates with Supabase auth for user-specific notifications

import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

import 'notification_token_manager_web.dart';
import 'notification_message_handler_web.dart';
import 'notification_permission_handler_web.dart';

/// Web-specific implementation of notification service
/// Orchestrates modular components for clean separation of concerns
class NotificationServiceWeb {
  final SupabaseClient _supabaseClient;
  final GoRouter _router;

  FirebaseMessaging? _firebaseMessaging;
  bool _isInitialized = false;

  // Module instances
  NotificationTokenManagerWeb? _tokenManager;
  NotificationMessageHandlerWeb? _messageHandler;
  NotificationPermissionHandlerWeb? _permissionHandler;

  // Auth state subscription
  StreamSubscription<AuthState>? _authStateSubscription;

  NotificationServiceWeb({
    required SupabaseClient supabaseClient,
    required GoRouter router,
  })  : _supabaseClient = supabaseClient,
        _router = router;

  // ============================================================================
  // Public Getters
  // ============================================================================

  /// Get current FCM token (null if not obtained)
  String? get fcmToken => _tokenManager?.fcmToken;

  /// Check if the service has been initialized
  bool get isInitialized => _isInitialized;

  /// Stream of notification tap events
  Stream<Map<String, dynamic>> get onNotificationTap =>
      _messageHandler?.onNotificationTap ?? const Stream.empty();

  // ============================================================================
  // Initialization
  // ============================================================================

  /// Initialize Firebase Messaging for web
  Future<void> initialize() async {
    print(
        '[FCM Web] 🔍 Initialize called - checking if already initialized...');
    print('[FCM Web] 📊 Current _isInitialized value: $_isInitialized');

    if (_isInitialized) {
      print('[FCM Web] ⚠️  Already initialized - skipping');
      return;
    }

    try {
      print('[FCM Web] 🚀 Starting initialization...');

      // Get Firebase Messaging instance
      try {
        print('[FCM Web] 📱 Getting Firebase Messaging instance...');
        _firebaseMessaging = FirebaseMessaging.instance;
        print('[FCM Web] ✅ Firebase Messaging instance obtained');
      } catch (e) {
        print('[FCM Web] ❌ Firebase instance error: $e');
        // Firebase may already be initialized in JS, continue anyway
      }

      print(
          '[FCM Web] 🔄 After Firebase instance - continuing to initialization...');

      // Initialize modular components
      _initializeModules();

      // Check service worker availability
      await _checkServiceWorkerStatus();

      // Request permission using permission handler
      print('[FCM Web] 📋 Requesting notification permission...');
      bool hasPermission = false;
      try {
        hasPermission = await _permissionHandler!.requestPermissions();
      } catch (e, stackTrace) {
        print('[FCM Web] ❌ Permission request failed with error: $e');
        print('[FCM Web] Stack trace: $stackTrace');
        print(
            '[FCM Web] ⚠️  This is likely a service worker or browser compatibility issue');
        return;
      }

      if (!hasPermission) {
        print('[FCM Web] ❌ Notification permission denied by user');
        return;
      }
      print('[FCM Web] ✅ Notification permission granted');

      // Get FCM token using token manager
      print('[FCM Web] 🔑 Getting FCM token...');
      final token = await _tokenManager!.getFCMToken();

      if (token != null) {
        print('[FCM Web] ✅ FCM Token obtained successfully');
      } else {
        print(
            '[FCM Web] ❌ Failed to get FCM token - notifications will NOT work');
      }

      // Set up token refresh listener
      print('[FCM Web] 🔄 Setting up token refresh listener...');
      _tokenManager!.setupTokenRefreshListener(() async {
        await _tokenManager!.registerTokenWithBackend();
      });

      // Set up message listeners using message handler
      print('[FCM Web] 📡 Setting up message listeners...');
      _messageHandler!.setupForegroundMessageListener();
      _messageHandler!.setupServiceWorkerMessageListener();

      // Register token with backend if obtained
      if (token != null) {
        print('[FCM Web] 📤 Registering token with backend...');
        await _tokenManager!.registerTokenWithBackend();
      }

      // Listen to auth state changes
      print('[FCM Web] 👤 Setting up auth state listener...');
      _setupAuthStateListener();

      _isInitialized = true;
      print('[FCM Web] ✅ Initialization complete');
      _printInitializationSummary();
    } catch (e, stackTrace) {
      print('[FCM Web] ❌ Initialization error: $e');
      print('[FCM Web] Stack trace: $stackTrace');
      rethrow;
    }
  }

  // ============================================================================
  // Private Helpers
  // ============================================================================

  /// Initialize all modular components
  void _initializeModules() {
    print('[FCM Web] 🔧 Initializing modular components...');

    _tokenManager = NotificationTokenManagerWeb(
      supabaseClient: _supabaseClient,
      firebaseMessaging: _firebaseMessaging!,
    );

    _messageHandler = NotificationMessageHandlerWeb(
      router: _router,
      firebaseMessaging: _firebaseMessaging!,
    );

    _permissionHandler = NotificationPermissionHandlerWeb(
      firebaseMessaging: _firebaseMessaging!,
    );

    print('[FCM Web] ✅ All modules initialized');
  }

  /// Check service worker availability and status
  Future<void> _checkServiceWorkerStatus() async {
    print('[FCM Web] 🔍 Checking service worker status...');
    try {
      if (kIsWeb) {
        final serviceWorkerSupported =
            html.window.navigator.serviceWorker != null;

        if (!serviceWorkerSupported) {
          print('[FCM Web] ❌ Service Worker not supported in this browser');
        } else {
          // Wait for service worker to be ready
          final registration = await html.window.navigator.serviceWorker!.ready;

          if (kDebugMode) {
            print('[FCM Web] ✅ Service worker ready');
            print('[FCM Web] 📊 Scope: ${registration.scope}');
            print('[FCM Web] 📊 Active: ${registration.active != null}');
          }
        }
      }
    } catch (e) {
      print('[FCM Web] ⚠️  Service worker check error: $e');
    }
  }

  /// Print initialization summary
  void _printInitializationSummary() {
    print('[FCM Web] 📊 Initialization Summary:');
    print('[FCM Web]    - Permission: granted');
    print(
        '[FCM Web]    - FCM Token: ${fcmToken != null ? 'obtained' : 'MISSING'}');
    print('[FCM Web]    - Foreground listener: active');
    print('[FCM Web]    - Service worker listener: active');
    print('[FCM Web]    - Token refresh listener: active');
    print('[FCM Web]    - Auth listener: active');
  }

  // ============================================================================
  // Auth State Monitoring
  // ============================================================================

  /// Set up listener for auth state changes
  void _setupAuthStateListener() {
    if (kDebugMode) print('[FCM Web] Setting up auth state listener...');

    _authStateSubscription = _supabaseClient.auth.onAuthStateChange.listen(
      (authState) {
        final event = authState.event;
        final session = authState.session;

        if (kDebugMode) {
          print('[FCM Web] Auth state changed: $event');
          print('[FCM Web] User authenticated: ${session?.user.id ?? 'null'}');
        }

        // Register token when user signs in
        if (event == AuthChangeEvent.signedIn && session != null) {
          if (kDebugMode) {
            print('[FCM Web] User signed in, registering FCM token...');
          }
          _tokenManager?.registerTokenWithBackend();
        }

        // Unregister token when user signs out or session expires
        if (event == AuthChangeEvent.signedOut ||
            event == AuthChangeEvent.tokenRefreshed && session == null) {
          if (kDebugMode) {
            print('[FCM Web] User signed out or session expired');
            print('[FCM Web] Unregistering FCM token from backend...');
          }
          _tokenManager?.unregisterTokenFromBackend();
        }
      },
    );
  }

  // ============================================================================
  // Public API
  // ============================================================================

  /// Request notification permissions from the browser
  Future<bool> requestPermissions() async {
    if (_permissionHandler == null) {
      if (kDebugMode) {
        print('[FCM Web] ❌ Permission handler not initialized');
      }
      return false;
    }
    return await _permissionHandler!.requestPermissions();
  }

  /// Delete the FCM token and unregister from backend
  Future<void> deleteToken() async {
    if (_tokenManager == null) {
      if (kDebugMode) {
        print('[FCM Web] ❌ Token manager not initialized');
      }
      return;
    }
    await _tokenManager!.deleteToken();
  }

  // ============================================================================
  // Cleanup
  // ============================================================================

  /// Dispose resources and clean up
  void dispose() {
    _authStateSubscription?.cancel();
    _tokenManager?.dispose();
    _messageHandler?.dispose();
  }
}
