import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/subscription_pricing.dart';

/// Service for managing subscription pricing
///
/// Fetches pricing from backend API and caches in SharedPreferences.
/// Automatically refreshes cache every 5 minutes.
class PricingService {
  static const String _cacheKey = 'subscription_pricing';
  static const String _cacheTimestampKey = 'subscription_pricing_timestamp';
  static const Duration _cacheDuration = Duration(minutes: 5);

  SubscriptionPricing? _pricing;
  DateTime? _lastFetch;

  /// Get current pricing (uses cache if valid)
  SubscriptionPricing get pricing => _pricing ?? SubscriptionPricing.empty();

  /// Initialize service and load pricing
  Future<void> initialize() async {
    try {
      // Try to load from cache first
      await _loadFromCache();

      // Fetch fresh data from API
      await fetchPricing();
    } catch (e) {
      debugPrint('⚠️ [PricingService] Error initializing: $e');
      // Use fallback pricing if initialization fails
      _pricing = SubscriptionPricing.empty();
    }
  }

  /// Fetch pricing from backend API
  Future<void> fetchPricing({bool forceRefresh = false}) async {
    try {
      // Check if cache is still valid
      if (!forceRefresh && _isCacheValid()) {
        debugPrint('✅ [PricingService] Using cached pricing');
        return;
      }

      debugPrint('🔄 [PricingService] Fetching fresh pricing from API...');

      final response = await Supabase.instance.client.functions.invoke(
        'subscription-pricing',
        method: HttpMethod.get,
      );

      if (response.status != 200) {
        throw Exception(
            'Failed to fetch pricing: ${response.status} ${response.data}');
      }

      final responseData = response.data as Map<String, dynamic>;

      if (responseData['success'] != true) {
        throw Exception('API error: ${responseData['error']}');
      }

      final pricingData = responseData['data'] as Map<String, dynamic>;
      _pricing = SubscriptionPricing.fromJson(pricingData);
      _lastFetch = DateTime.now();

      // Save to cache
      await _saveToCache();

      debugPrint('✅ [PricingService] Pricing fetched successfully');
    } catch (e) {
      debugPrint('❌ [PricingService] Error fetching pricing: $e');
      // Keep using cached pricing if fetch fails
      _pricing ??= SubscriptionPricing.empty();
    }
  }

  /// Get formatted price for a specific plan
  String getFormattedPrice(String planCode, {String? provider}) {
    final selectedProvider = provider ?? _getDefaultProvider();
    final providerPricing = pricing.getProvider(selectedProvider);

    if (providerPricing == null) {
      debugPrint(
          '⚠️ [PricingService] Provider "$selectedProvider" not found, using fallback');
      return PlanPrice.fallback(planCode).formatted;
    }

    final planPrice = providerPricing.getPlan(planCode);

    if (planPrice == null) {
      debugPrint(
          '⚠️ [PricingService] Plan "$planCode" not found in provider "$selectedProvider", using fallback');
      return PlanPrice.fallback(planCode).formatted;
    }

    return planPrice.formatted;
  }

  /// Get formatted price with "/month" suffix
  String getFormattedPricePerMonth(String planCode, {String? provider}) {
    return '${getFormattedPrice(planCode, provider: provider)}/month';
  }

  /// Get price amount in minor units (paise/cents)
  int getPriceAmount(String planCode, {String? provider}) {
    final selectedProvider = provider ?? _getDefaultProvider();
    final providerPricing = pricing.getProvider(selectedProvider);

    if (providerPricing == null) {
      return PlanPrice.fallback(planCode).amount;
    }

    final planPrice = providerPricing.getPlan(planCode);
    return planPrice?.amount ?? PlanPrice.fallback(planCode).amount;
  }

  /// Get currency for a specific plan
  String getCurrency(String planCode, {String? provider}) {
    final selectedProvider = provider ?? _getDefaultProvider();
    final providerPricing = pricing.getProvider(selectedProvider);

    if (providerPricing == null) {
      return PlanPrice.fallback(planCode).currency;
    }

    final planPrice = providerPricing.getPlan(planCode);
    return planPrice?.currency ?? PlanPrice.fallback(planCode).currency;
  }

  /// Get IAP product ID for a specific plan (for Google Play / Apple App Store)
  ///
  /// Returns null if:
  /// - Provider not found
  /// - Plan not found
  /// - Product ID not configured
  /// - Provider is not IAP-based (e.g., Razorpay)
  String? getProductId(String planCode, {String? provider}) {
    final selectedProvider = provider ?? _getDefaultProvider();
    final providerPricing = pricing.getProvider(selectedProvider);

    if (providerPricing == null) {
      debugPrint(
          '⚠️ [PricingService] Provider "$selectedProvider" not found for product ID');
      return null;
    }

    final planPrice = providerPricing.getPlan(planCode);

    if (planPrice == null) {
      debugPrint(
          '⚠️ [PricingService] Plan "$planCode" not found in provider "$selectedProvider" for product ID');
      return null;
    }

    if (planPrice.productId == null) {
      debugPrint(
          '⚠️ [PricingService] No product ID configured for plan "$planCode" in provider "$selectedProvider"');
    }

    return planPrice.productId;
  }

  /// Get default provider based on platform
  String _getDefaultProvider() {
    if (kIsWeb) {
      return 'razorpay';
    } else if (Platform.isAndroid) {
      return 'google_play';
    } else if (Platform.isIOS) {
      return 'apple_appstore';
    } else {
      return 'razorpay'; // fallback
    }
  }

  /// Check if cache is still valid
  bool _isCacheValid() {
    if (_pricing == null || _lastFetch == null) {
      return false;
    }

    final now = DateTime.now();
    final difference = now.difference(_lastFetch!);

    return difference < _cacheDuration;
  }

  /// Load pricing from SharedPreferences cache
  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(_cacheKey);
      final cachedTimestamp = prefs.getInt(_cacheTimestampKey);

      if (cachedData != null && cachedTimestamp != null) {
        final pricingJson = jsonDecode(cachedData) as Map<String, dynamic>;
        _pricing = SubscriptionPricing.fromJson(pricingJson);
        _lastFetch =
            DateTime.fromMillisecondsSinceEpoch(cachedTimestamp * 1000);

        debugPrint('✅ [PricingService] Loaded pricing from cache');
      }
    } catch (e) {
      debugPrint('⚠️ [PricingService] Error loading from cache: $e');
    }
  }

  /// Save pricing to SharedPreferences cache
  Future<void> _saveToCache() async {
    try {
      if (_pricing == null) return;

      final prefs = await SharedPreferences.getInstance();
      final pricingJson = jsonEncode(_pricing!.toJson());
      final timestamp = (_lastFetch ?? DateTime.now()).millisecondsSinceEpoch ~/
          1000; // Unix timestamp in seconds

      await prefs.setString(_cacheKey, pricingJson);
      await prefs.setInt(_cacheTimestampKey, timestamp);

      debugPrint('✅ [PricingService] Saved pricing to cache');
    } catch (e) {
      debugPrint('⚠️ [PricingService] Error saving to cache: $e');
    }
  }

  /// Clear cache and fetch fresh pricing
  Future<void> refreshPricing() async {
    _pricing = null;
    _lastFetch = null;
    await fetchPricing(forceRefresh: true);
  }

  /// Debug helper to print current pricing
  void debugPrintPricing() {
    debugPrint('📊 [PricingService] Current Pricing:');
    debugPrint('  Razorpay:');
    debugPrint(
        '    Standard: ${pricing.razorpay.standard.formatted} (Product ID: ${pricing.razorpay.standard.productId ?? "N/A"})');
    debugPrint(
        '    Plus: ${pricing.razorpay.plus.formatted} (Product ID: ${pricing.razorpay.plus.productId ?? "N/A"})');
    debugPrint(
        '    Premium: ${pricing.razorpay.premium.formatted} (Product ID: ${pricing.razorpay.premium.productId ?? "N/A"})');
    debugPrint('  Google Play:');
    debugPrint(
        '    Standard: ${pricing.googlePlay.standard.formatted} (Product ID: ${pricing.googlePlay.standard.productId ?? "N/A"})');
    debugPrint(
        '    Plus: ${pricing.googlePlay.plus.formatted} (Product ID: ${pricing.googlePlay.plus.productId ?? "N/A"})');
    debugPrint(
        '    Premium: ${pricing.googlePlay.premium.formatted} (Product ID: ${pricing.googlePlay.premium.productId ?? "N/A"})');
    debugPrint('  Apple App Store:');
    debugPrint(
        '    Standard: ${pricing.appleAppStore.standard.formatted} (Product ID: ${pricing.appleAppStore.standard.productId ?? "N/A"})');
    debugPrint(
        '    Plus: ${pricing.appleAppStore.plus.formatted} (Product ID: ${pricing.appleAppStore.plus.productId ?? "N/A"})');
    debugPrint(
        '    Premium: ${pricing.appleAppStore.premium.formatted} (Product ID: ${pricing.appleAppStore.premium.productId ?? "N/A"})');
    debugPrint('  Last Fetch: $_lastFetch');
    debugPrint('  Cache Valid: ${_isCacheValid()}');
  }
}
