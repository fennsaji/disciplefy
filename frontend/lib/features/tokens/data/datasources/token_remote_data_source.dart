import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/services/api_auth_helper.dart';
import '../models/token_status_model.dart';

/// Abstract contract for remote token operations.
abstract class TokenRemoteDataSource {
  /// Fetches current token status for the authenticated user.
  ///
  /// Throws [NetworkException] if there's a network issue.
  /// Throws [ServerException] if there's a server error.
  /// Throws [AuthenticationException] if authentication fails.
  Future<TokenStatusModel> getTokenStatus();

  /// Purchases additional tokens for standard plan users.
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
  Future<TokenStatusModel> purchaseTokens({
    required int tokenAmount,
    required String paymentOrderId,
    required String paymentId,
    required String signature,
  });
}

/// Implementation of TokenRemoteDataSource using Supabase.
class TokenRemoteDataSourceImpl implements TokenRemoteDataSource {
  /// Supabase client for API calls.
  final SupabaseClient _supabaseClient;

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
  Future<TokenStatusModel> purchaseTokens({
    required int tokenAmount,
    required String paymentOrderId,
    required String paymentId,
    required String signature,
  }) async {
    try {
      // Validate token before making authenticated request
      await ApiAuthHelper.validateTokenForRequest();

      // Use unified authentication helper
      final headers = await ApiAuthHelper.getAuthHeaders();

      print('🪙 [TOKEN_API] Purchasing tokens: $tokenAmount');

      // Validate input parameters
      if (tokenAmount <= 0) {
        throw const ClientException(
          message: 'Token amount must be greater than zero',
          code: 'INVALID_TOKEN_AMOUNT',
        );
      }

      if (paymentOrderId.isEmpty || paymentId.isEmpty || signature.isEmpty) {
        throw const ClientException(
          message: 'Payment verification details are required',
          code: 'MISSING_PAYMENT_DETAILS',
        );
      }

      // Call Supabase Edge Function for token purchase
      final response = await _supabaseClient.functions.invoke(
        'purchase-tokens',
        body: {
          'token_amount': tokenAmount,
          'payment_order_id': paymentOrderId,
          'payment_id': paymentId,
          'signature': signature,
        },
        headers: headers,
      );

      print('🪙 [TOKEN_API] Purchase response status: ${response.status}');
      print('🪙 [TOKEN_API] Purchase response data: ${response.data}');

      if (response.status == 200 && response.data != null) {
        final responseData = response.data as Map<String, dynamic>;

        if (responseData['success'] == true) {
          // Return updated token status after purchase
          final tokenData = responseData['data'] as Map<String, dynamic>;
          return TokenStatusModel.fromJson(tokenData);
        } else {
          final error = responseData['error'] as Map<String, dynamic>?;
          throw ServerException(
            message: error?['message'] as String? ?? 'Token purchase failed',
            code: error?['code'] as String? ?? 'PURCHASE_FAILED',
          );
        }
      } else if (response.status == 400) {
        // Handle validation errors
        final errorData = response.data as Map<String, dynamic>?;
        final error = errorData?['error'] as Map<String, dynamic>?;
        throw ClientException(
          message: error?['message'] as String? ?? 'Invalid purchase request',
          code: error?['code'] as String? ?? 'INVALID_REQUEST',
        );
      } else if (response.status == 401) {
        throw const AuthenticationException(
          message: 'Authentication required. Please sign in to continue.',
          code: 'UNAUTHORIZED',
        );
      } else if (response.status == 403) {
        throw const ClientException(
          message: 'Token purchase is not available for your account type.',
          code: 'PURCHASE_NOT_ALLOWED',
        );
      } else if (response.status >= 500) {
        throw const ServerException(
          message:
              'Server error occurred during purchase. Please try again later.',
          code: 'SERVER_ERROR',
        );
      } else {
        throw const ServerException(
          message: 'Token purchase failed. Please try again later.',
          code: 'PURCHASE_FAILED',
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
      // Convert to AuthenticationException for consistency
      throw const AuthenticationException(
        message: 'Authentication token is invalid. Please sign in again.',
        code: 'TOKEN_INVALID',
      );
    } catch (e) {
      print('🚨 [TOKEN_API] Unexpected purchase error: $e');
      throw ClientException(
        message: 'Unable to complete token purchase. Please try again later.',
        code: 'PURCHASE_FAILED',
        context: {'originalError': e.toString()},
      );
    }
  }
}
