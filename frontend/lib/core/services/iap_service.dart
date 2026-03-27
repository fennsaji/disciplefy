// In-App Purchase Service
//
// Handles Google Play and Apple App Store in-app purchases.
// Manages purchase flow, receipt extraction, and restoration.

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';
import '../utils/logger.dart';

class IAPService {
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  // Guard against concurrent restorePurchases() calls from multiple BLoC instances
  bool _restoreInProgress = false; // mutable — cannot be final

  // Sync-mode restore: collects purchases without triggering subscription creation
  bool _isSyncRestore = false;
  final List<PurchaseDetails> _syncPurchases = [];

  // Callbacks
  Function(PurchaseDetails)? onPurchaseUpdate;
  Function(String)? onPurchaseError;
  void Function()? onPurchaseCancelled;
  void Function(List<PurchaseDetails> purchases)? onSyncRestoreCompleted;

  /// Initialize IAP service
  Future<void> initialize() async {
    if (kIsWeb) {
      Logger.debug('🛒 [IAP] Web platform - IAP not available');
      return;
    }

    // Cancel any existing subscription before re-initializing to prevent
    // multiple stream listeners delivering the same purchase twice.
    await _subscription?.cancel();
    _subscription = null;

    // Check if IAP is available
    final available = await _iap.isAvailable();
    if (!available) {
      Logger.debug('🛒 [IAP] Store not available on this device');
      return;
    }

    // iOS-specific setup
    if (Platform.isIOS) {
      final iosPlatform =
          _iap.getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>();
      await iosPlatform.setDelegate(PaymentQueueDelegate());
    }

    // Listen to purchase updates
    _subscription = _iap.purchaseStream.listen(
      _handlePurchaseUpdate,
      onDone: () => Logger.debug('🛒 [IAP] Purchase stream closed'),
      onError: (error) {
        Logger.debug('🛒 [IAP] Purchase stream error: $error');
        onPurchaseError?.call(error.toString());
      },
    );

    Logger.debug('🛒 [IAP] Service initialized');
  }

  /// Dispose IAP service
  void dispose() {
    _subscription?.cancel();
    Logger.debug('🛒 [IAP] Service disposed');
  }

  /// Fetch available products from store
  Future<List<ProductDetails>> getProducts(Set<String> productIds) async {
    Logger.debug('🛒 [IAP] Fetching products: $productIds');

    final response = await _iap.queryProductDetails(productIds);

    if (response.error != null) {
      Logger.debug('🛒 [IAP] Error fetching products: ${response.error}');
      throw Exception('Failed to fetch products: ${response.error?.message}');
    }

    if (response.productDetails.isEmpty) {
      Logger.debug('🛒 [IAP] No products found');
      throw Exception('No products found for the given IDs');
    }

    Logger.debug('🛒 [IAP] Found ${response.productDetails.length} products');
    return response.productDetails;
  }

  /// Purchase a product.
  ///
  /// [oldPurchaseDetails] — provide when upgrading/downgrading an existing
  /// Google Play subscription. Passing the old purchase tells Google Play to
  /// replace that subscription instead of creating an independent new one,
  /// which prevents two active subscriptions appearing simultaneously.
  Future<void> purchaseProduct(
    ProductDetails productDetails, {
    GooglePlayPurchaseDetails? oldPurchaseDetails,
  }) async {
    Logger.debug('🛒 [IAP] Initiating purchase: ${productDetails.id}');

    late PurchaseParam purchaseParam;

    if (Platform.isAndroid) {
      ChangeSubscriptionParam? changeParam;
      if (oldPurchaseDetails != null) {
        changeParam = ChangeSubscriptionParam(
          oldPurchaseDetails: oldPurchaseDetails,
          replacementMode: ReplacementMode.withTimeProration,
        );
        Logger.debug(
            '🛒 [IAP] changeSubscriptionParam set — replacing ${oldPurchaseDetails.productID}');
      }
      // GooglePlayPurchaseParam automatically surfaces the offerToken from
      // GooglePlayProductDetails.offerToken (via subscriptionIndex) inside the
      // platform layer — no explicit offerToken parameter is needed here.
      purchaseParam = GooglePlayPurchaseParam(
        productDetails: productDetails,
        changeSubscriptionParam: changeParam,
      );
    } else {
      purchaseParam = PurchaseParam(productDetails: productDetails);
    }

    try {
      final success = await _iap.buyNonConsumable(purchaseParam: purchaseParam);

      if (!success) {
        Logger.debug('🛒 [IAP] Purchase initiation failed');
        onPurchaseError?.call('Failed to initiate purchase');
      }
    } catch (e) {
      Logger.debug('🛒 [IAP] Purchase error: $e');
      onPurchaseError?.call(e.toString());
    }
  }

  /// Query existing Google Play purchases to find one matching [productId].
  ///
  /// Used when upgrading/downgrading a subscription so the old purchase can be
  /// passed as [ChangeSubscriptionParam.oldPurchaseDetails].
  /// Returns null if not on Android, if the product is not found, or if the
  /// query fails (caller should proceed without the param).
  Future<GooglePlayPurchaseDetails?> findExistingGooglePlayPurchase(
      String productId) async {
    if (!Platform.isAndroid) return null;
    try {
      final androidAddition =
          _iap.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      final response = await androidAddition.queryPastPurchases();
      for (final GooglePlayPurchaseDetails purchase in response.pastPurchases) {
        if (purchase.productID == productId) {
          Logger.debug(
              '🛒 [IAP] Found existing purchase for $productId: ${purchase.purchaseID}');
          return purchase;
        }
      }
      Logger.debug('🛒 [IAP] No existing purchase found for $productId');
    } catch (e) {
      Logger.debug('🛒 [IAP] queryPastPurchases failed (non-fatal): $e');
    }
    return null;
  }

  /// Restore previous purchases
  ///
  /// Guarded against concurrent calls — if multiple BLoC instances (one per
  /// route + one from the main.dart lifecycle) all call this simultaneously,
  /// only the first completes; subsequent calls are silently dropped.
  Future<void> restorePurchases() async {
    if (_restoreInProgress) {
      Logger.debug('🛒 [IAP] Restore already in progress — skipping duplicate');
      return;
    }

    _restoreInProgress = true;
    Logger.debug('🛒 [IAP] Restoring purchases');

    try {
      await _iap.restorePurchases();
      Logger.debug('🛒 [IAP] Restore completed');
    } catch (e) {
      Logger.debug('🛒 [IAP] Restore error: $e');
      onPurchaseError?.call('Failed to restore purchases: $e');
    } finally {
      _restoreInProgress = false;
    }
  }

  /// Restore purchases in sync mode — collects device-side purchases without
  /// triggering subscription creation. Timer-gated (5 s) to let Google Play
  /// deliver all pending purchase updates.
  ///
  /// After the timer completes, [onSyncRestoreCompleted] is called with the
  /// collected purchases (empty list = device has no active purchases).
  Future<void> restorePurchasesForSync() async {
    if (_restoreInProgress) {
      Logger.debug(
          '🛒 [IAP] Restore already in progress — skipping sync restore');
      return;
    }
    _restoreInProgress = true;
    _isSyncRestore = true;
    _syncPurchases.clear();
    Logger.debug('🛒 [IAP] Starting sync-mode restore');
    try {
      await _iap.restorePurchases();
      // Wait 5 s for Google Play to deliver all pending purchase updates
      await Future.delayed(const Duration(seconds: 5));
    } finally {
      final collected = List<PurchaseDetails>.from(_syncPurchases);
      _syncPurchases.clear();
      _isSyncRestore = false;
      _restoreInProgress = false;
      Logger.debug(
          '🛒 [IAP] Sync restore complete — ${collected.length} purchase(s) collected');
      onSyncRestoreCompleted?.call(collected);
    }
  }

  /// Handle purchase updates from store
  void _handlePurchaseUpdate(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      Logger.debug(
          '🛒 [IAP] Purchase update: ${purchase.productID}, status: ${purchase.status}');

      // In sync-mode, collect purchases silently without notifying the BLoC.
      // This prevents the normal flow from creating duplicate subscriptions.
      if (_isSyncRestore) {
        if (purchase.status == PurchaseStatus.purchased ||
            purchase.status == PurchaseStatus.restored) {
          _syncPurchases.add(purchase);
        }
        continue;
      }

      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        // Notify BLoC — acknowledgment (completePurchase) happens AFTER
        // backend validation succeeds, so Google Play re-delivers on next
        // app start if the backend call fails.
        onPurchaseUpdate?.call(purchase);
      } else if (purchase.status == PurchaseStatus.error) {
        Logger.debug('🛒 [IAP] Purchase error: ${purchase.error}');
        onPurchaseError?.call(purchase.error?.message ?? 'Purchase failed');
        // Clear failed transactions from the queue immediately.
        if (purchase.pendingCompletePurchase) {
          _iap.completePurchase(purchase);
        }
      } else if (purchase.status == PurchaseStatus.canceled) {
        Logger.debug('🛒 [IAP] Purchase cancelled by user');
        onPurchaseCancelled?.call();
        if (purchase.pendingCompletePurchase) {
          _iap.completePurchase(purchase);
        }
      }
      // Note: PurchaseStatus.pending — no action; wait for a terminal status.
    }
  }

  /// Acknowledge a purchase after successful backend validation.
  ///
  /// Must be called by the BLoC once the subscription has been created in the
  /// backend. Until this is called Google Play / App Store will re-deliver
  /// the purchase on every app start, giving us automatic retry on failure.
  Future<void> acknowledgePurchase(PurchaseDetails purchase) async {
    if (purchase.pendingCompletePurchase) {
      await _iap.completePurchase(purchase);
      Logger.debug('✅ [IAP] Purchase acknowledged: ${purchase.productID}');
    }
  }

  /// Extract receipt data for backend validation
  ///
  /// Throws [Exception] if receipt data cannot be extracted.
  String getReceiptData(PurchaseDetails purchase) {
    try {
      if (Platform.isAndroid) {
        final androidPurchase = purchase as GooglePlayPurchaseDetails;
        final receipt = androidPurchase.billingClientPurchase.originalJson;
        if (receipt.isEmpty) {
          throw Exception('Google Play receipt data is empty');
        }
        return receipt;
      } else if (Platform.isIOS) {
        final iosPurchase = purchase as AppStorePurchaseDetails;
        final receipt = iosPurchase.verificationData.serverVerificationData;
        if (receipt.isEmpty) {
          throw Exception('App Store receipt data is empty');
        }
        return receipt;
      }
      throw Exception('Unsupported platform for receipt extraction');
    } catch (e) {
      Logger.debug('🛒 [IAP] Failed to extract receipt data: $e');
      rethrow;
    }
  }

  /// Get product ID from purchase
  String getProductId(PurchaseDetails purchase) {
    return purchase.productID;
  }

  /// Get transaction ID from purchase
  String getTransactionId(PurchaseDetails purchase) {
    if (Platform.isAndroid) {
      final androidPurchase = purchase as GooglePlayPurchaseDetails;
      return androidPurchase.billingClientPurchase.orderId;
    } else if (Platform.isIOS) {
      final iosPurchase = purchase as AppStorePurchaseDetails;
      return iosPurchase.skPaymentTransaction.transactionIdentifier ?? '';
    }

    return '';
  }

  /// Get purchase token (Android only)
  String? getPurchaseToken(PurchaseDetails purchase) {
    if (Platform.isAndroid) {
      final androidPurchase = purchase as GooglePlayPurchaseDetails;
      return androidPurchase.billingClientPurchase.purchaseToken;
    }
    return null;
  }

  /// Get package name (Android only)
  String? getPackageName(PurchaseDetails purchase) {
    if (Platform.isAndroid) {
      final androidPurchase = purchase as GooglePlayPurchaseDetails;
      return androidPurchase.billingClientPurchase.packageName;
    }
    return null;
  }
}

/// iOS Payment Queue Delegate
class PaymentQueueDelegate implements SKPaymentQueueDelegateWrapper {
  @override
  bool shouldContinueTransaction(
    SKPaymentTransactionWrapper transaction,
    SKStorefrontWrapper storefront,
  ) {
    return true;
  }

  @override
  bool shouldShowPriceConsent() {
    return false;
  }
}
