import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/memory_verses/models/memory_verse_config.dart';

/// System configuration service
///
/// Manages app-wide system configuration fetched from the backend,
/// including maintenance mode, feature flags, app version control, etc.
///
/// Features:
/// - Maintenance mode detection
/// - Feature flag management with plan-based access
/// - App version control and force update checks
/// - 5-minute cache (matches backend cache TTL)
class SystemConfigService extends ChangeNotifier {
  static const String _cacheKey = 'system_config_cache';
  static const String _cacheTimestampKey = 'system_config_cache_timestamp';
  static const Duration _cacheDuration = Duration(minutes: 5);

  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoading = false;
  bool _isInitialized = false;
  SystemConfig? _config;
  DateTime? _lastFetch;
  String? _error;

  // Getters
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  SystemConfig? get config => _config;
  String? get error => _error;

  /// Check if app is in maintenance mode
  bool get isMaintenanceModeActive => _config?.maintenanceMode.enabled ?? false;

  /// Get maintenance mode message
  String get maintenanceModeMessage =>
      _config?.maintenanceMode.message ??
      'We are currently performing maintenance. Please check back shortly.';

  /// Initialize the service (load from cache, then fetch fresh)
  Future<void> initialize() async {
    debugPrint('🔧 [SystemConfigService] initialize() called');

    if (_isInitialized) {
      debugPrint('ℹ️  [SystemConfigService] Already initialized, skipping');
      return;
    }

    try {
      _isLoading = true;
      notifyListeners();

      debugPrint('📦 [SystemConfigService] Loading from cache...');
      // Load from cache first
      await _loadFromCache();

      // Fetch fresh data in background (if cache is stale)
      if (_shouldRefresh()) {
        debugPrint(
            '🔄 [SystemConfigService] Cache is stale, fetching fresh data...');
        await fetchSystemConfig(forceRefresh: true);
      } else {
        debugPrint('✅ [SystemConfigService] Using cached config (fresh)');
      }

      _isInitialized = true;
      debugPrint('✅ [SystemConfigService] Initialization complete');
    } catch (e) {
      _error = 'Failed to initialize system config: $e';
      debugPrint('❌ [SystemConfigService] Initialization error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetch system configuration from backend
  Future<void> fetchSystemConfig({bool forceRefresh = false}) async {
    debugPrint(
        '📡 [SystemConfigService] fetchSystemConfig() called (forceRefresh: $forceRefresh)');

    // Check cache first (unless force refresh)
    if (!forceRefresh && !_shouldRefresh()) {
      debugPrint('ℹ️ [SystemConfigService] Using cached config');
      return;
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      debugPrint(
          '🌐 [SystemConfigService] Calling backend API: /functions/v1/system-config');

      final response = await _supabase.functions.invoke(
        'system-config',
        method: HttpMethod.get,
      );

      debugPrint(
          '📥 [SystemConfigService] Response received: status=${response.status}');

      if (response.status == 200) {
        final data = response.data as Map<String, dynamic>;

        debugPrint(
            '📄 [SystemConfigService] Response data keys: ${data.keys.toList()}');

        if (data['success'] == true) {
          _config = SystemConfig.fromJson(data['data']);
          _lastFetch = DateTime.now();

          // Save to cache
          await _saveToCache();

          debugPrint('✅ [SystemConfigService] Config fetched successfully');
          debugPrint(
              '   - Maintenance mode: ${_config?.maintenanceMode.enabled}');
          debugPrint(
              '   - Feature flags count: ${_config?.featureFlags.length}');
        } else {
          throw Exception(data['error'] ?? 'Failed to fetch system config');
        }
      } else {
        throw Exception('HTTP \${response.status}: \${response.data}');
      }
    } catch (e) {
      _error = 'Failed to fetch system config: $e';
      debugPrint('❌ [SystemConfigService] Fetch error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Check if a feature is enabled for the given plan
  bool isFeatureEnabled(String featureKey, String planType) {
    final feature = _config?.featureFlags[featureKey];
    if (feature == null) return false;

    if (!feature.enabled) return false;

    return feature.enabledForPlans.contains(planType);
  }

  /// Check if user has access to use a feature (can actually use it, not just see it)
  bool hasFeatureAccess(String featureKey, String planType) {
    return isFeatureEnabled(featureKey, planType);
  }

  /// Check if feature should be shown with lock icon
  /// Returns true if:
  /// - Feature is enabled globally
  /// - User's plan doesn't have access
  /// - Display mode is 'lock'
  bool isFeatureLocked(String featureKey, String planType) {
    final feature = _config?.featureFlags[featureKey];
    if (feature == null) return false;

    // If feature is globally disabled, never show lock
    if (!feature.enabled) return false;

    // If user has access, never show lock
    if (feature.enabledForPlans.contains(planType)) return false;

    // Show lock only if display mode is 'lock'
    return feature.displayMode == 'lock';
  }

  /// Check if feature should be completely hidden
  /// Returns true if:
  /// - Feature is globally disabled, OR
  /// - User's plan doesn't have access AND display mode is 'hide'
  bool shouldHideFeature(String featureKey, String planType) {
    final feature = _config?.featureFlags[featureKey];
    if (feature == null) return true; // Hide unknown features

    // Always hide if feature is globally disabled
    if (!feature.enabled) return true;

    // If user has access, never hide
    if (feature.enabledForPlans.contains(planType)) return false;

    // Hide if display mode is 'hide' (don't hide if 'lock')
    return feature.displayMode == 'hide';
  }

  /// Get display mode for a feature
  String getFeatureDisplayMode(String featureKey) {
    return _config?.featureFlags[featureKey]?.displayMode ?? 'hide';
  }

  /// Get required plans for a feature
  List<String> getRequiredPlans(String featureKey) {
    return _config?.featureFlags[featureKey]?.enabledForPlans ?? [];
  }

  /// Get upgrade target plan for a locked feature
  /// Returns the cheapest plan that has access to the feature
  String? getUpgradePlan(String featureKey, String currentPlan) {
    final requiredPlans = getRequiredPlans(featureKey);
    if (requiredPlans.isEmpty) return null;

    // Plan hierarchy: free < standard < plus < premium
    const planHierarchy = ['free', 'standard', 'plus', 'premium'];
    final currentIndex = planHierarchy.indexOf(currentPlan.toLowerCase());

    // Find the cheapest plan that has access and is higher than current plan
    for (final plan in planHierarchy) {
      if (requiredPlans.contains(plan)) {
        final planIndex = planHierarchy.indexOf(plan);
        if (planIndex > currentIndex) {
          return plan;
        }
      }
    }

    return null;
  }

  /// Get all enabled features for a plan
  List<String> getEnabledFeatures(String planType) {
    if (_config == null) return [];

    return _config!.featureFlags.entries
        .where((entry) =>
            entry.value.enabled &&
            entry.value.enabledForPlans.contains(planType))
        .map((entry) => entry.key)
        .toList();
  }

  /// Check if app version is below minimum required
  bool isUpdateRequired(String currentVersion, String platform) {
    final minVersion = _config?.versionControl.minVersion[platform];
    if (minVersion == null) return false;

    return _compareVersions(currentVersion, minVersion) < 0;
  }

  /// Check if force update is enabled
  bool get isForceUpdateEnabled => _config?.versionControl.forceUpdate ?? false;

  // Private helper methods

  bool _shouldRefresh() {
    if (_lastFetch == null) return true;
    return DateTime.now().difference(_lastFetch!) > _cacheDuration;
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_cacheKey);
      final cachedTimestamp = prefs.getInt(_cacheTimestampKey);

      if (cachedJson != null && cachedTimestamp != null) {
        final cacheAge =
            DateTime.now().millisecondsSinceEpoch - cachedTimestamp;

        // Only use cache if less than 5 minutes old
        if (cacheAge < _cacheDuration.inMilliseconds) {
          _config = SystemConfig.fromJson(jsonDecode(cachedJson));
          _lastFetch = DateTime.fromMillisecondsSinceEpoch(cachedTimestamp);
          debugPrint(
              '✅ [SystemConfigService] Loaded from cache (age: \${cacheAge ~/ 1000}s)');
        } else {
          debugPrint(
              'ℹ️ [SystemConfigService] Cache expired (age: \${cacheAge ~/ 1000}s)');
        }
      }
    } catch (e) {
      debugPrint('⚠️ [SystemConfigService] Cache load error: $e');
    }
  }

  Future<void> _saveToCache() async {
    try {
      if (_config == null) return;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(_config!.toJson()));
      await prefs.setInt(
          _cacheTimestampKey, DateTime.now().millisecondsSinceEpoch);

      debugPrint('✅ [SystemConfigService] Saved to cache');
    } catch (e) {
      debugPrint('⚠️ [SystemConfigService] Cache save error: $e');
    }
  }

  /// Compare semantic versions (returns -1 if v1 < v2, 0 if equal, 1 if v1 > v2)
  int _compareVersions(String v1, String v2) {
    final parts1 = v1.split('.').map(int.parse).toList();
    final parts2 = v2.split('.').map(int.parse).toList();

    for (var i = 0; i < 3; i++) {
      final p1 = i < parts1.length ? parts1[i] : 0;
      final p2 = i < parts2.length ? parts2[i] : 0;

      if (p1 < p2) return -1;
      if (p1 > p2) return 1;
    }

    return 0;
  }

  /// Clear cache (for testing or when logout)
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove(_cacheTimestampKey);

      _config = null;
      _lastFetch = null;

      debugPrint('✅ [SystemConfigService] Cache cleared');
      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ [SystemConfigService] Cache clear error: $e');
    }
  }
}

/// System configuration model
class SystemConfig {
  final MaintenanceMode maintenanceMode;
  final VersionControl versionControl;
  final Map<String, FeatureFlag> featureFlags;
  final MemoryVerseConfig memoryVerseConfig;

  SystemConfig({
    required this.maintenanceMode,
    required this.versionControl,
    required this.featureFlags,
    required this.memoryVerseConfig,
  });

  factory SystemConfig.fromJson(Map<String, dynamic> json) {
    return SystemConfig(
      maintenanceMode: MaintenanceMode.fromJson(json['maintenanceMode'] ?? {}),
      versionControl: VersionControl.fromJson(json['versionControl'] ?? {}),
      featureFlags: (json['featureFlags'] as Map<String, dynamic>? ?? {})
          .map((key, value) => MapEntry(key, FeatureFlag.fromJson(value))),
      memoryVerseConfig: json['memoryVerseConfig'] != null
          ? MemoryVerseConfig.fromJson(json['memoryVerseConfig'])
          : MemoryVerseConfig.defaultConfig(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'maintenanceMode': maintenanceMode.toJson(),
      'versionControl': versionControl.toJson(),
      'featureFlags':
          featureFlags.map((key, value) => MapEntry(key, value.toJson())),
      'memoryVerseConfig': memoryVerseConfig.toJson(),
    };
  }
}

class MaintenanceMode {
  final bool enabled;
  final String message;

  MaintenanceMode({
    required this.enabled,
    required this.message,
  });

  factory MaintenanceMode.fromJson(Map<String, dynamic> json) {
    return MaintenanceMode(
      enabled: json['enabled'] ?? false,
      message: json['message'] ?? 'We are currently performing maintenance.',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'message': message,
    };
  }
}

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
      latestVersion: json['latestVersion'] ?? '1.0.0',
      forceUpdate: json['forceUpdate'] ?? false,
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

class FeatureFlag {
  final bool enabled;
  final List<String> enabledForPlans;
  final String displayMode; // 'hide' | 'lock'

  FeatureFlag({
    required this.enabled,
    required this.enabledForPlans,
    required this.displayMode,
  });

  factory FeatureFlag.fromJson(Map<String, dynamic> json) {
    return FeatureFlag(
      enabled: json['enabled'] ?? false,
      enabledForPlans: List<String>.from(json['plans'] ?? []),
      displayMode: json['displayMode'] ?? 'hide',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'plans': enabledForPlans,
      'displayMode': displayMode,
    };
  }
}
