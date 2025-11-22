import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/services/api_auth_helper.dart';
import '../models/subscription_model.dart';
import '../../domain/entities/subscription.dart';

/// Abstract contract for remote subscription operations.
abstract class SubscriptionRemoteDataSource {
  /// Creates a new premium subscription for the authenticated user.
  ///
  /// Creates a Razorpay subscription and returns authorization URL
  /// for the user to complete payment setup.
  ///
  /// Returns [CreateSubscriptionResponseModel] with subscription details and payment URL
  ///
  /// Throws [NetworkException] if there's a network issue.
  /// Throws [ServerException] if there's a server error.
  /// Throws [AuthenticationException] if authentication fails.
  /// Throws [ClientException] if subscription creation fails.
  Future<CreateSubscriptionResponseModel> createSubscription();

  /// Cancels the user's active subscription.
  ///
  /// [cancelAtCycleEnd] - If true, subscription remains active until current period ends.
  ///                      If false, cancels immediately and revokes premium access.
  /// [reason] - Optional cancellation reason for analytics
  ///
  /// Returns [CancelSubscriptionResponseModel] with cancellation details
  ///
  /// Throws [NetworkException] if there's a network issue.
  /// Throws [ServerException] if there's a server error.
  /// Throws [AuthenticationException] if authentication fails.
  /// Throws [ClientException] if cancellation fails or no active subscription found.
  Future<CancelSubscriptionResponseModel> cancelSubscription({
    required bool cancelAtCycleEnd,
    String? reason,
  });

  /// Resumes a cancelled subscription.
  ///
  /// Reactivates a subscription that was cancelled with cancel_at_cycle_end=true
  /// and is still within its billing period.
  ///
  /// Returns [ResumeSubscriptionResponseModel] with resumption details
  ///
  /// Throws [NetworkException] if there's a network issue.
  /// Throws [ServerException] if there's a server error.
  /// Throws [AuthenticationException] if authentication fails.
  /// Throws [ClientException] if resumption fails or subscription cannot be resumed.
  Future<ResumeSubscriptionResponseModel> resumeSubscription();

  /// Gets the user's active subscription.
  ///
  /// Returns active [SubscriptionModel] or null if user has no active subscription.
  ///
  /// Throws [NetworkException] if there's a network issue.
  /// Throws [ServerException] if there's a server error.
  /// Throws [AuthenticationException] if authentication fails.
  Future<SubscriptionModel?> getActiveSubscription();

  /// Gets all subscriptions for the authenticated user (active and historical).
  ///
  /// Returns list of [SubscriptionModel] ordered by creation date (newest first)
  ///
  /// Throws [NetworkException] if there's a network issue.
  /// Throws [ServerException] if there's a server error.
  /// Throws [AuthenticationException] if authentication fails.
  Future<List<SubscriptionModel>> getSubscriptionHistory();

  /// Gets subscription invoices for the authenticated user.
  ///
  /// [limit] - Maximum number of invoices to return (optional)
  /// [offset] - Number of invoices to skip for pagination (optional)
  ///
  /// Returns list of subscription invoices
  ///
  /// Throws [NetworkException] if there's a network issue.
  /// Throws [ServerException] if there's a server error.
  /// Throws [AuthenticationException] if authentication fails.
  Future<List<SubscriptionInvoiceModel>> getInvoices({
    int? limit,
    int? offset,
  });
}

/// Implementation of SubscriptionRemoteDataSource using Supabase.
class SubscriptionRemoteDataSourceImpl implements SubscriptionRemoteDataSource {
  /// Supabase client for API calls.
  final SupabaseClient _supabaseClient;

  /// Creates a new SubscriptionRemoteDataSourceImpl instance.
  SubscriptionRemoteDataSourceImpl({
    required SupabaseClient supabaseClient,
  }) : _supabaseClient = supabaseClient;

  @override
  Future<CreateSubscriptionResponseModel> createSubscription() async {
    try {
      // Validate token before making authenticated request
      await ApiAuthHelper.validateTokenForRequest();

      // Use unified authentication helper
      final headers = await ApiAuthHelper.getAuthHeaders();

      print('💎 [SUBSCRIPTION_API] Creating premium subscription...');

      // Call Supabase Edge Function for subscription creation
      final response = await _supabaseClient.functions.invoke(
        'create-subscription',
        headers: headers,
      );

      print('💎 [SUBSCRIPTION_API] Response status: ${response.status}');
      print('💎 [SUBSCRIPTION_API] Response data: ${response.data}');

      if (response.status == 201 && response.data != null) {
        final responseData = response.data as Map<String, dynamic>;

        if (responseData['success'] == true) {
          return CreateSubscriptionResponseModel.fromJson(responseData);
        } else {
          final error = responseData['error'] as Map<String, dynamic>?;
          throw ServerException(
            message:
                error?['message'] as String? ?? 'Failed to create subscription',
            code: error?['code'] as String? ?? 'SUBSCRIPTION_CREATION_FAILED',
          );
        }
      } else if (response.status == 400) {
        final errorData = response.data as Map<String, dynamic>?;
        final error = errorData?['error'] as Map<String, dynamic>?;
        final errorCode = error?['code'] as String?;

        // Handle specific error cases
        if (errorCode == 'ALREADY_PREMIUM') {
          throw const ClientException(
            message: 'You already have premium access',
            code: 'ALREADY_PREMIUM',
          );
        }

        throw ClientException(
          message:
              error?['message'] as String? ?? 'Invalid subscription request',
          code: errorCode ?? 'INVALID_REQUEST',
        );
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
          message: 'Failed to create subscription. Please try again later.',
          code: 'SUBSCRIPTION_CREATION_FAILED',
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
      print('🚨 [SUBSCRIPTION_API] Unexpected error: $e');
      throw ClientException(
        message: 'Unable to create subscription. Please try again later.',
        code: 'SUBSCRIPTION_CREATION_FAILED',
        context: {'originalError': e.toString()},
      );
    }
  }

  @override
  Future<CancelSubscriptionResponseModel> cancelSubscription({
    required bool cancelAtCycleEnd,
    String? reason,
  }) async {
    try {
      // Validate token before making authenticated request
      await ApiAuthHelper.validateTokenForRequest();

      // Use unified authentication helper
      final headers = await ApiAuthHelper.getAuthHeaders();

      print(
          '💎 [SUBSCRIPTION_API] Cancelling subscription (cancel_at_cycle_end: $cancelAtCycleEnd)...');

      // Call Supabase Edge Function for subscription cancellation
      final response = await _supabaseClient.functions.invoke(
        'cancel-subscription',
        body: {
          'cancel_at_cycle_end': cancelAtCycleEnd,
          if (reason != null) 'reason': reason,
        },
        headers: headers,
      );

      print('💎 [SUBSCRIPTION_API] Response status: ${response.status}');
      print('💎 [SUBSCRIPTION_API] Response data: ${response.data}');

      if (response.status == 200 && response.data != null) {
        final responseData = response.data as Map<String, dynamic>;

        if (responseData['success'] == true) {
          return CancelSubscriptionResponseModel.fromJson(responseData);
        } else {
          final error = responseData['error'] as Map<String, dynamic>?;
          throw ServerException(
            message:
                error?['message'] as String? ?? 'Failed to cancel subscription',
            code: error?['code'] as String? ?? 'CANCELLATION_FAILED',
          );
        }
      } else if (response.status == 404) {
        throw const ClientException(
          message: 'No active subscription found to cancel',
          code: 'SUBSCRIPTION_NOT_FOUND',
        );
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
          message: 'Failed to cancel subscription. Please try again later.',
          code: 'CANCELLATION_FAILED',
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
      print('🚨 [SUBSCRIPTION_API] Unexpected cancellation error: $e');
      throw ClientException(
        message: 'Unable to cancel subscription. Please try again later.',
        code: 'CANCELLATION_FAILED',
        context: {'originalError': e.toString()},
      );
    }
  }

  @override
  Future<ResumeSubscriptionResponseModel> resumeSubscription() async {
    try {
      // Validate token before making authenticated request
      await ApiAuthHelper.validateTokenForRequest();

      // Use unified authentication helper
      final headers = await ApiAuthHelper.getAuthHeaders();

      print('💎 [SUBSCRIPTION_API] Resuming cancelled subscription...');

      // Call Supabase Edge Function for subscription resumption
      final response = await _supabaseClient.functions.invoke(
        'resume-subscription',
        headers: headers,
      );

      print('💎 [SUBSCRIPTION_API] Response status: ${response.status}');
      print('💎 [SUBSCRIPTION_API] Response data: ${response.data}');

      if (response.status == 200 && response.data != null) {
        final responseData = response.data as Map<String, dynamic>;

        if (responseData['success'] == true) {
          return ResumeSubscriptionResponseModel.fromJson(responseData);
        } else {
          final error = responseData['error'] as Map<String, dynamic>?;
          throw ServerException(
            message:
                error?['message'] as String? ?? 'Failed to resume subscription',
            code: error?['code'] as String? ?? 'RESUME_FAILED',
          );
        }
      } else if (response.status == 404) {
        throw const ClientException(
          message: 'No cancelled subscription found to resume',
          code: 'SUBSCRIPTION_NOT_FOUND',
        );
      } else if (response.status == 400) {
        final errorData = response.data as Map<String, dynamic>?;
        final error = errorData?['error'] as Map<String, dynamic>?;
        throw ClientException(
          message: error?['message'] as String? ?? 'Cannot resume subscription',
          code: error?['code'] as String? ?? 'INVALID_REQUEST',
        );
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
          message: 'Failed to resume subscription. Please try again later.',
          code: 'RESUME_FAILED',
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
      print('🚨 [SUBSCRIPTION_API] Unexpected resume error: $e');
      throw ClientException(
        message: 'Unable to resume subscription. Please try again later.',
        code: 'RESUME_FAILED',
        context: {'originalError': e.toString()},
      );
    }
  }

  @override
  Future<SubscriptionModel?> getActiveSubscription() async {
    try {
      // Validate token before making authenticated request
      await ApiAuthHelper.validateTokenForRequest();

      print('💎 [SUBSCRIPTION_API] Fetching active subscription...');

      // Get current user ID
      final user = _supabaseClient.auth.currentUser;
      if (user == null) {
        throw const AuthenticationException(
          message: 'User not authenticated',
          code: 'USER_NOT_AUTHENTICATED',
        );
      }

      // Query subscriptions table for active subscription
      // Include 'cancelled' status to handle subscriptions that are cancelled
      // but still active until the end of the billing period
      final response = await _supabaseClient
          .from('subscriptions')
          .select()
          .eq('user_id', user.id)
          .inFilter('status', ['active', 'authenticated', 'cancelled'])
          .order('created_at', ascending: false)
          .maybeSingle();

      print('💎 [SUBSCRIPTION_API] Active subscription response: $response');

      if (response != null) {
        final subscription = SubscriptionModel.fromJson(response);

        // For cancelled subscriptions, check if they're still active
        if (subscription.status == SubscriptionStatus.cancelled) {
          if (subscription.cancelAtCycleEnd &&
              subscription.currentPeriodEnd != null) {
            final periodEnd = subscription.currentPeriodEnd!;
            final now = DateTime.now();

            // Only return if still within the active period
            if (periodEnd.isAfter(now)) {
              print(
                  '💎 [SUBSCRIPTION_API] Cancelled subscription still active until $periodEnd');
              return subscription;
            } else {
              print('💎 [SUBSCRIPTION_API] Cancelled subscription has expired');
              return null;
            }
          } else {
            // Immediate cancellation - not active
            print(
                '💎 [SUBSCRIPTION_API] Subscription was cancelled immediately');
            return null;
          }
        }

        return subscription;
      } else {
        return null; // No active subscription
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
      print(
          '🚨 [SUBSCRIPTION_API] Unexpected error getting active subscription: $e');
      throw ClientException(
        message: 'Unable to fetch subscription status. Please try again later.',
        code: 'GET_SUBSCRIPTION_FAILED',
        context: {'originalError': e.toString()},
      );
    }
  }

  @override
  Future<List<SubscriptionModel>> getSubscriptionHistory() async {
    try {
      // Validate token before making authenticated request
      await ApiAuthHelper.validateTokenForRequest();

      print('💎 [SUBSCRIPTION_API] Fetching subscription history...');

      // Get current user ID
      final user = _supabaseClient.auth.currentUser;
      if (user == null) {
        throw const AuthenticationException(
          message: 'User not authenticated',
          code: 'USER_NOT_AUTHENTICATED',
        );
      }

      // Query subscriptions table for all user subscriptions
      final response = await _supabaseClient
          .from('subscriptions')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      print(
          '💎 [SUBSCRIPTION_API] Subscription history response: ${response.length} subscriptions');

      return response.map((json) => SubscriptionModel.fromJson(json)).toList();
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
      print(
          '🚨 [SUBSCRIPTION_API] Unexpected error getting subscription history: $e');
      throw ClientException(
        message:
            'Unable to fetch subscription history. Please try again later.',
        code: 'GET_HISTORY_FAILED',
        context: {'originalError': e.toString()},
      );
    }
  }

  @override
  Future<List<SubscriptionInvoiceModel>> getInvoices({
    int? limit,
    int? offset,
  }) async {
    try {
      // Validate token before making authenticated request
      await ApiAuthHelper.validateTokenForRequest();

      print('💎 [SUBSCRIPTION_API] Fetching subscription invoices...');

      // Get current user ID
      final user = _supabaseClient.auth.currentUser;
      if (user == null) {
        throw const AuthenticationException(
          message: 'User not authenticated',
          code: 'USER_NOT_AUTHENTICATED',
        );
      }

      // Query subscription_invoices table
      var query = _supabaseClient
          .from('subscription_invoices')
          .select()
          .eq('user_id', user.id)
          .order('paid_at', ascending: false);

      // Apply pagination if specified
      if (offset != null || limit != null) {
        final startRange = offset ?? 0;
        final endRange = startRange + (limit ?? 50) - 1;
        query = query.range(startRange, endRange);

        print(
            '🔍 [SUBSCRIPTION_API] Using pagination range: $startRange to $endRange');
      }

      final response = await query;

      print(
          '💎 [SUBSCRIPTION_API] Invoices response: ${response.length} invoices');

      return response
          .map((json) => SubscriptionInvoiceModel.fromJson(json))
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
      print('🚨 [SUBSCRIPTION_API] Unexpected error getting invoices: $e');
      throw ClientException(
        message: 'Unable to fetch invoices. Please try again later.',
        code: 'GET_INVOICES_FAILED',
        context: {'originalError': e.toString()},
      );
    }
  }
}
