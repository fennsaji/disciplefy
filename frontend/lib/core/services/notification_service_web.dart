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
import '../utils/logger.dart';

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
    Logger.debug(
        '[FCM Web] 🔍 Initialize called - checking if already initialized...');
    Logger.debug('[FCM Web] 📊 Current _isInitialized value: $_isInitialized');

    if (_isInitialized) {
      Logger.warning('[FCM Web] ⚠️  Already initialized - skipping');
      return;
    }

    try {
      Logger.debug('[FCM Web] 🚀 Starting initialization...');

      // Get Firebase Messaging instance
      try {
        Logger.debug('[FCM Web] 📱 Getting Firebase Messaging instance...');
        _firebaseMessaging = FirebaseMessaging.instance;
        Logger.error('[FCM Web] ✅ Firebase Messaging instance obtained');
      } catch (e) {
        Logger.debug('[FCM Web] ❌ Firebase instance error: $e');
        // Firebase may already be initialized in JS, continue anyway
      }

      Logger.debug(
          '[FCM Web] 🔄 After Firebase instance - continuing to initialization...');

      // Initialize modular components
      _initializeModules();

      // Check service worker availability
      await _checkServiceWorkerStatus();

      // Request permission using permission handler
      Logger.debug('[FCM Web] 📋 Requesting notification permission...');
      bool hasPermission = false;
      try {
        hasPermission = await _permissionHandler!.requestPermissions();
      } catch (e, stackTrace) {
        Logger.error('[FCM Web] ❌ Permission request failed with error: $e');
        Logger.debug('[FCM Web] Stack trace: $stackTrace');
        Logger.warning(
            '[FCM Web] ⚠️  This is likely a service worker or browser compatibility issue');
        return;
      }

      if (!hasPermission) {
        Logger.error('[FCM Web] ❌ Notification permission denied by user');
        return;
      }
      Logger.debug('[FCM Web] ✅ Notification permission granted');

      // Get FCM token using token manager
      Logger.debug('[FCM Web] 🔑 Getting FCM token...');
      final token = await _tokenManager!.getFCMToken();

      if (token != null) {
        Logger.error('[FCM Web] ✅ FCM Token obtained successfully');
      } else {
        Logger.error(
            '[FCM Web] ❌ Failed to get FCM token - notifications will NOT work');
      }

      // Set up token refresh listener
      Logger.debug('[FCM Web] 🔄 Setting up token refresh listener...');
      _tokenManager!.setupTokenRefreshListener(() async {
        await _tokenManager!.registerTokenWithBackend();
      });

      // Set up message listeners using message handler
      Logger.debug('[FCM Web] 📡 Setting up message listeners...');
      _messageHandler!.setupForegroundMessageListener();
      _messageHandler!.setupServiceWorkerMessageListener();

      // Register token with backend if obtained
      if (token != null) {
        Logger.debug('[FCM Web] 📤 Registering token with backend...');
        await _tokenManager!.registerTokenWithBackend();
      }

      // Listen to auth state changes
      Logger.debug('[FCM Web] 👤 Setting up auth state listener...');
      _setupAuthStateListener();

      _isInitialized = true;
      Logger.debug('[FCM Web] ✅ Initialization complete');
      _printInitializationSummary();
    } catch (e, stackTrace) {
      Logger.error('[FCM Web] ❌ Initialization error: $e');
      Logger.debug('[FCM Web] Stack trace: $stackTrace');
      rethrow;
    }
  }

  // ============================================================================
  // Private Helpers
  // ============================================================================

  /// Initialize all modular components
  void _initializeModules() {
    Logger.debug('[FCM Web] 🔧 Initializing modular components...');

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

    Logger.debug('[FCM Web] ✅ All modules initialized');
  }

  /// Check service worker availability and status
  Future<void> _checkServiceWorkerStatus() async {
    Logger.debug('[FCM Web] 🔍 Checking service worker status...');
    try {
      if (kIsWeb) {
        final serviceWorkerSupported =
            html.window.navigator.serviceWorker != null;

        if (!serviceWorkerSupported) {
          Logger.error(
              '[FCM Web] ❌ Service Worker not supported in this browser');
        } else {
          // Wait for service worker to be ready
          final registration = await html.window.navigator.serviceWorker!.ready;

          if (kDebugMode) {
            Logger.debug('[FCM Web] ✅ Service worker ready');
            Logger.debug('[FCM Web] 📊 Scope: ${registration.scope}');
            Logger.debug('[FCM Web] 📊 Active: ${registration.active != null}');
          }

          // 🔒 SECURITY: Send Firebase config to service worker at runtime
          // This prevents hardcoding API keys in the service worker file
          await _sendFirebaseConfigToServiceWorker(registration);
        }
      }
    } catch (e) {
      Logger.error('[FCM Web] ⚠️  Service worker check error: $e');
    }
  }

  /// Send Firebase configuration to the service worker at runtime
  /// This prevents hardcoding API keys in the codebase
  Future<void> _sendFirebaseConfigToServiceWorker(
      html.ServiceWorkerRegistration registration) async {
    try {
      // Get Firebase config from environment (passed via --dart-define)
      const firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');

      if (firebaseApiKey.isEmpty) {
        Logger.warning(
            '[FCM Web] ⚠️  Firebase API key not provided via --dart-define');
        Logger.debug('[FCM Web] ⚠️  Service worker will use fallback config');
        return;
      }

      final firebaseConfig = {
        'apiKey': firebaseApiKey,
        'authDomain': const String.fromEnvironment('FIREBASE_AUTH_DOMAIN',
            defaultValue: 'disciplefy---bible-study.firebaseapp.com'),
        'projectId': const String.fromEnvironment('FIREBASE_PROJECT_ID',
            defaultValue: 'disciplefy---bible-study'),
        'storageBucket': const String.fromEnvironment('FIREBASE_STORAGE_BUCKET',
            defaultValue: 'disciplefy---bible-study.firebasestorage.app'),
        'messagingSenderId': const String.fromEnvironment(
            'FIREBASE_MESSAGING_SENDER_ID',
            defaultValue: '16888340359'),
        'appId': const String.fromEnvironment('FIREBASE_APP_ID',
            defaultValue: '1:16888340359:web:36ad4ae0d1ef1adf8e3d22'),
        'measurementId': const String.fromEnvironment('FIREBASE_MEASUREMENT_ID',
            defaultValue: 'G-TY0KDPH5TS'),
      };

      Logger.debug('[FCM Web] 🔧 Sending Firebase config to service worker...');
      registration.active?.postMessage({
        'type': 'FIREBASE_CONFIG',
        'config': firebaseConfig,
      });
      Logger.error('[FCM Web] ✅ Firebase config sent to service worker');
    } catch (e) {
      Logger.debug(
          '[FCM Web] ❌ Failed to send Firebase config to service worker: $e');
    }
  }

  /// Print initialization summary
  void _printInitializationSummary() {
    Logger.debug('[FCM Web] 📊 Initialization Summary:');
    Logger.debug('[FCM Web]    - Permission: granted');
    Logger.debug(
        '[FCM Web]    - FCM Token: ${fcmToken != null ? 'obtained' : 'MISSING'}');
    Logger.debug('[FCM Web]    - Foreground listener: active');
    Logger.debug('[FCM Web]    - Service worker listener: active');
    Logger.debug('[FCM Web]    - Token refresh listener: active');
    Logger.debug('[FCM Web]    - Auth listener: active');
  }

  // ============================================================================
  // Auth State Monitoring
  // ============================================================================

  /// Set up listener for auth state changes
  void _setupAuthStateListener() {
    if (kDebugMode) Logger.debug('[FCM Web] Setting up auth state listener...');

    _authStateSubscription = _supabaseClient.auth.onAuthStateChange.listen(
      (authState) {
        final event = authState.event;
        final session = authState.session;

        if (kDebugMode) {
          Logger.debug('[FCM Web] Auth state changed: $event');
          Logger.debug(
              '[FCM Web] User authenticated: ${session?.user.id ?? 'null'}');
        }

        // Register token when user signs in
        if (event == AuthChangeEvent.signedIn && session != null) {
          Logger.debug('[FCM Web] User signed in, registering FCM token...');
          _tokenManager?.registerTokenWithBackend();
        }

        // Unregister token when user signs out or session expires
        if (event == AuthChangeEvent.signedOut ||
            event == AuthChangeEvent.tokenRefreshed && session == null) {
          if (kDebugMode) {
            Logger.debug('[FCM Web] User signed out or session expired');
            Logger.debug('[FCM Web] Unregistering FCM token from backend...');
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
      Logger.error('[FCM Web] ❌ Permission handler not initialized');
      return false;
    }
    return await _permissionHandler!.requestPermissions();
  }

  /// Delete the FCM token and unregister from backend
  Future<void> deleteToken() async {
    if (_tokenManager == null) {
      Logger.error('[FCM Web] ❌ Token manager not initialized');
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
