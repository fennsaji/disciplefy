import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/services/api_auth_helper.dart';
import '../models/token_status_model.dart';
import '../models/purchase_history_model.dart';
import '../models/purchase_statistics_model.dart' as stats;
import '../models/payment_preferences_model.dart' as prefs;
import '../models/saved_payment_method_model.dart';
import '../models/token_usage_history_model.dart';
import '../models/usage_statistics_model.dart';
import '../../domain/entities/payment_order_response.dart';

/// Abstract contract for remote token operations.
abstract class TokenRemoteDataSource {
  /// Fetches current token status for the authenticated user.
  ///
  /// Throws [NetworkException] if there's a network issue.
  /// Throws [ServerException] if there's a server error.
  /// Throws [AuthenticationException] if authentication fails.
  Future<TokenStatusModel> getTokenStatus();

  /// Creates a payment order for token purchase (step 1 of new flow)
  ///
  /// [tokenAmount] - Number of tokens to purchase (must be positive)
  ///
  /// Returns order ID for Razorpay payment gateway
  ///
  /// Throws [NetworkException] if there's a network issue.
  /// Throws [ServerException] if there's a server error.
  /// Throws [AuthenticationException] if authentication fails.
  /// Throws [ClientException] if order creation fails.
  Future<PaymentOrderResponse> createPaymentOrder({
    required int tokenAmount,
  });

  /// Confirms payment after successful Razorpay transaction (step 2 of new flow)
  ///
  /// [paymentId] - Razorpay payment ID
  /// [orderId] - Razorpay order ID
  /// [signature] - Razorpay payment signature
  /// [tokenAmount] - Number of tokens purchased
  ///
  /// Returns updated token status after purchase
  ///
  /// Throws [NetworkException] if there's a network issue.
  /// Throws [ServerException] if there's a server error.
  /// Throws [AuthenticationException] if authentication fails.
  /// Throws [ClientException] if payment verification fails.
  Future<TokenStatusModel> confirmPayment({
    required String paymentId,
    required String orderId,
    required String signature,
    required int tokenAmount,
  });

  /// Gets purchase history for the authenticated user.
  ///
  /// [limit] - Maximum number of purchases to return (optional)
  /// [offset] - Number of purchases to skip (optional)
  ///
  /// Returns list of purchase history records
  ///
  /// Throws [NetworkException] if there's a network issue.
  /// Throws [ServerException] if there's a server error.
  /// Throws [AuthenticationException] if authentication fails.
  Future<List<PurchaseHistoryModel>> getPurchaseHistory({
    int? limit,
    int? offset,
  });

  /// Gets purchase statistics for the authenticated user.
  ///
  /// Returns aggregated purchase statistics
  ///
  /// Throws [NetworkException] if there's a network issue.
  /// Throws [ServerException] if there's a server error.
  /// Throws [AuthenticationException] if authentication fails.
  Future<stats.PurchaseStatisticsModel> getPurchaseStatistics();

  /// Gets saved payment methods for the authenticated user.
  ///
  /// Returns list of saved payment methods
  ///
  /// Throws [NetworkException] if there's a network issue.
  /// Throws [ServerException] if there's a server error.
  /// Throws [AuthenticationException] if authentication fails.
  Future<List<SavedPaymentMethodModel>> getPaymentMethods();

  /// Saves a new payment method for the authenticated user.
  ///
  /// Returns the ID of the saved payment method
  ///
  /// Throws [NetworkException] if there's a network issue.
  /// Throws [ServerException] if there's a server error.
  /// Throws [AuthenticationException] if authentication fails.
  Future<String> savePaymentMethod({
    required String methodType,
    required String provider,
    required String token,
    String? lastFour,
    String? brand,
    String? displayName,
    bool isDefault = false,
    int? expiryMonth,
    int? expiryYear,
  });

  /// Sets a payment method as default.
  ///
  /// Returns true on success
  ///
  /// Throws [NetworkException] if there's a network issue.
  /// Throws [ServerException] if there's a server error.
  /// Throws [AuthenticationException] if authentication fails.
  Future<bool> setDefaultPaymentMethod(String methodId);

  /// Updates payment method usage timestamp and increments usage count.
  ///
  /// This should be called whenever a payment method is used successfully
  /// to track usage patterns and update last used timestamp.
  ///
  /// Returns true on success
  ///
  /// Throws [NetworkException] if there's a network issue.
  /// Throws [ServerException] if there's a server error.
  /// Throws [AuthenticationException] if authentication fails.
  Future<bool> updatePaymentMethodUsage(String methodId);

  /// Records payment method usage with additional context for analytics.
  ///
  /// [methodId] - ID of the payment method used
  /// [transactionAmount] - Amount of the transaction
  /// [transactionType] - Type of transaction ('token_purchase', 'subscription', etc.)
  /// [metadata] - Additional tracking data
  ///
  /// Returns true on success
  Future<bool> recordPaymentMethodUsage({
    required String methodId,
    required double transactionAmount,
    required String transactionType,
    Map<String, dynamic>? metadata,
  });

  /// Deletes a payment method.
  ///
  /// Returns true on success
  ///
  /// Throws [NetworkException] if there's a network issue.
  /// Throws [ServerException] if there's a server error.
  /// Throws [AuthenticationException] if authentication fails.
  Future<bool> deletePaymentMethod(String methodId);

  /// Gets payment preferences for the authenticated user.
  ///
  /// Returns payment preferences
  ///
  /// Throws [NetworkException] if there's a network issue.
  /// Throws [ServerException] if there's a server error.
  /// Throws [AuthenticationException] if authentication fails.
  Future<prefs.PaymentPreferencesModel> getPaymentPreferences();

  /// Updates payment preferences for the authenticated user.
  ///
  /// Returns updated preferences
  ///
  /// Throws [NetworkException] if there's a network issue.
  /// Throws [ServerException] if there's a server error.
  /// Throws [AuthenticationException] if authentication fails.
  Future<prefs.PaymentPreferencesModel> updatePaymentPreferences({
    bool? autoSavePaymentMethods,
    String? preferredWallet,
    bool? enableOneClickPurchase,
    String? defaultPaymentType,
  });

  /// Gets token usage history for the authenticated user.
  ///
  /// [limit] - Maximum number of records to return (1-100, default 20)
  /// [offset] - Number of records to skip for pagination (default 0)
  /// [startDate] - Optional start date for filtering records
  /// [endDate] - Optional end date for filtering records
  ///
  /// Returns list of token usage history records ordered by created_at DESC
  ///
  /// Throws [NetworkException] if there's a network issue.
  /// Throws [ServerException] if there's a server error.
  /// Throws [AuthenticationException] if authentication fails.
  Future<List<TokenUsageHistoryModel>> getUsageHistory({
    int? limit,
    int? offset,
    DateTime? startDate,
    DateTime? endDate,
  });

  /// Gets aggregated token usage statistics for the authenticated user.
  ///
  /// [startDate] - Optional start date for filtering statistics
  /// [endDate] - Optional end date for filtering statistics
  ///
  /// Returns aggregated statistics including:
  /// - Total tokens consumed
  /// - Total operations performed
  /// - Daily vs purchased token breakdown
  /// - Most used feature, language, and study mode
  /// - Breakdowns by feature, language, and study mode
  ///
  /// Throws [NetworkException] if there's a network issue.
  /// Throws [ServerException] if there's a server error.
  /// Throws [AuthenticationException] if authentication fails.
  Future<UsageStatisticsModel> getUsageStatistics({
    DateTime? startDate,
    DateTime? endDate,
  });

  /// Legacy method - Purchases additional tokens for standard plan users.
  ///
  /// [tokenAmount] - Number of tokens to purchase (must be positive)
  /// [paymentOrderId] - Razorpay payment order ID
  /// [paymentId] - Razorpay payment ID
  /// [signature] - Razorpay payment signature
  ///
  /// Throws [NetworkException] if there's a network issue.
  /// Throws [ServerException] if there's a server error.
  /// Throws [AuthenticationException] if authentication fails.
  /// Throws [ClientException] if purchase validation fails.
}

/// Implementation of TokenRemoteDataSource using Supabase.
class TokenRemoteDataSourceImpl implements TokenRemoteDataSource {
  /// Supabase client for API calls.
  final SupabaseClient _supabaseClient;

  /// Track ongoing payment confirmations to prevent duplicates
  final Set<String> _processingPayments = <String>{};

  /// Creates a new TokenRemoteDataSourceImpl instance.
  TokenRemoteDataSourceImpl({
    required SupabaseClient supabaseClient,
  }) : _supabaseClient = supabaseClient;

  @override
  Future<TokenStatusModel> getTokenStatus() async {
    try {
      // Validate token before making authenticated request
      await ApiAuthHelper.validateTokenForRequest();

      // Use unified authentication helper
      final headers = await ApiAuthHelper.getAuthHeaders();

      print('🪙 [TOKEN_API] Fetching token status...');

      // Call Supabase Edge Function for token status
      final response = await _supabaseClient.functions.invoke(
        'token-status',
        method: HttpMethod.get,
        headers: headers,
      );

      print('🪙 [TOKEN_API] Response status: ${response.status}');
      print('🪙 [TOKEN_API] Response data: ${response.data}');

      if (response.status == 200 && response.data != null) {
        final responseData = response.data as Map<String, dynamic>;

        if (responseData['success'] == true) {
          return TokenStatusModel.fromJson(responseData);
        } else {
          final error = responseData['error'] as Map<String, dynamic>?;
          throw ServerException(
            message:
                error?['message'] as String? ?? 'Failed to fetch token status',
            code: error?['code'] as String? ?? 'TOKEN_STATUS_ERROR',
          );
        }
      } else if (response.status == 401) {
        throw const AuthenticationException(
          message: 'Authentication required. Please sign in to continue.',
          code: 'UNAUTHORIZED',
        );
      } else if (response.status >= 500) {
        throw const ServerException(
          message: 'Server error occurred. Please try again later.',
          code: 'SERVER_ERROR',
        );
      } else {
        throw const ServerException(
          message: 'Failed to fetch token status. Please try again later.',
          code: 'TOKEN_STATUS_ERROR',
        );
      }
    } on NetworkException {
      rethrow;
    } on ServerException {
      rethrow;
    } on AuthenticationException {
      rethrow;
    } on TokenValidationException {
      // Convert to AuthenticationException for consistency
      throw const AuthenticationException(
        message: 'Authentication token is invalid. Please sign in again.',
        code: 'TOKEN_INVALID',
      );
    } catch (e) {
      print('🚨 [TOKEN_API] Unexpected error: $e');
      throw ClientException(
        message: 'Unable to fetch token information. Please try again later.',
        code: 'TOKEN_STATUS_FAILED',
        context: {'originalError': e.toString()},
      );
    }
  }

  @override
  Future<PaymentOrderResponse> createPaymentOrder({
    required int tokenAmount,
  }) async {
    try {
      // Validate token before making authenticated request
      await ApiAuthHelper.validateTokenForRequest();

      // Use unified authentication helper
      final headers = await ApiAuthHelper.getAuthHeaders();

      print('🪙 [TOKEN_API] Creating payment order for $tokenAmount tokens...');

      // Validate input parameters
      if (tokenAmount <= 0) {
        throw const ClientException(
          message: 'Token amount must be greater than zero',
          code: 'INVALID_TOKEN_AMOUNT',
        );
      }

      // Call Supabase Edge Function for order creation
      final response = await _supabaseClient.functions.invoke(
        'purchase-tokens',
        body: {
          'token_amount': tokenAmount,
          // No payment details - this is just order creation
        },
        headers: headers,
      );

      print(
          '🪙 [TOKEN_API] Order creation response status: ${response.status}');
      print('🪙 [TOKEN_API] Order creation response data: ${response.data}');

      if (response.status == 200 && response.data != null) {
        final responseData = response.data as Map<String, dynamic>;

        if (responseData['success'] == true) {
          final orderId = responseData['order_id'] as String;
          final keyId = responseData['key_id'] as String;
          final tokenAmount = responseData['token_amount'] as int;
          final amount = responseData['amount'] as int;
          final currency = responseData['currency'] as String;

          return PaymentOrderResponse(
            orderId: orderId,
            keyId: keyId,
            tokenAmount: tokenAmount,
            amount: amount,
            currency: currency,
          );
        } else {
          final error = responseData['error'] as Map<String, dynamic>?;
          throw ServerException(
            message: error?['message'] as String? ?? 'Order creation failed',
            code: error?['code'] as String? ?? 'ORDER_CREATION_FAILED',
          );
        }
      } else if (response.status == 400) {
        final errorData = response.data as Map<String, dynamic>?;
        final error = errorData?['error'] as Map<String, dynamic>?;
        throw ClientException(
          message: error?['message'] as String? ?? 'Invalid order request',
          code: error?['code'] as String? ?? 'INVALID_REQUEST',
        );
      } else if (response.status == 401) {
        throw const AuthenticationException(
          message: 'Authentication required. Please sign in to continue.',
          code: 'UNAUTHORIZED',
        );
      } else if (response.status == 403) {
        throw const ClientException(
          message: 'Order creation is not available for your account type.',
          code: 'ORDER_NOT_ALLOWED',
        );
      } else if (response.status >= 500) {
        throw const ServerException(
          message:
              'Server error occurred during order creation. Please try again later.',
          code: 'SERVER_ERROR',
        );
      } else {
        throw const ServerException(
          message: 'Order creation failed. Please try again later.',
          code: 'ORDER_CREATION_FAILED',
        );
      }
    } on NetworkException {
      rethrow;
    } on ServerException {
      rethrow;
    } on AuthenticationException {
      rethrow;
    } on ClientException {
      rethrow;
    } on TokenValidationException {
      throw const AuthenticationException(
        message: 'Authentication token is invalid. Please sign in again.',
        code: 'TOKEN_INVALID',
      );
    } catch (e) {
      print('🚨 [TOKEN_API] Unexpected order creation error: $e');
      throw ClientException(
        message: 'Unable to create payment order. Please try again later.',
        code: 'ORDER_CREATION_FAILED',
        context: {'originalError': e.toString()},
      );
    }
  }

  @override
  Future<TokenStatusModel> confirmPayment({
    required String paymentId,
    required String orderId,
    required String signature,
    required int tokenAmount,
  }) async {
    // Prevent duplicate payment confirmation calls
    if (_processingPayments.contains(paymentId)) {
      print(
          '⚠️ [TOKEN_API] Payment $paymentId already being confirmed - throwing duplicate error');
      throw const ClientException(
        message: 'Payment confirmation already in progress',
        code: 'DUPLICATE_PAYMENT_CONFIRMATION',
      );
    }

    // Mark payment as being processed
    _processingPayments.add(paymentId);
    print(
        '🔒 [TOKEN_API] Payment $paymentId marked as processing at HTTP level');

    try {
      await ApiAuthHelper.validateTokenForRequest();
      final headers = await ApiAuthHelper.getAuthHeaders();

      print('🪙 [TOKEN_API] Confirming payment: $paymentId');

      _validateConfirmPaymentParams(paymentId, orderId, signature, tokenAmount);

      final response = await _callConfirmPaymentAPI(
        paymentId: paymentId,
        orderId: orderId,
        signature: signature,
        tokenAmount: tokenAmount,
        headers: headers,
      );

      final result = _processConfirmPaymentResponse(response);

      // Clean up processing set on success
      _processingPayments.remove(paymentId);
      print(
          '🧹 [TOKEN_API] Payment $paymentId removed from processing set (success)');

      return result;
    } on NetworkException {
      _processingPayments.remove(paymentId);
      print(
          '🧹 [TOKEN_API] Payment $paymentId removed from processing set (NetworkException)');
      rethrow;
    } on ServerException {
      _processingPayments.remove(paymentId);
      print(
          '🧹 [TOKEN_API] Payment $paymentId removed from processing set (ServerException)');
      rethrow;
    } on AuthenticationException {
      _processingPayments.remove(paymentId);
      print(
          '🧹 [TOKEN_API] Payment $paymentId removed from processing set (AuthenticationException)');
      rethrow;
    } on ClientException {
      _processingPayments.remove(paymentId);
      print(
          '🧹 [TOKEN_API] Payment $paymentId removed from processing set (ClientException)');
      rethrow;
    } on TokenValidationException {
      _processingPayments.remove(paymentId);
      print(
          '🧹 [TOKEN_API] Payment $paymentId removed from processing set (TokenValidationException)');
      throw const AuthenticationException(
        message: 'Authentication token is invalid. Please sign in again.',
        code: 'TOKEN_INVALID',
      );
    } catch (e) {
      _processingPayments.remove(paymentId);
      print(
          '🧹 [TOKEN_API] Payment $paymentId removed from processing set (UnexpectedException)');
      print('🚨 [TOKEN_API] Unexpected payment confirmation error: $e');
      throw ClientException(
        message: 'Unable to confirm payment. Please try again later.',
        code: 'CONFIRMATION_FAILED',
        context: {'originalError': e.toString()},
      );
    }
  }

  @override
  Future<List<PurchaseHistoryModel>> getPurchaseHistory({
    int? limit,
    int? offset,
  }) async {
    try {
      // Validate token before making authenticated request
      await ApiAuthHelper.validateTokenForRequest();

      // Use unified authentication helper
      final headers = await ApiAuthHelper.getAuthHeaders();

      print('🪙 [TOKEN_API] Fetching purchase history...');

      // Get purchase history from database
      var query = _supabaseClient
          .from('purchase_history')
          .select()
          .order('purchased_at', ascending: false);

      // Use range for pagination (don't combine with limit as they conflict)
      if (offset != null || limit != null) {
        final startRange = offset ?? 0;
        final endRange = startRange + (limit ?? 50) - 1;
        query = query.range(startRange, endRange);

        print(
            '🔍 [TOKEN_API] Using pagination range: $startRange to $endRange (offset: ${offset ?? 0}, limit: ${limit ?? 50})');
      }

      final response = await query;

      print(
          '🪙 [TOKEN_API] Purchase history response: ${response.length} records');

      return response
          .map((json) => PurchaseHistoryModel.fromJson(json))
          .toList();
    } on NetworkException {
      rethrow;
    } on ServerException {
      rethrow;
    } on AuthenticationException {
      rethrow;
    } on TokenValidationException {
      throw const AuthenticationException(
        message: 'Authentication token is invalid. Please sign in again.',
        code: 'TOKEN_INVALID',
      );
    } catch (e) {
      print('🚨 [TOKEN_API] Unexpected purchase history error: $e');
      throw ClientException(
        message: 'Unable to fetch purchase history. Please try again later.',
        code: 'PURCHASE_HISTORY_FAILED',
        context: {'originalError': e.toString()},
      );
    }
  }

  @override
  Future<stats.PurchaseStatisticsModel> getPurchaseStatistics() async {
    try {
      // Validate token before making authenticated request
      await ApiAuthHelper.validateTokenForRequest();

      // Use unified authentication helper
      final headers = await ApiAuthHelper.getAuthHeaders();

      print('🪙 [TOKEN_API] Fetching purchase statistics...');

      // Get current user ID for the statistics query
      final user = _supabaseClient.auth.currentUser;
      if (user?.id == null) {
        throw const AuthenticationException(
          message: 'User ID not available for statistics request',
          code: 'NO_USER_ID',
        );
      }

      // Get purchase statistics using the database function with user ID
      final response =
          await _supabaseClient.rpc('get_user_purchase_stats', params: {
        'p_user_id': user!.id,
      });

      print('🪙 [TOKEN_API] Purchase statistics response: $response');

      if (response != null && response is List && response.isNotEmpty) {
        // The RPC function returns a table (array of rows), we need the first row
        final statsData = response[0] as Map<String, dynamic>;

        // Transform the field names to match what the model expects
        final transformedData = {
          'total_purchases': statsData['total_purchases'],
          'total_amount_spent': statsData['total_spent'],
          'total_tokens_purchased': statsData['total_tokens'],
          'average_purchase_amount': statsData['average_purchase'],
          'first_purchase_date': null, // Not provided by the database function
          'last_purchase_date': statsData['last_purchase_date'],
          'most_used_payment_method': statsData['most_used_payment_method'],
        };

        return stats.PurchaseStatisticsModel.fromJson(transformedData);
      } else {
        // Return empty statistics if no data available
        return const stats.PurchaseStatisticsModel(
          totalPurchases: 0,
          totalAmountSpent: 0.0,
          totalTokensPurchased: 0,
          averagePurchaseAmount: 0.0,
        );
      }
    } on NetworkException {
      rethrow;
    } on ServerException {
      rethrow;
    } on AuthenticationException {
      rethrow;
    } on TokenValidationException {
      throw const AuthenticationException(
        message: 'Authentication token is invalid. Please sign in again.',
        code: 'TOKEN_INVALID',
      );
    } catch (e) {
      print('🚨 [TOKEN_API] Unexpected purchase statistics error: $e');
      throw ClientException(
        message: 'Unable to fetch purchase statistics. Please try again later.',
        code: 'PURCHASE_STATISTICS_FAILED',
        context: {'originalError': e.toString()},
      );
    }
  }

  @override
  Future<List<SavedPaymentMethodModel>> getPaymentMethods() async {
    try {
      // Validate token before making authenticated request
      await ApiAuthHelper.validateTokenForRequest();

      print('💳 [TOKEN_API] Fetching saved payment methods...');

      // Get payment methods from database using RPC function
      final response = await _supabaseClient.rpc('get_user_payment_methods');

      print(
          '💳 [TOKEN_API] Payment methods response: ${response?.length ?? 0} methods');

      if (response is List) {
        return response
            .map((json) =>
                SavedPaymentMethodModel.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        return [];
      }
    } on NetworkException {
      rethrow;
    } on ServerException {
      rethrow;
    } on AuthenticationException {
      rethrow;
    } on TokenValidationException {
      throw const AuthenticationException(
        message: 'Authentication token is invalid. Please sign in again.',
        code: 'TOKEN_INVALID',
      );
    } catch (e) {
      print('🚨 [TOKEN_API] Unexpected payment methods error: $e');
      throw ClientException(
        message: 'Unable to fetch payment methods. Please try again later.',
        code: 'PAYMENT_METHODS_FAILED',
        context: {'originalError': e.toString()},
      );
    }
  }

  @override
  Future<String> savePaymentMethod({
    required String methodType,
    required String provider,
    required String token,
    String? lastFour,
    String? brand,
    String? displayName,
    bool isDefault = false,
    int? expiryMonth,
    int? expiryYear,
  }) async {
    try {
      // Validate token before making authenticated request
      await ApiAuthHelper.validateTokenForRequest();

      print('💳 [TOKEN_API] Saving payment method: $methodType');

      // Get current user ID
      final user = _supabaseClient.auth.currentUser;
      if (user == null) {
        throw const AuthenticationException(
          message: 'User not authenticated',
          code: 'USER_NOT_AUTHENTICATED',
        );
      }

      // Save payment method using database function
      final response =
          await _supabaseClient.rpc('save_payment_method', params: {
        'p_user_id': user.id,
        'p_method_type': methodType,
        'p_provider': provider,
        'p_token': token,
        'p_last_four': lastFour,
        'p_brand': brand,
        'p_display_name': displayName,
        'p_is_default': isDefault,
        'p_expiry_month': expiryMonth,
        'p_expiry_year': expiryYear,
      });

      print('💳 [TOKEN_API] Payment method saved: $response');

      if (response != null) {
        return response as String;
      } else {
        throw const ServerException(
          message: 'Failed to save payment method',
          code: 'SAVE_PAYMENT_METHOD_FAILED',
        );
      }
    } on NetworkException {
      rethrow;
    } on ServerException {
      rethrow;
    } on AuthenticationException {
      rethrow;
    } on TokenValidationException {
      throw const AuthenticationException(
        message: 'Authentication token is invalid. Please sign in again.',
        code: 'TOKEN_INVALID',
      );
    } catch (e) {
      print('🚨 [TOKEN_API] Unexpected save payment method error: $e');
      throw ClientException(
        message: 'Unable to save payment method. Please try again later.',
        code: 'SAVE_PAYMENT_METHOD_FAILED',
        context: {'originalError': e.toString()},
      );
    }
  }

  @override
  Future<bool> setDefaultPaymentMethod(String methodId) async {
    try {
      // Validate token before making authenticated request
      await ApiAuthHelper.validateTokenForRequest();

      print('💳 [TOKEN_API] Setting default payment method: $methodId');

      // Get current user ID
      final user = _supabaseClient.auth.currentUser;
      if (user == null) {
        throw const AuthenticationException(
          message: 'User not authenticated',
          code: 'USER_NOT_AUTHENTICATED',
        );
      }

      // Set default payment method using database function
      final response =
          await _supabaseClient.rpc('set_default_payment_method', params: {
        'p_method_id': methodId,
        'p_user_id': user.id,
      });

      print('💳 [TOKEN_API] Default payment method result: $response');

      return response == true;
    } on NetworkException {
      rethrow;
    } on ServerException {
      rethrow;
    } on AuthenticationException {
      rethrow;
    } on TokenValidationException {
      throw const AuthenticationException(
        message: 'Authentication token is invalid. Please sign in again.',
        code: 'TOKEN_INVALID',
      );
    } catch (e) {
      print('🚨 [TOKEN_API] Unexpected set default payment method error: $e');
      throw ClientException(
        message:
            'Unable to set default payment method. Please try again later.',
        code: 'SET_DEFAULT_PAYMENT_METHOD_FAILED',
        context: {'originalError': e.toString()},
      );
    }
  }

  @override
  Future<bool> updatePaymentMethodUsage(String methodId) async {
    try {
      // Validate token before making authenticated request
      await ApiAuthHelper.validateTokenForRequest();

      print('💳 [TOKEN_API] Updating payment method usage: $methodId');

      // Get current user ID
      final user = _supabaseClient.auth.currentUser;
      if (user == null) {
        throw const AuthenticationException(
          message: 'User not authenticated',
          code: 'USER_NOT_AUTHENTICATED',
        );
      }

      // Update payment method usage using database function
      final response =
          await _supabaseClient.rpc('update_payment_method_usage', params: {
        'p_method_id': methodId,
        'p_user_id': user.id,
      });

      print('💳 [TOKEN_API] Payment method usage updated: $response');

      return response == true;
    } on NetworkException {
      rethrow;
    } on ServerException {
      rethrow;
    } on AuthenticationException {
      rethrow;
    } on TokenValidationException {
      throw const AuthenticationException(
        message: 'Authentication token is invalid. Please sign in again.',
        code: 'TOKEN_INVALID',
      );
    } catch (e) {
      print('🚨 [TOKEN_API] Unexpected update payment method usage error: $e');
      throw ClientException(
        message:
            'Unable to update payment method usage. Please try again later.',
        code: 'UPDATE_PAYMENT_METHOD_USAGE_FAILED',
        context: {'originalError': e.toString()},
      );
    }
  }

  @override
  Future<bool> recordPaymentMethodUsage({
    required String methodId,
    required double transactionAmount,
    required String transactionType,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // Validate token before making authenticated request
      await ApiAuthHelper.validateTokenForRequest();

      print(
          '💳 [TOKEN_API] Recording payment method usage: $methodId for $transactionType');

      // Get current user ID
      final user = _supabaseClient.auth.currentUser;
      if (user == null) {
        throw const AuthenticationException(
          message: 'User not authenticated',
          code: 'USER_NOT_AUTHENTICATED',
        );
      }

      // Record detailed payment method usage using database function
      final response =
          await _supabaseClient.rpc('record_payment_method_usage', params: {
        'p_method_id': methodId,
        'p_user_id': user.id,
        'p_transaction_amount': transactionAmount,
        'p_transaction_type': transactionType,
        'p_metadata': metadata ?? {},
      });

      print('💳 [TOKEN_API] Payment method usage recorded: $response');

      return response == true;
    } on NetworkException {
      rethrow;
    } on ServerException {
      rethrow;
    } on AuthenticationException {
      rethrow;
    } on TokenValidationException {
      throw const AuthenticationException(
        message: 'Authentication token is invalid. Please sign in again.',
        code: 'TOKEN_INVALID',
      );
    } catch (e) {
      print('🚨 [TOKEN_API] Unexpected record payment method usage error: $e');
      throw ClientException(
        message:
            'Unable to record payment method usage. Please try again later.',
        code: 'RECORD_PAYMENT_METHOD_USAGE_FAILED',
        context: {'originalError': e.toString()},
      );
    }
  }

  @override
  Future<bool> deletePaymentMethod(String methodId) async {
    try {
      // Validate token before making authenticated request
      await ApiAuthHelper.validateTokenForRequest();

      print('💳 [TOKEN_API] Deleting payment method: $methodId');

      // Get current user ID
      final user = _supabaseClient.auth.currentUser;
      if (user == null) {
        throw const AuthenticationException(
          message: 'User not authenticated',
          code: 'USER_NOT_AUTHENTICATED',
        );
      }

      // Delete payment method using database function
      final response =
          await _supabaseClient.rpc('delete_payment_method', params: {
        'p_method_id': methodId,
        'p_user_id': user.id,
      });

      print('💳 [TOKEN_API] Payment method deleted: $response');

      return response == true;
    } on NetworkException {
      rethrow;
    } on ServerException {
      rethrow;
    } on AuthenticationException {
      rethrow;
    } on TokenValidationException {
      throw const AuthenticationException(
        message: 'Authentication token is invalid. Please sign in again.',
        code: 'TOKEN_INVALID',
      );
    } catch (e) {
      print('🚨 [TOKEN_API] Unexpected delete payment method error: $e');
      throw ClientException(
        message: 'Unable to delete payment method. Please try again later.',
        code: 'DELETE_PAYMENT_METHOD_FAILED',
        context: {'originalError': e.toString()},
      );
    }
  }

  @override
  Future<prefs.PaymentPreferencesModel> getPaymentPreferences() async {
    try {
      // Validate token before making authenticated request
      await ApiAuthHelper.validateTokenForRequest();

      print('💳 [TOKEN_API] Fetching payment preferences...');

      // Get payment preferences using database function
      final response =
          await _supabaseClient.rpc('get_payment_preferences_for_user');

      print('💳 [TOKEN_API] Payment preferences response: $response');

      if (response != null) {
        return prefs.PaymentPreferencesModel.fromJson(
            response as Map<String, dynamic>);
      } else {
        throw const ServerException(
          message: 'No payment preferences data available',
          code: 'NO_PREFERENCES_DATA',
        );
      }
    } on NetworkException {
      rethrow;
    } on ServerException {
      rethrow;
    } on AuthenticationException {
      rethrow;
    } on TokenValidationException {
      throw const AuthenticationException(
        message: 'Authentication token is invalid. Please sign in again.',
        code: 'TOKEN_INVALID',
      );
    } catch (e) {
      print('🚨 [TOKEN_API] Unexpected payment preferences error: $e');
      throw ClientException(
        message: 'Unable to fetch payment preferences. Please try again later.',
        code: 'PAYMENT_PREFERENCES_FAILED',
        context: {'originalError': e.toString()},
      );
    }
  }

  @override
  Future<prefs.PaymentPreferencesModel> updatePaymentPreferences({
    bool? autoSavePaymentMethods,
    String? preferredWallet,
    bool? enableOneClickPurchase,
    String? defaultPaymentType,
  }) async {
    try {
      // Validate token before making authenticated request
      await ApiAuthHelper.validateTokenForRequest();

      print('💳 [TOKEN_API] Updating payment preferences...');

      // Get current user ID
      final user = _supabaseClient.auth.currentUser;
      if (user == null) {
        throw const AuthenticationException(
          message: 'User not authenticated',
          code: 'USER_NOT_AUTHENTICATED',
        );
      }

      // Update payment preferences using database function
      final response = await _supabaseClient
          .rpc('update_payment_preferences_for_user', params: {
        'p_user_id': user.id,
        'p_auto_save_payment_methods': autoSavePaymentMethods,
        'p_preferred_wallet': preferredWallet,
        'p_enable_one_click_purchase': enableOneClickPurchase,
        'p_default_payment_type': defaultPaymentType,
      });

      print('💳 [TOKEN_API] Payment preferences updated: $response');

      if (response != null) {
        return prefs.PaymentPreferencesModel.fromJson(
            response as Map<String, dynamic>);
      } else {
        throw const ServerException(
          message: 'Failed to update payment preferences',
          code: 'UPDATE_PREFERENCES_FAILED',
        );
      }
    } on NetworkException {
      rethrow;
    } on ServerException {
      rethrow;
    } on AuthenticationException {
      rethrow;
    } on TokenValidationException {
      throw const AuthenticationException(
        message: 'Authentication token is invalid. Please sign in again.',
        code: 'TOKEN_INVALID',
      );
    } catch (e) {
      print('🚨 [TOKEN_API] Unexpected update payment preferences error: $e');
      throw ClientException(
        message:
            'Unable to update payment preferences. Please try again later.',
        code: 'UPDATE_PREFERENCES_FAILED',
        context: {'originalError': e.toString()},
      );
    }
  }

  @override
  Future<List<TokenUsageHistoryModel>> getUsageHistory({
    int? limit,
    int? offset,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      // Validate token before making authenticated request
      await ApiAuthHelper.validateTokenForRequest();

      // Use unified authentication helper
      final headers = await ApiAuthHelper.getAuthHeaders();

      print('📊 [TOKEN_API] Fetching usage history...');

      // Build query parameters
      final queryParams = <String, String>{
        if (limit != null) 'limit': limit.toString(),
        if (offset != null) 'offset': offset.toString(),
        if (startDate != null) 'start_date': startDate.toIso8601String(),
        if (endDate != null) 'end_date': endDate.toIso8601String(),
      };

      print('📊 [TOKEN_API] Query params: $queryParams');

      // Call token-usage-history Edge Function
      final response = await _supabaseClient.functions.invoke(
        'token-usage-history',
        method: HttpMethod.get,
        headers: headers,
        queryParameters: queryParams,
      );

      print('📊 [TOKEN_API] Usage history response status: ${response.status}');

      if (response.status == 200 && response.data != null) {
        final responseData = response.data as Map<String, dynamic>;

        if (responseData['success'] == true) {
          final data = responseData['data'] as Map<String, dynamic>;
          final historyList = data['history'] as List<dynamic>;

          print('📊 [TOKEN_API] Retrieved ${historyList.length} usage records');

          return historyList
              .map((json) =>
                  TokenUsageHistoryModel.fromJson(json as Map<String, dynamic>))
              .toList();
        } else {
          final error = responseData['error'] as Map<String, dynamic>?;
          throw ServerException(
            message:
                error?['message'] as String? ?? 'Failed to fetch usage history',
            code: error?['code'] as String? ?? 'USAGE_HISTORY_ERROR',
          );
        }
      } else if (response.status == 401) {
        throw const AuthenticationException(
          message: 'Authentication required. Please sign in to continue.',
          code: 'UNAUTHORIZED',
        );
      } else if (response.status >= 500) {
        throw const ServerException(
          message: 'Server error occurred. Please try again later.',
          code: 'SERVER_ERROR',
        );
      } else {
        throw const ServerException(
          message: 'Failed to fetch usage history. Please try again later.',
          code: 'USAGE_HISTORY_ERROR',
        );
      }
    } on NetworkException {
      rethrow;
    } on ServerException {
      rethrow;
    } on AuthenticationException {
      rethrow;
    } on TokenValidationException {
      throw const AuthenticationException(
        message: 'Authentication token is invalid. Please sign in again.',
        code: 'TOKEN_INVALID',
      );
    } catch (e) {
      print('🚨 [TOKEN_API] Unexpected usage history error: $e');
      throw ClientException(
        message: 'Unable to fetch usage history. Please try again later.',
        code: 'USAGE_HISTORY_FAILED',
        context: {'originalError': e.toString()},
      );
    }
  }

  @override
  Future<UsageStatisticsModel> getUsageStatistics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      // Validate token before making authenticated request
      await ApiAuthHelper.validateTokenForRequest();

      // Use unified authentication helper
      final headers = await ApiAuthHelper.getAuthHeaders();

      print('📊 [TOKEN_API] Fetching usage statistics...');

      // Build query parameters
      final queryParams = <String, String>{
        'include_statistics': 'true',
        if (startDate != null) 'start_date': startDate.toIso8601String(),
        if (endDate != null) 'end_date': endDate.toIso8601String(),
      };

      print('📊 [TOKEN_API] Statistics query params: $queryParams');

      // Call token-usage-history Edge Function with statistics flag
      final response = await _supabaseClient.functions.invoke(
        'token-usage-history',
        method: HttpMethod.get,
        headers: headers,
        queryParameters: queryParams,
      );

      print(
          '📊 [TOKEN_API] Usage statistics response status: ${response.status}');

      if (response.status == 200 && response.data != null) {
        final responseData = response.data as Map<String, dynamic>;

        if (responseData['success'] == true) {
          final data = responseData['data'] as Map<String, dynamic>;
          final statisticsData = data['statistics'];

          if (statisticsData != null) {
            print('📊 [TOKEN_API] Statistics retrieved successfully');
            return UsageStatisticsModel.fromJson(
                statisticsData as Map<String, dynamic>);
          } else {
            // Return empty statistics if no data available
            print(
                '📊 [TOKEN_API] No statistics data available, returning empty');
            return UsageStatisticsModel.empty();
          }
        } else {
          final error = responseData['error'] as Map<String, dynamic>?;
          throw ServerException(
            message: error?['message'] as String? ??
                'Failed to fetch usage statistics',
            code: error?['code'] as String? ?? 'USAGE_STATISTICS_ERROR',
          );
        }
      } else if (response.status == 401) {
        throw const AuthenticationException(
          message: 'Authentication required. Please sign in to continue.',
          code: 'UNAUTHORIZED',
        );
      } else if (response.status >= 500) {
        throw const ServerException(
          message: 'Server error occurred. Please try again later.',
          code: 'SERVER_ERROR',
        );
      } else {
        throw const ServerException(
          message: 'Failed to fetch usage statistics. Please try again later.',
          code: 'USAGE_STATISTICS_ERROR',
        );
      }
    } on NetworkException {
      rethrow;
    } on ServerException {
      rethrow;
    } on AuthenticationException {
      rethrow;
    } on TokenValidationException {
      throw const AuthenticationException(
        message: 'Authentication token is invalid. Please sign in again.',
        code: 'TOKEN_INVALID',
      );
    } catch (e) {
      print('🚨 [TOKEN_API] Unexpected usage statistics error: $e');
      throw ClientException(
        message: 'Unable to fetch usage statistics. Please try again later.',
        code: 'USAGE_STATISTICS_FAILED',
        context: {'originalError': e.toString()},
      );
    }
  }

  /// Validates parameters for payment confirmation
  void _validateConfirmPaymentParams(
    String paymentId,
    String orderId,
    String signature,
    int tokenAmount,
  ) {
    if (paymentId.isEmpty || orderId.isEmpty || signature.isEmpty) {
      throw const ClientException(
        message: 'Payment verification details are required',
        code: 'MISSING_PAYMENT_DETAILS',
      );
    }

    if (tokenAmount <= 0) {
      throw const ClientException(
        message: 'Token amount must be greater than zero',
        code: 'INVALID_TOKEN_AMOUNT',
      );
    }
  }

  /// Makes the API call for payment confirmation
  Future<FunctionResponse> _callConfirmPaymentAPI({
    required String paymentId,
    required String orderId,
    required String signature,
    required int tokenAmount,
    required Map<String, String> headers,
  }) async {
    final response = await _supabaseClient.functions.invoke(
      'confirm-token-purchase',
      body: {
        'payment_id': paymentId,
        'order_id': orderId,
        'signature': signature,
        'token_amount': tokenAmount,
      },
      headers: headers,
    );

    print(
        '🪙 [TOKEN_API] Payment confirmation response status: ${response.status}');
    print(
        '🪙 [TOKEN_API] Payment confirmation response data: ${response.data}');

    return response;
  }

  /// Processes the API response for payment confirmation
  TokenStatusModel _processConfirmPaymentResponse(FunctionResponse response) {
    if (response.status == 200 && response.data != null) {
      final responseData = response.data as Map<String, dynamic>;

      if (responseData['success'] == true) {
        // The token data is in the 'token_balance' field, not 'data'
        final tokenData = responseData['token_balance'] as Map<String, dynamic>;
        return TokenStatusModel.fromJson(tokenData);
      } else {
        final error = responseData['error'] as Map<String, dynamic>?;
        throw ServerException(
          message:
              error?['message'] as String? ?? 'Payment confirmation failed',
          code: error?['code'] as String? ?? 'CONFIRMATION_FAILED',
        );
      }
    } else if (response.status == 400) {
      final errorData = response.data as Map<String, dynamic>?;
      final error = errorData?['error'] as Map<String, dynamic>?;
      throw ClientException(
        message: error?['message'] as String? ??
            'Invalid payment confirmation request',
        code: error?['code'] as String? ?? 'INVALID_REQUEST',
      );
    } else if (response.status == 401) {
      throw const AuthenticationException(
        message: 'Authentication required. Please sign in to continue.',
        code: 'UNAUTHORIZED',
      );
    } else if (response.status == 403) {
      throw const ClientException(
        message: 'Payment confirmation is not available for your account type.',
        code: 'CONFIRMATION_NOT_ALLOWED',
      );
    } else if (response.status >= 500) {
      throw const ServerException(
        message:
            'Server error occurred during payment confirmation. Please try again later.',
        code: 'SERVER_ERROR',
      );
    } else {
      throw const ServerException(
        message: 'Payment confirmation failed. Please try again later.',
        code: 'CONFIRMATION_FAILED',
      );
    }
  }
}
