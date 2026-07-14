// Apple Consumable Purchase Service
//
// Drives the iOS consumable purchase flow (token packs and developer tips):
// StoreKit purchase → backend verification (confirm-apple-purchase) →
// completePurchase acknowledgment. Purchases stay unacknowledged until the
// backend confirms, so StoreKit redelivers them on next launch if we crash
// or the network drops — the backend endpoint is idempotent.

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/logger.dart';
import 'api_auth_helper.dart';
import 'iap_service.dart';

enum ConsumableKind { tokens, tip }

class ConsumablePurchaseResult {
  final ConsumableKind kind;
  final int tokensCredited;
  final bool alreadyFulfilled;

  const ConsumablePurchaseResult({
    required this.kind,
    required this.tokensCredited,
    required this.alreadyFulfilled,
  });
}

class AppleConsumablePurchaseService {
  static const tokenProductPrefix = 'com.disciplefy.tokens_';
  static const tipProductPrefix = 'com.disciplefy.tip_';

  /// Fixed tip tiers (rupee amounts). Product IDs: `com.disciplefy.tip_{amount}`
  static const tipAmounts = [49, 199, 499, 999];

  final IAPService _iapService;
  final SupabaseClient _supabaseClient;

  // Flow callbacks — set by the page driving the purchase
  void Function(ConsumablePurchaseResult result)? onSuccess;
  void Function(String message)? onError;
  void Function()? onCancelled;

  bool _bound = false;

  AppleConsumablePurchaseService({
    required IAPService iapService,
    required SupabaseClient supabaseClient,
  })  : _iapService = iapService,
        _supabaseClient = supabaseClient;

  static String tokenProductId(int tokens) => '$tokenProductPrefix$tokens';
  static String tipProductId(int amount) => '$tipProductPrefix$amount';

  /// Wire this service into IAPService's consumable callbacks.
  /// Safe to call repeatedly (e.g. from each page's initState).
  void bind() {
    _iapService.onConsumablePurchaseUpdate = _handlePurchaseUpdate;
    _iapService.onConsumablePurchaseError = (message) => onError?.call(message);
    _iapService.onConsumablePurchaseCancelled = () => onCancelled?.call();
    _bound = true;
  }

  /// Load StoreKit products for the given token pack sizes.
  /// Returns products keyed by token count; missing packs are skipped
  /// (not yet configured in App Store Connect).
  Future<Map<int, ProductDetails>> loadTokenPackProducts(
      List<int> packTokens) async {
    final ids = packTokens.map(tokenProductId).toSet();
    final products = await _iapService.getProducts(ids);
    return {
      for (final p in products)
        if (int.tryParse(p.id.replaceFirst(tokenProductPrefix, '')) != null)
          int.parse(p.id.replaceFirst(tokenProductPrefix, '')): p,
    };
  }

  /// Load StoreKit products for the tip tiers, keyed by rupee amount.
  Future<Map<int, ProductDetails>> loadTipProducts() async {
    final ids = tipAmounts.map(tipProductId).toSet();
    final products = await _iapService.getProducts(ids);
    return {
      for (final p in products)
        if (int.tryParse(p.id.replaceFirst(tipProductPrefix, '')) != null)
          int.parse(p.id.replaceFirst(tipProductPrefix, '')): p,
    };
  }

  Future<void> purchase(ProductDetails product) async {
    assert(_bound, 'Call bind() before purchase()');
    await _iapService.purchaseConsumable(product);
  }

  Future<void> _handlePurchaseUpdate(PurchaseDetails purchase) async {
    final kind = purchase.productID.startsWith(tipProductPrefix)
        ? ConsumableKind.tip
        : ConsumableKind.tokens;
    try {
      Logger.debug(
          '🪙 [CONSUMABLE] Confirming ${purchase.productID} with backend');
      final receipt = await _iapService.getReceiptData(purchase);
      final headers = await ApiAuthHelper.getAuthHeaders();

      final response = await _supabaseClient.functions.invoke(
        'confirm-apple-purchase',
        body: {
          'receipt': receipt,
          'product_id': purchase.productID,
          'kind': kind.name,
        },
        headers: headers,
      );

      final data = response.data as Map<String, dynamic>?;
      if (response.status == 200 && data?['success'] == true) {
        // Acknowledge ONLY after the backend has fulfilled the purchase.
        await _iapService.acknowledgePurchase(purchase);
        Logger.info(
            '🪙 [CONSUMABLE] ✅ ${kind.name} purchase fulfilled: ${purchase.productID}');
        onSuccess?.call(ConsumablePurchaseResult(
          kind: kind,
          tokensCredited: (data?['tokens_credited'] as num?)?.toInt() ?? 0,
          alreadyFulfilled: data?['already_fulfilled'] == true,
        ));
      } else {
        final message = (data?['error'] is Map)
            ? ((data?['error']?['message'] as String?) ?? 'Verification failed')
            : ((data?['error'] as String?) ?? 'Verification failed');
        Logger.error(
            '🪙 [CONSUMABLE] Backend rejected purchase: $message (status ${response.status})');
        // Leave unacknowledged — StoreKit redelivers, backend is idempotent.
        onError?.call(message);
      }
    } catch (e) {
      Logger.error('🪙 [CONSUMABLE] Confirmation failed', error: e);
      // Leave unacknowledged for retry on next launch.
      onError?.call(
          'Could not confirm your purchase. It will be retried automatically.');
    }
  }
}
