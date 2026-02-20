import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/services/api_auth_helper.dart';
import '../models/subscription_model.dart';
import '../models/subscription_v2_models.dart';
import '../../domain/entities/subscription.dart';
import '../../domain/entities/user_subscription_status.dart';
import '../../../../core/utils/logger.dart';

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

  /// Gets the user's subscription status including trial information.
  ///
  /// Returns [UserSubscriptionStatus] with current plan, trial status,
  /// and subscription details.
  ///
  /// Throws [NetworkException] if there's a network issue.
  /// Throws [ServerException] if there's a server error.
  /// Throws [AuthenticationException] if authentication fails.
  Future<UserSubscriptionStatus> getSubscriptionStatus();

  /// Creates a new Standard subscription for the authenticated user.
  ///
  /// Creates a Razorpay subscription for Standard plan (₹79/month)
  /// and returns authorization URL for the user to complete payment setup.
  ///
  /// Returns [CreateSubscriptionResponseModel] with subscription details and payment URL
  ///
  /// Throws [NetworkException] if there's a network issue.
  /// Throws [ServerException] if there's a server error.
  /// Throws [AuthenticationException] if authentication fails.
  /// Throws [ClientException] if trial is still active or subscription exists.
  Future<CreateSubscriptionResponseModel> createStandardSubscription();

  /// Creates a new Plus subscription (₹149/month) for the authenticated user.
  ///
  /// Returns [CreateSubscriptionResponseModel] with subscription details and payment URL
  ///
  /// Throws [NetworkException] if there's a network issue.
  /// Throws [ServerException] if there's a server error.
  /// Throws [AuthenticationException] if authentication fails.
  /// Throws [ClientException] if user already has Premium or Plus subscription.
  Future<CreateSubscriptionResponseModel> createPlusSubscription();

  /// Starts a 7-day Premium trial for eligible users.
  ///
  /// Returns [StartPremiumTrialResponseModel] with trial details
  ///
  /// Throws [NetworkException] if there's a network issue.
  /// Throws [ServerException] if there's a server error.
  /// Throws [AuthenticationException] if authentication fails.
  /// Throws [ClientException] if user is not eligible for trial.
  Future<StartPremiumTrialResponseModel> startPremiumTrial();

  /// Gets available subscription plans with provider-specific pricing.
  ///
  /// [provider] - Payment provider ('razorpay', 'google_play', 'apple_appstore')
  /// [region] - Region code (default: 'IN')
  /// [promoCode] - Optional promotional code to apply discount
  ///
  /// Returns list of available plans with pricing and optional promo details
  ///
  /// Throws [NetworkException] if there's a network issue.
  /// Throws [ServerException] if there's a server error.
  /// Throws [ClientException] if provider is invalid.
  Future<GetPlansResponseModel> getPlans({
    required String provider,
    String? region,
    String? promoCode,
    String? locale,
  });

  /// Validates a promotional code.
  ///
  /// [promoCode] - Promotional code to validate
  /// [planCode] - Optional plan code to check applicability
  /// [provider] - Optional payment provider (default: 'razorpay')
  ///
  /// Returns validation result with campaign details if valid
  ///
  /// Throws [NetworkException] if there's a network issue.
  /// Throws [ServerException] if there's a server error.
  /// Throws [AuthenticationException] if authentication fails.
  Future<ValidatePromoCodeResponseModel> validatePromoCode({
    required String promoCode,
    String? planCode,
    String? provider,
  });

  /// Creates a generic subscription supporting multiple payment providers.
  ///
  /// [planCode] - Plan identifier ('standard', 'plus', 'premium')
  /// [provider] - Payment provider ('razorpay', 'google_play', 'apple_appstore')
  /// [region] - Region code (default: 'IN')
  /// [promoCode] - Optional promotional code
  /// [receipt] - Purchase receipt for IAP (required for Google Play/Apple)
  ///
  /// Returns subscription details with authorization URL (Razorpay) or immediate activation (IAP)
  ///
  /// Throws [NetworkException] if there's a network issue.
  /// Throws [ServerException] if there's a server error.
  /// Throws [AuthenticationException] if authentication fails.
  /// Throws [ClientException] if subscription creation fails.
  Future<CreateSubscriptionV2ResponseModel> createSubscriptionV2({
    required String planCode,
    required String provider,
    String? region,
    String? promoCode,
    String? receipt,
  });
}

/// Response model for starting a Premium trial
class StartPremiumTrialResponseModel {
  final DateTime trialStartedAt;
  final DateTime trialEndAt;
  final int daysRemaining;
  final String message;

  const StartPremiumTrialResponseModel({
    required this.trialStartedAt,
    required this.trialEndAt,
    required this.daysRemaining,
    required this.message,
  });

  factory StartPremiumTrialResponseModel.fromJson(Map<String, dynamic> json) {
    return StartPremiumTrialResponseModel(
      trialStartedAt: DateTime.parse(json['trial_started_at'] as String),
      trialEndAt: DateTime.parse(json['trial_end_at'] as String),
      daysRemaining: json['days_remaining'] as int,
      message: json['message'] as String,
    );
  }
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

      Logger.debug('💎 [SUBSCRIPTION_API] Creating premium subscription...');

      // Call Supabase Edge Function for subscription creation
      final response = await _supabaseClient.functions.invoke(
        'create-subscription',
        headers: headers,
      );

      Logger.info('💎 [SUBSCRIPTION_API] Response status: ${response.status}');
      Logger.debug('💎 [SUBSCRIPTION_API] Response data: ${response.data}');

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
      Logger.error('🚨 [SUBSCRIPTION_API] Unexpected error: $e');
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

      Logger.debug(
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

      Logger.info('💎 [SUBSCRIPTION_API] Response status: ${response.status}');
      Logger.debug('💎 [SUBSCRIPTION_API] Response data: ${response.data}');

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
      Logger.error('🚨 [SUBSCRIPTION_API] Unexpected cancellation error: $e');
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

      Logger.debug('💎 [SUBSCRIPTION_API] Resuming cancelled subscription...');

      // Call Supabase Edge Function for subscription resumption
      final response = await _supabaseClient.functions.invoke(
        'resume-subscription',
        headers: headers,
      );

      Logger.info('💎 [SUBSCRIPTION_API] Response status: ${response.status}');
      Logger.debug('💎 [SUBSCRIPTION_API] Response data: ${response.data}');

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
      Logger.error('🚨 [SUBSCRIPTION_API] Unexpected resume error: $e');
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

      Logger.debug('💎 [SUBSCRIPTION_API] Fetching active subscription...');

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
      // Use .limit(1) to ensure only one row is returned when multiple exist
      final response = await _supabaseClient
          .from('subscriptions')
          .select()
          .eq('user_id', user.id)
          .inFilter('status', ['active', 'authenticated', 'cancelled'])
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      Logger.debug(
          '💎 [SUBSCRIPTION_API] Active subscription response: $response');

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
              Logger.debug(
                  '💎 [SUBSCRIPTION_API] Cancelled subscription still active until $periodEnd');
              return subscription;
            } else {
              Logger.debug(
                  '💎 [SUBSCRIPTION_API] Cancelled subscription has expired');
              return null;
            }
          } else {
            // Immediate cancellation - not active
            Logger.debug(
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
      Logger.error(
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

      Logger.debug('💎 [SUBSCRIPTION_API] Fetching subscription history...');

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

      Logger.debug(
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
      Logger.error(
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

      Logger.debug('💎 [SUBSCRIPTION_API] Fetching subscription invoices...');

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

        Logger.debug(
            '🔍 [SUBSCRIPTION_API] Using pagination range: $startRange to $endRange');
      }

      final response = await query;

      Logger.debug(
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
      Logger.error(
          '🚨 [SUBSCRIPTION_API] Unexpected error getting invoices: $e');
      throw ClientException(
        message: 'Unable to fetch invoices. Please try again later.',
        code: 'GET_INVOICES_FAILED',
        context: {'originalError': e.toString()},
      );
    }
  }

  @override
  Future<UserSubscriptionStatus> getSubscriptionStatus() async {
    try {
      Logger.debug('💎 [SUBSCRIPTION_API] Fetching subscription status...');

      // Get current user ID
      final user = _supabaseClient.auth.currentUser;
      if (user == null) {
        // Return default status for unauthenticated users
        Logger.debug(
            '💎 [SUBSCRIPTION_API] User not authenticated, returning default status');
        return UserSubscriptionStatus.defaultStatus();
      }

      // Call the get_subscription_status RPC function
      final response = await _supabaseClient.rpc(
        'get_subscription_status',
        params: {'p_user_id': user.id},
      );

      Logger.debug(
          '💎 [SUBSCRIPTION_API] Subscription status response: $response');

      if (response != null) {
        return UserSubscriptionStatus.fromJson(
            response as Map<String, dynamic>);
      } else {
        return UserSubscriptionStatus.defaultStatus();
      }
    } on NetworkException {
      rethrow;
    } on ServerException {
      rethrow;
    } on AuthenticationException {
      rethrow;
    } catch (e) {
      Logger.error(
          '🚨 [SUBSCRIPTION_API] Unexpected error getting subscription status: $e');
      // Return default status on error instead of throwing
      return UserSubscriptionStatus.defaultStatus();
    }
  }

  @override
  Future<CreateSubscriptionResponseModel> createStandardSubscription() async {
    try {
      // Validate token before making authenticated request
      await ApiAuthHelper.validateTokenForRequest();

      // Use unified authentication helper
      final headers = await ApiAuthHelper.getAuthHeaders();

      Logger.debug('💎 [SUBSCRIPTION_API] Creating Standard subscription...');

      // Call Supabase Edge Function for Standard subscription creation
      final response = await _supabaseClient.functions.invoke(
        'create-standard-subscription',
        headers: headers,
      );

      Logger.info('💎 [SUBSCRIPTION_API] Response status: ${response.status}');
      Logger.debug('💎 [SUBSCRIPTION_API] Response data: ${response.data}');

      if (response.status == 201 && response.data != null) {
        final responseData = response.data as Map<String, dynamic>;

        if (responseData['success'] == true) {
          return CreateSubscriptionResponseModel.fromJson(responseData);
        } else {
          final error = responseData['error'] as Map<String, dynamic>?;
          throw ServerException(
            message: error?['message'] as String? ??
                'Failed to create Standard subscription',
            code: error?['code'] as String? ?? 'SUBSCRIPTION_CREATION_FAILED',
          );
        }
      } else if (response.status == 400) {
        final errorData = response.data as Map<String, dynamic>?;
        final error = errorData?['error'] as Map<String, dynamic>?;
        final errorCode = error?['code'] as String?;

        // Handle specific error cases
        if (errorCode == 'TRIAL_STILL_ACTIVE') {
          throw ClientException(
            message: error?['message'] as String? ??
                'Standard plan is currently free during trial period',
            code: 'TRIAL_STILL_ACTIVE',
          );
        }
        if (errorCode == 'ALREADY_PREMIUM') {
          throw const ClientException(
            message: 'You already have Premium access',
            code: 'ALREADY_PREMIUM',
          );
        }
        if (errorCode == 'SUBSCRIPTION_EXISTS') {
          throw const ClientException(
            message: 'You already have an active Standard subscription',
            code: 'SUBSCRIPTION_EXISTS',
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
          message:
              'Failed to create Standard subscription. Please try again later.',
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
      Logger.error(
          '🚨 [SUBSCRIPTION_API] Unexpected error creating Standard subscription: $e');
      throw ClientException(
        message:
            'Unable to create Standard subscription. Please try again later.',
        code: 'SUBSCRIPTION_CREATION_FAILED',
        context: {'originalError': e.toString()},
      );
    }
  }

  @override
  Future<CreateSubscriptionResponseModel> createPlusSubscription() async {
    try {
      // Validate token before making authenticated request
      await ApiAuthHelper.validateTokenForRequest();

      // Use unified authentication helper
      final headers = await ApiAuthHelper.getAuthHeaders();

      Logger.debug('💎 [SUBSCRIPTION_API] Creating Plus subscription...');

      // Call Supabase Edge Function for Plus subscription creation
      final response = await _supabaseClient.functions.invoke(
        'create-plus-subscription',
        headers: headers,
      );

      Logger.info('💎 [SUBSCRIPTION_API] Response status: ${response.status}');
      Logger.debug('💎 [SUBSCRIPTION_API] Response data: ${response.data}');

      if (response.status == 201 && response.data != null) {
        final responseData = response.data as Map<String, dynamic>;

        if (responseData['success'] == true) {
          return CreateSubscriptionResponseModel.fromJson(responseData);
        } else {
          final error = responseData['error'] as Map<String, dynamic>?;
          throw ServerException(
            message: error?['message'] as String? ??
                'Failed to create Plus subscription',
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
            message: 'You already have Premium access',
            code: 'ALREADY_PREMIUM',
          );
        }
        if (errorCode == 'SUBSCRIPTION_EXISTS') {
          throw const ClientException(
            message: 'You already have an active Plus subscription',
            code: 'SUBSCRIPTION_EXISTS',
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
          message:
              'Failed to create Plus subscription. Please try again later.',
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
      Logger.error(
          '🚨 [SUBSCRIPTION_API] Unexpected error creating Plus subscription: $e');
      throw ClientException(
        message: 'Unable to create Plus subscription. Please try again later.',
        code: 'SUBSCRIPTION_CREATION_FAILED',
        context: {'originalError': e.toString()},
      );
    }
  }

  @override
  Future<StartPremiumTrialResponseModel> startPremiumTrial() async {
    try {
      // Validate token before making authenticated request
      await ApiAuthHelper.validateTokenForRequest();

      // Use unified authentication helper
      final headers = await ApiAuthHelper.getAuthHeaders();

      Logger.debug('💎 [SUBSCRIPTION_API] Starting Premium trial...');

      // Call Supabase Edge Function for Premium trial
      final response = await _supabaseClient.functions.invoke(
        'start-premium-trial',
        headers: headers,
      );

      Logger.info('💎 [SUBSCRIPTION_API] Response status: ${response.status}');
      Logger.debug('💎 [SUBSCRIPTION_API] Response data: ${response.data}');

      if (response.status == 201 && response.data != null) {
        final responseData = response.data as Map<String, dynamic>;

        if (responseData['success'] == true) {
          return StartPremiumTrialResponseModel.fromJson(responseData);
        } else {
          final error = responseData['error'] as Map<String, dynamic>?;
          throw ServerException(
            message:
                error?['message'] as String? ?? 'Failed to start Premium trial',
            code: error?['code'] as String? ?? 'TRIAL_START_FAILED',
          );
        }
      } else if (response.status == 400) {
        final errorData = response.data as Map<String, dynamic>?;
        final error = errorData?['error'] as Map<String, dynamic>?;
        final errorCode = error?['code'] as String?;

        // Handle specific error cases
        if (errorCode == 'TRIAL_NOT_AVAILABLE') {
          throw ClientException(
            message: error?['message'] as String? ??
                'Premium trial is not available yet',
            code: 'TRIAL_NOT_AVAILABLE',
          );
        }
        if (errorCode == 'ALREADY_PREMIUM') {
          throw const ClientException(
            message: 'You already have Premium access',
            code: 'ALREADY_PREMIUM',
          );
        }
        if (errorCode == 'TRIAL_ALREADY_USED') {
          throw const ClientException(
            message: 'You have already used your Premium trial',
            code: 'TRIAL_ALREADY_USED',
          );
        }
        if (errorCode == 'TRIAL_ALREADY_ACTIVE') {
          throw const ClientException(
            message: 'You already have an active Premium trial',
            code: 'TRIAL_ALREADY_ACTIVE',
          );
        }
        if (errorCode == 'NOT_ELIGIBLE') {
          throw ClientException(
            message: error?['message'] as String? ??
                'You are not eligible for the Premium trial',
            code: 'NOT_ELIGIBLE',
          );
        }

        throw ClientException(
          message: error?['message'] as String? ?? 'Invalid trial request',
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
          message: 'Failed to start Premium trial. Please try again later.',
          code: 'TRIAL_START_FAILED',
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
      Logger.error(
          '🚨 [SUBSCRIPTION_API] Unexpected error starting Premium trial: $e');
      throw ClientException(
        message: 'Unable to start Premium trial. Please try again later.',
        code: 'TRIAL_START_FAILED',
        context: {'originalError': e.toString()},
      );
    }
  }

  @override
  Future<GetPlansResponseModel> getPlans({
    required String provider,
    String? region,
    String? promoCode,
    String? locale,
  }) async {
    try {
      Logger.debug(
          '💎 [SUBSCRIPTION_API] Fetching plans for provider: $provider, region: $region, promo: $promoCode, locale: $locale');

      // Build query parameters
      final queryParams = {
        'provider': provider,
        if (region != null) 'region': region,
        if (promoCode != null) 'promo_code': promoCode,
        if (locale != null) 'locale': locale,
      };

      // Call Supabase Edge Function
      final response = await _supabaseClient.functions.invoke(
        'get-plans',
        queryParameters: queryParams,
      );

      Logger.info('💎 [SUBSCRIPTION_API] Response status: ${response.status}');
      Logger.debug('💎 [SUBSCRIPTION_API] Response data: ${response.data}');

      if (response.status == 200 && response.data != null) {
        final responseData = response.data as Map<String, dynamic>;

        if (responseData['success'] == true) {
          return GetPlansResponseModel.fromJson(responseData);
        } else {
          throw ServerException(
            message:
                responseData['error'] as String? ?? 'Failed to fetch plans',
            code: 'PLANS_FETCH_FAILED',
          );
        }
      } else if (response.status == 400) {
        throw const ClientException(
          message: 'Invalid provider or parameters',
          code: 'INVALID_PARAMETERS',
        );
      } else if (response.status >= 500) {
        throw const ServerException(
          message: 'Server error occurred. Please try again later.',
          code: 'SERVER_ERROR',
        );
      } else {
        throw const ServerException(
          message: 'Failed to fetch plans. Please try again later.',
          code: 'PLANS_FETCH_FAILED',
        );
      }
    } on NetworkException {
      rethrow;
    } on ServerException {
      rethrow;
    } on ClientException {
      rethrow;
    } catch (e) {
      Logger.error('🚨 [SUBSCRIPTION_API] Unexpected error fetching plans: $e');
      throw ClientException(
        message: 'Unable to fetch subscription plans. Please try again later.',
        code: 'PLANS_FETCH_FAILED',
        context: {'originalError': e.toString()},
      );
    }
  }

  @override
  Future<ValidatePromoCodeResponseModel> validatePromoCode({
    required String promoCode,
    String? planCode,
    String? provider,
  }) async {
    try {
      // Validate token before making authenticated request
      await ApiAuthHelper.validateTokenForRequest();

      // Use unified authentication helper
      final headers = await ApiAuthHelper.getAuthHeaders();

      Logger.debug('💎 [SUBSCRIPTION_API] Validating promo code: $promoCode');

      // Call Supabase Edge Function
      final response = await _supabaseClient.functions.invoke(
        'validate-promo-code',
        body: {
          'promo_code': promoCode,
          if (planCode != null) 'plan_code': planCode,
          if (provider != null) 'provider': provider,
        },
        headers: headers,
      );

      Logger.info('💎 [SUBSCRIPTION_API] Response status: ${response.status}');
      Logger.debug('💎 [SUBSCRIPTION_API] Response data: ${response.data}');

      if (response.status == 200 && response.data != null) {
        return ValidatePromoCodeResponseModel.fromJson(
            response.data as Map<String, dynamic>);
      } else if (response.status == 400) {
        throw const ClientException(
          message: 'Invalid promo code or parameters',
          code: 'INVALID_PROMO_CODE',
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
          message: 'Failed to validate promo code. Please try again later.',
          code: 'PROMO_VALIDATION_FAILED',
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
      Logger.error(
          '🚨 [SUBSCRIPTION_API] Unexpected error validating promo code: $e');
      throw ClientException(
        message: 'Unable to validate promo code. Please try again later.',
        code: 'PROMO_VALIDATION_FAILED',
        context: {'originalError': e.toString()},
      );
    }
  }

  @override
  Future<CreateSubscriptionV2ResponseModel> createSubscriptionV2({
    required String planCode,
    required String provider,
    String? region,
    String? promoCode,
    String? receipt,
  }) async {
    try {
      // Validate token before making authenticated request
      await ApiAuthHelper.validateTokenForRequest();

      // Use unified authentication helper
      final headers = await ApiAuthHelper.getAuthHeaders();

      Logger.debug(
          '💎 [SUBSCRIPTION_API] Creating subscription V2 - plan: $planCode, provider: $provider');

      // Call Supabase Edge Function
      final response = await _supabaseClient.functions.invoke(
        'create-subscription-v2',
        body: {
          'plan_code': planCode,
          'provider': provider,
          if (region != null) 'region': region,
          if (promoCode != null) 'promo_code': promoCode,
          if (receipt != null) 'receipt': receipt,
        },
        headers: headers,
      );

      Logger.info('💎 [SUBSCRIPTION_API] Response status: ${response.status}');
      Logger.debug('💎 [SUBSCRIPTION_API] Response data: ${response.data}');

      if (response.status == 201 && response.data != null) {
        final responseData = response.data as Map<String, dynamic>;

        if (responseData['success'] == true) {
          return CreateSubscriptionV2ResponseModel.fromJson(responseData);
        } else {
          final error = responseData['error'] as String?;
          final code = responseData['code'] as String?;
          throw ServerException(
            message: error ?? 'Failed to create subscription',
            code: code ?? 'SUBSCRIPTION_CREATION_FAILED',
          );
        }
      } else if (response.status == 400) {
        final errorData = response.data as Map<String, dynamic>?;
        final error = errorData?['error'] as String?;
        final code = errorData?['code'] as String?;

        // Handle specific error cases
        if (code == 'ALREADY_SUBSCRIBED') {
          throw ClientException(
            message: error ?? 'You already have an active subscription',
            code: 'ALREADY_SUBSCRIBED',
          );
        }
        if (code == 'INVALID_RECEIPT') {
          throw ClientException(
            message: error ?? 'Invalid purchase receipt',
            code: 'INVALID_RECEIPT',
          );
        }

        throw ClientException(
          message: error ?? 'Invalid subscription request',
          code: code ?? 'INVALID_REQUEST',
        );
      } else if (response.status == 401) {
        throw const AuthenticationException(
          message: 'Authentication required. Please sign in to continue.',
          code: 'UNAUTHORIZED',
        );
      } else if (response.status == 404) {
        throw const ClientException(
          message: 'Plan not found or not available for this provider/region',
          code: 'PLAN_NOT_FOUND',
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
      Logger.error(
          '🚨 [SUBSCRIPTION_API] Unexpected error creating subscription V2: $e');
      throw ClientException(
        message: 'Unable to create subscription. Please try again later.',
        code: 'SUBSCRIPTION_CREATION_FAILED',
        context: {'originalError': e.toString()},
      );
    }
  }
}
