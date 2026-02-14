import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';

/// System Configuration Service
///
/// Manages system-wide configuration including:
/// - Maintenance mode (global on/off switch)
/// - App version requirements (force update control)
/// - Feature flags (dynamic feature toggles)
///
/// Implements 5-minute caching pattern (matches backend TTL) using:
/// - In-memory cache for fast access
/// - SharedPreferences for persistence across app restarts
///
/// Usage:
/// ```dart
/// final service = SystemConfigService();
/// await service.initialize();
///
/// if (service.isMaintenanceModeActive) {
///   // Show maintenance screen
/// }
///
/// final hasVoice = service.isFeatureEnabled('voice_buddy', userPlan);
/// ```
class SystemConfigService extends ChangeNotifier {
  static const String _cacheKey = 'system_config_cache';
  static const String _cacheTimestampKey = 'system_config_timestamp';
  static const Duration _cacheDuration = Duration(minutes: 5);

  SystemConfig? _config;
  bool _isInitialized = false;
  DateTime? _lastFetch;

  /// Current system configuration (null if not initialized)
  SystemConfig? get config => _config;

  /// Whether the service has been initialized
  bool get isInitialized => _isInitialized;

  /// Whether maintenance mode is currently active
  bool get isMaintenanceModeActive => _config?.maintenanceMode.enabled ?? false;

  /// Maintenance message to display to users
  String get maintenanceMessage =>
      _config?.maintenanceMode.message ??
      'We are currently performing system maintenance. Please check back shortly.';

  /// Initialize the service
  ///
  /// Loads cached config first for instant availability,
  /// then fetches fresh data in background.
  ///
  /// Should be called once during app startup in main.dart
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Try to load from cache first (instant)
      await _loadFromCache();

      // Fetch fresh data in background (may use cache if still valid)
      await fetchSystemConfig();

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('[SystemConfigService] Initialization error: $e');
      // Don't throw - allow app to continue with cached/default config
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Fetch system configuration from backend
  ///
  /// Uses backend API endpoint: /functions/v1/system-config
  ///
  /// @param forceRefresh - Skip cache and fetch fresh data
  Future<void> fetchSystemConfig({bool forceRefresh = false}) async {
    if (!forceRefresh && _isCacheValid()) {
      debugPrint('[SystemConfigService] Using cached config');
      return;
    }

    try {
      debugPrint('[SystemConfigService] Fetching from backend API');

      final response = await Supabase.instance.client.functions
          .invoke('system-config', method: HttpMethod.get);

      if (response.status == 200 && response.data['success'] == true) {
        final configData = response.data['data'];
        _config = SystemConfig.fromJson(configData);
        _lastFetch = DateTime.now();

        // Cache the result
        await _saveToCache(configData);
        notifyListeners();

        debugPrint('[SystemConfigService] Config fetched successfully');
      } else {
        debugPrint(
            '[SystemConfigService] API returned error: ${response.status}');
      }
    } catch (e) {
      debugPrint('[SystemConfigService] Failed to fetch config: $e');
      // Don't throw - keep using cached config
    }
  }

  /// Check if a feature is enabled for a specific plan
  ///
  /// @param featureKey - Feature identifier (e.g., 'voice_buddy')
  /// @param planType - User's subscription plan ('free', 'standard', 'plus', 'premium')
  /// @returns true if feature is enabled globally AND plan has access
  bool isFeatureEnabled(String featureKey, String planType) {
    if (_config == null) return false;

    final flag = _config!.featureFlags[featureKey];
    if (flag == null) return false;

    return flag.enabled && flag.plans.contains(planType);
  }

  /// Get minimum required version for current platform
  ///
  /// @param platform - Platform identifier ('android', 'ios', 'web')
  /// @returns Minimum required version string (e.g., '1.0.0')
  String getMinVersionForPlatform(String platform) {
    if (_config == null) return '1.0.0';

    switch (platform.toLowerCase()) {
      case 'android':
        return _config!.versionControl.minVersion['android'] ?? '1.0.0';
      case 'ios':
        return _config!.versionControl.minVersion['ios'] ?? '1.0.0';
      case 'web':
        return _config!.versionControl.minVersion['web'] ?? '1.0.0';
      default:
        return '1.0.0';
    }
  }

  /// Check if cache is still valid (within 5-minute TTL)
  bool _isCacheValid() {
    if (_lastFetch == null) return false;
    return DateTime.now().difference(_lastFetch!) < _cacheDuration;
  }

  /// Load configuration from SharedPreferences cache
  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_cacheKey);
      final timestamp = prefs.getInt(_cacheTimestampKey);

      if (cachedJson != null && timestamp != null) {
        final cacheAge = DateTime.now().millisecondsSinceEpoch - timestamp;

        // Only use cache if less than 5 minutes old
        if (cacheAge < _cacheDuration.inMilliseconds) {
          _config = SystemConfig.fromJson(json.decode(cachedJson));
          _lastFetch = DateTime.fromMillisecondsSinceEpoch(timestamp);
          debugPrint(
              '[SystemConfigService] Loaded from cache (age: ${(cacheAge / 1000).toStringAsFixed(0)}s)');
        } else {
          debugPrint(
              '[SystemConfigService] Cache expired (age: ${(cacheAge / 1000).toStringAsFixed(0)}s)');
        }
      }
    } catch (e) {
      debugPrint('[SystemConfigService] Failed to load from cache: $e');
    }
  }

  /// Save configuration to SharedPreferences cache
  Future<void> _saveToCache(Map<String, dynamic> configData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, json.encode(configData));
      await prefs.setInt(
          _cacheTimestampKey, DateTime.now().millisecondsSinceEpoch);
      debugPrint('[SystemConfigService] Saved to cache');
    } catch (e) {
      debugPrint('[SystemConfigService] Failed to save to cache: $e');
    }
  }

  /// Clear the configuration cache
  ///
  /// Forces next fetch to get fresh data from backend.
  /// Useful after admin updates config.
  Future<void> clearCache() async {
    _config = null;
    _lastFetch = null;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove(_cacheTimestampKey);
      debugPrint('[SystemConfigService] Cache cleared');
    } catch (e) {
      debugPrint('[SystemConfigService] Failed to clear cache: $e');
    }

    notifyListeners();
  }
}

// ============================================================================
// Data Models
// ============================================================================

/// Complete system configuration
class SystemConfig {
  final MaintenanceMode maintenanceMode;
  final VersionControl versionControl;
  final Map<String, FeatureFlag> featureFlags;

  SystemConfig({
    required this.maintenanceMode,
    required this.versionControl,
    required this.featureFlags,
  });

  factory SystemConfig.fromJson(Map<String, dynamic> json) {
    final flagsMap = <String, FeatureFlag>{};
    if (json['featureFlags'] != null) {
      (json['featureFlags'] as Map<String, dynamic>).forEach((key, value) {
        flagsMap[key] = FeatureFlag.fromJson(value as Map<String, dynamic>);
      });
    }

    return SystemConfig(
      maintenanceMode: MaintenanceMode.fromJson(
          json['maintenanceMode'] as Map<String, dynamic>),
      versionControl: VersionControl.fromJson(
          json['versionControl'] as Map<String, dynamic>),
      featureFlags: flagsMap,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'maintenanceMode': maintenanceMode.toJson(),
      'versionControl': versionControl.toJson(),
      'featureFlags':
          featureFlags.map((key, value) => MapEntry(key, value.toJson())),
    };
  }
}

/// Maintenance mode configuration
class MaintenanceMode {
  final bool enabled;
  final String message;

  MaintenanceMode({
    required this.enabled,
    required this.message,
  });

  factory MaintenanceMode.fromJson(Map<String, dynamic> json) {
    return MaintenanceMode(
      enabled: json['enabled'] as bool? ?? false,
      message: json['message'] as String? ?? 'System maintenance in progress',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'message': message,
    };
  }
}

/// App version control configuration
class VersionControl {
  final Map<String, String> minVersion;
  final String latestVersion;
  final bool forceUpdate;

  VersionControl({
    required this.minVersion,
    required this.latestVersion,
    required this.forceUpdate,
  });

  factory VersionControl.fromJson(Map<String, dynamic> json) {
    return VersionControl(
      minVersion: Map<String, String>.from(json['minVersion'] ?? {}),
      latestVersion: json['latestVersion'] as String? ?? '1.0.0',
      forceUpdate: json['forceUpdate'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'minVersion': minVersion,
      'latestVersion': latestVersion,
      'forceUpdate': forceUpdate,
    };
  }
}

/// Feature flag configuration
class FeatureFlag {
  final bool enabled;
  final List<String> plans;

  FeatureFlag({
    required this.enabled,
    required this.plans,
  });

  factory FeatureFlag.fromJson(Map<String, dynamic> json) {
    return FeatureFlag(
      enabled: json['enabled'] as bool? ?? false,
      plans: List<String>.from(json['plans'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'plans': plans,
    };
  }
}
