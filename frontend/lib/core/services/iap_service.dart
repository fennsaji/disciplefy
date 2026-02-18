// In-App Purchase Service
//
// Handles Google Play and Apple App Store in-app purchases.
// Manages purchase flow, receipt extraction, and restoration.

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';
import '../utils/logger.dart';

class IAPService {
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  // Callbacks
  Function(PurchaseDetails)? onPurchaseUpdate;
  Function(String)? onPurchaseError;

  /// Initialize IAP service
  Future<void> initialize() async {
    if (kIsWeb) {
      Logger.debug('🛒 [IAP] Web platform - IAP not available');
      return;
    }

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

  /// Purchase a product
  Future<void> purchaseProduct(ProductDetails product) async {
    Logger.debug('🛒 [IAP] Initiating purchase: ${product.id}');

    final purchaseParam = PurchaseParam(productDetails: product);

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

  /// Restore previous purchases
  Future<void> restorePurchases() async {
    Logger.debug('🛒 [IAP] Restoring purchases');

    try {
      await _iap.restorePurchases();
      Logger.debug('🛒 [IAP] Restore completed');
    } catch (e) {
      Logger.debug('🛒 [IAP] Restore error: $e');
      onPurchaseError?.call('Failed to restore purchases: $e');
    }
  }

  /// Handle purchase updates from store
  void _handlePurchaseUpdate(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      Logger.debug(
          '🛒 [IAP] Purchase update: ${purchase.productID}, status: ${purchase.status}');

      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        // Notify callback with successful purchase
        onPurchaseUpdate?.call(purchase);
      } else if (purchase.status == PurchaseStatus.error) {
        Logger.debug('🛒 [IAP] Purchase error: ${purchase.error}');
        onPurchaseError?.call(purchase.error?.message ?? 'Purchase failed');
      } else if (purchase.status == PurchaseStatus.canceled) {
        Logger.debug('🛒 [IAP] Purchase cancelled by user');
        onPurchaseError?.call('Purchase cancelled');
      }

      // Complete pending transactions
      if (purchase.pendingCompletePurchase) {
        _iap.completePurchase(purchase);
      }
    }
  }

  /// Extract receipt data for backend validation
  String getReceiptData(PurchaseDetails purchase) {
    if (Platform.isAndroid) {
      // Google Play receipt
      final androidPurchase = purchase as GooglePlayPurchaseDetails;
      return androidPurchase.billingClientPurchase.originalJson;
    } else if (Platform.isIOS) {
      // Apple App Store receipt
      final iosPurchase = purchase as AppStorePurchaseDetails;
      return iosPurchase.verificationData.serverVerificationData;
    }

    return '';
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
