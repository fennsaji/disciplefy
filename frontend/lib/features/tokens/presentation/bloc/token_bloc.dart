import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';

import '../../domain/entities/token_status.dart';
import '../../domain/entities/purchase_history.dart';
import '../../domain/entities/purchase_statistics.dart';
import '../../domain/entities/payment_order_response.dart';
import '../../domain/usecases/get_token_status.dart' as get_token_status;
import '../../domain/usecases/create_payment_order.dart'
    as create_payment_order;
import '../../domain/usecases/confirm_payment.dart' as confirm_payment;
import '../../domain/usecases/get_purchase_history.dart'
    as get_purchase_history;
import '../../domain/usecases/get_purchase_statistics.dart'
    as get_purchase_statistics;
import '../../../../core/error/failures.dart' as failures;
import '../../../../core/error/token_failures.dart';
import '../../../../core/error/cache_failure.dart';
import '../../../../core/usecases/usecase.dart';

import 'token_event.dart';
import 'token_state.dart';

/// Token BLoC
///
/// Manages all token-related state and operations including:
/// - Fetching and caching token status
/// - Handling token purchases with Razorpay
/// - Managing token consumption tracking
/// - Plan upgrades and validations
/// - Real-time token balance updates
class TokenBloc extends Bloc<TokenEvent, TokenState> {
  final get_token_status.GetTokenStatus _getTokenStatus;
  final create_payment_order.CreatePaymentOrder _createPaymentOrder;
  final confirm_payment.ConfirmPayment _confirmPayment;
  final get_purchase_history.GetPurchaseHistory _getPurchaseHistory;
  final get_purchase_statistics.GetPurchaseStatistics _getPurchaseStatistics;

  // Token status cache with timestamp
  TokenStatus? _cachedTokenStatus;
  DateTime? _lastCacheUpdate;
  Timer? _refreshTimer;

  static const Duration _cacheValidityDuration = Duration(minutes: 5);
  static const Duration _autoRefreshInterval = Duration(minutes: 10);

  TokenBloc({
    required get_token_status.GetTokenStatus getTokenStatus,
    required create_payment_order.CreatePaymentOrder createPaymentOrder,
    required confirm_payment.ConfirmPayment confirmPayment,
    required get_purchase_history.GetPurchaseHistory getPurchaseHistory,
    required get_purchase_statistics.GetPurchaseStatistics
        getPurchaseStatistics,
  })  : _getTokenStatus = getTokenStatus,
        _createPaymentOrder = createPaymentOrder,
        _confirmPayment = confirmPayment,
        _getPurchaseHistory = getPurchaseHistory,
        _getPurchaseStatistics = getPurchaseStatistics,
        super(const TokenInitial()) {
    // Register event handlers
    on<GetTokenStatus>(_onGetTokenStatus);
    on<RefreshTokenStatus>(_onRefreshTokenStatus);
    on<ConsumeTokens>(_onConsumeTokens);
    on<SimulateTokenConsumption>(_onSimulateTokenConsumption);
    on<ResetDailyTokens>(_onResetDailyTokens);
    on<UpgradeUserPlan>(_onUpgradeUserPlan);
    on<ClearTokenError>(_onClearTokenError);
    on<ValidateTokenSufficiency>(_onValidateTokenSufficiency);
    on<PaymentSuccess>(_onPaymentSuccess);
    on<PaymentFailure>(_onPaymentFailure);
    on<ScheduleTokenResetNotification>(_onScheduleTokenResetNotification);
    on<PrefetchTokenStatus>(_onPrefetchTokenStatus);
    on<CreatePaymentOrder>(_onCreatePaymentOrder);
    on<ConfirmPayment>(_onConfirmPayment);
    on<GetPurchaseHistory>(_onGetPurchaseHistory);
    on<GetPurchaseStatistics>(_onGetPurchaseStatistics);
    on<RefreshPurchaseHistory>(_onRefreshPurchaseHistory);

    // Start auto-refresh timer
    _startAutoRefreshTimer();
  }

  @override
  Future<void> close() {
    _refreshTimer?.cancel();
    return super.close();
  }

  /// Handles fetching token status from API or cache
  Future<void> _onGetTokenStatus(
    GetTokenStatus event,
    Emitter<TokenState> emit,
  ) async {
    if (kDebugMode) {
      print('🪙 [TOKEN_BLOC] GetTokenStatus event received');
      print(
          '🪙 [TOKEN_BLOC] Cache valid: ${_isCacheValid()}, cached status: $_cachedTokenStatus');
    }

    // Check if cached data is valid
    if (_isCacheValid() && _cachedTokenStatus != null) {
      if (kDebugMode) {
        print(
            '🪙 [TOKEN_BLOC] Using cached token status: ${_cachedTokenStatus!.userPlan}');
      }
      emit(TokenLoaded(
        tokenStatus: _cachedTokenStatus!,
        lastUpdated: _lastCacheUpdate!,
      ));
      return;
    }

    if (kDebugMode) {
      print('🪙 [TOKEN_BLOC] Fetching token status from API...');
    }
    emit(const TokenLoading(operation: 'fetching'));

    final result = await _getTokenStatus(NoParams());

    result.fold(
      (failure) {
        if (kDebugMode) {
          print('🪙 [TOKEN_BLOC] ❌ Token fetch failed: ${failure.message}');
        }
        emit(TokenError(
          failure: failure,
          operation: 'fetching',
          previousTokenStatus: _cachedTokenStatus,
        ));
      },
      (tokenStatus) {
        if (kDebugMode) {
          print(
              '🪙 [TOKEN_BLOC] ✅ Token fetch success: plan=${tokenStatus.userPlan}, tokens=${tokenStatus.totalTokens}');
        }
        _updateCache(tokenStatus);
        emit(TokenLoaded(
          tokenStatus: tokenStatus,
          lastUpdated: DateTime.now(),
        ));
      },
    );
  }

  /// Handles refreshing token status (ignores cache)
  Future<void> _onRefreshTokenStatus(
    RefreshTokenStatus event,
    Emitter<TokenState> emit,
  ) async {
    // If already loaded, show refresh indicator
    if (state is TokenLoaded) {
      final currentState = state as TokenLoaded;
      emit(currentState.copyWith(isRefreshing: true));
    } else {
      emit(const TokenLoading(operation: 'refreshing'));
    }

    final result = await _getTokenStatus(NoParams());

    result.fold(
      (failure) => emit(TokenError(
        failure: failure,
        operation: 'refreshing',
        previousTokenStatus: _cachedTokenStatus,
      )),
      (tokenStatus) {
        _updateCache(tokenStatus);
        emit(TokenLoaded(
          tokenStatus: tokenStatus,
          lastUpdated: DateTime.now(),
        ));
      },
    );
  }

  /// Handles local token consumption (immediate UI feedback)
  Future<void> _onConsumeTokens(
    ConsumeTokens event,
    Emitter<TokenState> emit,
  ) async {
    if (_cachedTokenStatus == null) {
      emit(const TokenError(
        failure: CacheFailure(message: 'Token status not available'),
        operation: 'consumption',
      ));
      return;
    }

    // Premium users have unlimited tokens
    if (_cachedTokenStatus!.isPremium) {
      return; // No need to consume tokens
    }

    // Check if sufficient tokens available
    if (_cachedTokenStatus!.totalTokens < event.tokensConsumed) {
      emit(TokenError(
        failure: InsufficientTokensFailure(
          requiredTokens: event.tokensConsumed,
          availableTokens: _cachedTokenStatus!.totalTokens,
        ),
        operation: 'consumption',
        previousTokenStatus: _cachedTokenStatus,
      ));
      return;
    }

    // Show consumption in progress
    emit(TokenConsuming(
      currentTokenStatus: _cachedTokenStatus!,
      tokensBeingConsumed: event.tokensConsumed,
      operationType: event.operationType,
    ));

    // Update cached token count immediately for UI responsiveness
    final updatedTokenStatus = _cachedTokenStatus!.copyWith(
      purchasedTokens:
          (_cachedTokenStatus!.purchasedTokens - event.tokensConsumed)
              .clamp(0, double.infinity)
              .toInt(),
      totalTokens: (_cachedTokenStatus!.totalTokens - event.tokensConsumed)
          .clamp(0, double.infinity)
          .toInt(),
    );

    _updateCache(updatedTokenStatus);

    emit(TokenLoaded(
      tokenStatus: updatedTokenStatus,
      lastUpdated: DateTime.now(),
    ));

    // Refresh from server in background to sync with actual consumption
    add(const RefreshTokenStatus());
  }

  /// Handles token consumption simulation for testing
  Future<void> _onSimulateTokenConsumption(
    SimulateTokenConsumption event,
    Emitter<TokenState> emit,
  ) async {
    add(ConsumeTokens(
      tokensConsumed: event.tokensToConsume,
      operationType: 'simulation',
    ));
  }

  /// Handles daily token reset (typically server-driven)
  Future<void> _onResetDailyTokens(
    ResetDailyTokens event,
    Emitter<TokenState> emit,
  ) async {
    // Refresh token status to get updated daily allocation
    add(const RefreshTokenStatus());
  }

  /// Handles plan upgrade process
  Future<void> _onUpgradeUserPlan(
    UpgradeUserPlan event,
    Emitter<TokenState> emit,
  ) async {
    if (_cachedTokenStatus == null) {
      emit(const TokenError(
        failure: CacheFailure(message: 'Token status not available'),
        operation: 'upgrade',
      ));
      return;
    }

    emit(TokenPlanUpgrading(
      currentTokenStatus: _cachedTokenStatus!,
      targetPlan: event.targetPlan,
      step: PurchaseStep.initiating,
    ));

    // TODO: Implement actual plan upgrade logic with payment processing
    // For now, simulate successful upgrade
    await Future.delayed(const Duration(seconds: 2));

    final upgradedPlan =
        event.targetPlan == 'premium' ? UserPlan.premium : UserPlan.standard;
    final newDailyLimit = upgradedPlan == UserPlan.premium
        ? 0
        : (upgradedPlan == UserPlan.standard ? 100 : 50);

    final updatedTokenStatus = _cachedTokenStatus!.copyWith(
      availableTokens: upgradedPlan == UserPlan.premium ? 0 : newDailyLimit,
      totalTokens: upgradedPlan == UserPlan.premium
          ? 0
          : newDailyLimit + _cachedTokenStatus!.purchasedTokens,
      dailyLimit: newDailyLimit,
      userPlan: upgradedPlan,
      isPremium: upgradedPlan == UserPlan.premium,
      unlimitedUsage: upgradedPlan == UserPlan.premium,
      canPurchaseTokens: upgradedPlan == UserPlan.standard,
    );

    _updateCache(updatedTokenStatus);

    emit(TokenPlanUpgradeSuccess(
      updatedTokenStatus: updatedTokenStatus,
      newPlan: event.targetPlan,
    ));

    // Transition back to loaded state
    Timer(const Duration(seconds: 3), () {
      if (!isClosed && !_shouldPreservePurchaseHistoryState()) {
        add(const GetTokenStatus());
      }
    });
  }

  /// Handles clearing error states
  Future<void> _onClearTokenError(
    ClearTokenError event,
    Emitter<TokenState> emit,
  ) async {
    if (state is TokenError) {
      final errorState = state as TokenError;
      if (errorState.previousTokenStatus != null) {
        emit(TokenLoaded(
          tokenStatus: errorState.previousTokenStatus!,
          lastUpdated: _lastCacheUpdate ?? DateTime.now(),
        ));
      } else {
        emit(const TokenInitial());
      }
    }
  }

  /// Handles token sufficiency validation
  Future<void> _onValidateTokenSufficiency(
    ValidateTokenSufficiency event,
    Emitter<TokenState> emit,
  ) async {
    if (_cachedTokenStatus == null) {
      add(const GetTokenStatus());
      return;
    }

    emit(TokenValidating(
      requiredTokens: event.requiredTokens,
      operationType: event.operationType,
    ));

    await Future.delayed(
        const Duration(milliseconds: 300)); // Brief validation delay

    final hasSufficientTokens =
        _cachedTokenStatus!.hasSufficientTokens(event.requiredTokens);

    emit(TokenValidated(
      hasSufficientTokens: hasSufficientTokens,
      requiredTokens: event.requiredTokens,
      availableTokens: _cachedTokenStatus!.totalTokens,
      operationType: event.operationType,
    ));

    // Return to loaded state
    Timer(const Duration(seconds: 2), () {
      if (!isClosed && _cachedTokenStatus != null) {
        emit(TokenLoaded(
          tokenStatus: _cachedTokenStatus!,
          lastUpdated: _lastCacheUpdate ?? DateTime.now(),
        ));
      }
    });
  }

  /// Handles successful payment callback from Razorpay
  Future<void> _onPaymentSuccess(
    PaymentSuccess event,
    Emitter<TokenState> emit,
  ) async {
    if (_cachedTokenStatus == null) return;

    emit(TokenPurchasing(
      currentTokenStatus: _cachedTokenStatus!,
      tokensToPurchase: event.tokensPurchased,
      amount: event.tokensPurchased / 10.0,
      step: PurchaseStep.verifyingPayment,
    ));

    // TODO: Verify payment with backend
    await Future.delayed(const Duration(seconds: 1));

    emit(TokenPurchasing(
      currentTokenStatus: _cachedTokenStatus!,
      tokensToPurchase: event.tokensPurchased,
      amount: event.tokensPurchased / 10.0,
      step: PurchaseStep.updatingBalance,
    ));

    // Update token balance
    final updatedTokenStatus = _cachedTokenStatus!.copyWith(
      purchasedTokens:
          _cachedTokenStatus!.purchasedTokens + event.tokensPurchased,
      totalTokens: _cachedTokenStatus!.totalTokens + event.tokensPurchased,
    );

    _updateCache(updatedTokenStatus);

    emit(TokenPurchaseSuccess(
      updatedTokenStatus: updatedTokenStatus,
      tokensPurchased: event.tokensPurchased,
      amountPaid: event.tokensPurchased / 10.0,
      paymentId: event.paymentId,
    ));
  }

  /// Handles failed payment callback from Razorpay
  Future<void> _onPaymentFailure(
    PaymentFailure event,
    Emitter<TokenState> emit,
  ) async {
    emit(TokenError(
      failure: TokenPaymentFailure(paymentError: event.error),
      operation: 'payment',
      previousTokenStatus: _cachedTokenStatus,
    ));
  }

  /// Handles scheduling token reset notifications
  Future<void> _onScheduleTokenResetNotification(
    ScheduleTokenResetNotification event,
    Emitter<TokenState> emit,
  ) async {
    // TODO: Integrate with local notification system
    // For now, just acknowledge the event
  }

  /// Handles prefetching token status in background
  Future<void> _onPrefetchTokenStatus(
    PrefetchTokenStatus event,
    Emitter<TokenState> emit,
  ) async {
    // Prefetch without emitting loading states
    final result = await _getTokenStatus(NoParams());
    result.fold(
      (failure) => {}, // Ignore prefetch failures
      (tokenStatus) => _updateCache(tokenStatus),
    );
  }

  /// Handles creating payment order (step 1 of new payment flow)
  Future<void> _onCreatePaymentOrder(
    CreatePaymentOrder event,
    Emitter<TokenState> emit,
  ) async {
    if (_cachedTokenStatus == null) {
      emit(const TokenError(
        failure: CacheFailure(message: 'Token status not available'),
        operation: 'order_creation',
      ));
      return;
    }

    // Premium users cannot purchase tokens (they have unlimited)
    if (_cachedTokenStatus!.userPlan == UserPlan.premium) {
      emit(const TokenError(
        failure: ValidationFailure(
            message:
                'Premium users have unlimited tokens and do not need to purchase'),
        operation: 'order_creation',
      ));
      return;
    }

    // Emit order creating state
    emit(TokenOrderCreating(
      currentTokenStatus: _cachedTokenStatus!,
      tokensToPurchase: event.tokenAmount,
      amount: event.tokenAmount / 10.0, // 10 tokens = ₹1
    ));

    // Create payment order
    final orderParams = create_payment_order.CreatePaymentOrderParams(
      tokenAmount: event.tokenAmount,
    );

    final result = await _createPaymentOrder(orderParams);

    result.fold(
      (failure) => emit(TokenError(
        failure: failure,
        operation: 'order_creation',
        previousTokenStatus: _cachedTokenStatus,
      )),
      (orderResponse) => emit(TokenOrderCreated(
        currentTokenStatus: _cachedTokenStatus!,
        tokensToPurchase: event.tokenAmount,
        amount: event.tokenAmount / 10.0,
        orderId: orderResponse.orderId,
        keyId: orderResponse.keyId,
      )),
    );
  }

  /// Handles confirming payment (step 2 of new payment flow)
  Future<void> _onConfirmPayment(
    ConfirmPayment event,
    Emitter<TokenState> emit,
  ) async {
    debugPrint(
        '🔍 [TOKEN_BLOC] _onConfirmPayment called for payment: ${event.paymentId}');
    if (_cachedTokenStatus == null) {
      emit(const TokenError(
        failure: CacheFailure(message: 'Token status not available'),
        operation: 'payment_confirmation',
      ));
      return;
    }

    // Comprehensive input validation before payment confirmation
    final validationError = _validatePaymentConfirmationInputs(event);
    if (validationError != null) {
      emit(TokenError(
        failure: validationError,
        operation: 'payment_confirmation',
        previousTokenStatus: _cachedTokenStatus,
      ));
      return;
    }

    // Emit payment confirming state
    emit(TokenPaymentConfirming(
      currentTokenStatus: _cachedTokenStatus!,
      tokensPurchased: event.tokenAmount,
      paymentId: event.paymentId,
      orderId: event.orderId,
      signature: event.signature,
    ));

    // Confirm payment
    final confirmParams = confirm_payment.ConfirmPaymentParams(
      paymentId: event.paymentId,
      orderId: event.orderId,
      signature: event.signature,
      tokenAmount: event.tokenAmount,
    );

    final result = await _confirmPayment(confirmParams);

    result.fold(
      (failure) => emit(TokenError(
        failure: failure,
        operation: 'payment_confirmation',
        previousTokenStatus: _cachedTokenStatus,
      )),
      (updatedTokenStatus) {
        _updateCache(updatedTokenStatus);
        emit(TokenPurchaseSuccess(
          updatedTokenStatus: updatedTokenStatus,
          tokensPurchased: event.tokenAmount,
          amountPaid: event.tokenAmount / 10.0,
          paymentId: event.paymentId,
        ));

        // Transition back to loaded state after success message
        Timer(const Duration(seconds: 3), () {
          if (!isClosed && !_shouldPreservePurchaseHistoryState()) {
            add(const GetTokenStatus());
          }
        });
      },
    );
  }

  /// Handles fetching purchase history
  Future<void> _onGetPurchaseHistory(
    GetPurchaseHistory event,
    Emitter<TokenState> emit,
  ) async {
    final offset = event.offset ?? 0;
    final limit = event.limit ?? 20;

    debugPrint(
        '🔍 [TOKEN_BLOC] GetPurchaseHistory called - offset: $offset, limit: $limit');
    debugPrint('🔍 [TOKEN_BLOC] Current state: ${state.runtimeType}');

    // Only show loading if this is the first load (offset = 0)
    if (offset == 0) {
      debugPrint(
          '🔍 [TOKEN_BLOC] Emitting PurchaseHistoryLoading (offset = 0)');
      emit(const PurchaseHistoryLoading());
    } else {
      debugPrint(
          '🔍 [TOKEN_BLOC] Skipping loading state (offset > 0, pagination)');
    }

    final params = get_purchase_history.GetPurchaseHistoryParams(
      limit: event.limit,
      offset: event.offset,
    );

    final result = await _getPurchaseHistory(params);

    result.fold(
      (failure) {
        debugPrint(
            '😨 [TOKEN_BLOC] Purchase history fetch failed: ${failure.message}');
        emit(PurchaseHistoryError(
          failure: failure,
          operation: 'fetch_history',
        ));
      },
      (newPurchases) {
        debugPrint(
            '🔍 [TOKEN_BLOC] Received ${newPurchases.length} new purchases from API');
        debugPrint(
            '🔍 [TOKEN_BLOC] Checking pagination condition: offset=$offset > 0 = ${offset > 0}');
        debugPrint(
            '🔍 [TOKEN_BLOC] Current state is PurchaseHistoryLoaded: ${state is PurchaseHistoryLoaded}');

        // If this is pagination (offset > 0), accumulate with existing data
        if (offset > 0 && state is PurchaseHistoryLoaded) {
          final currentState = state as PurchaseHistoryLoaded;
          final combinedPurchases =
              List<PurchaseHistory>.from(currentState.purchases)
                ..addAll(newPurchases);

          debugPrint(
              '🔄 [TOKEN_BLOC] Pagination: Added ${newPurchases.length} purchases to existing ${currentState.purchases.length}, total: ${combinedPurchases.length}');

          // Preserve existing statistics if they exist
          emit(PurchaseHistoryLoaded(
            purchases: combinedPurchases,
            statistics: currentState.statistics, // Preserve statistics
            lastUpdated: DateTime.now(),
          ));
        } else {
          // First load or refresh - replace data
          final reason = offset == 0
              ? 'Initial load'
              : (state is! PurchaseHistoryLoaded
                  ? 'State not PurchaseHistoryLoaded'
                  : 'Unknown');
          debugPrint(
              '🔄 [TOKEN_BLOC] Initial/Refresh load ($reason): ${newPurchases.length} purchases');
          emit(PurchaseHistoryLoaded(
            purchases: newPurchases,
            lastUpdated: DateTime.now(),
          ));
        }
      },
    );
  }

  /// Handles fetching purchase statistics
  Future<void> _onGetPurchaseStatistics(
    GetPurchaseStatistics event,
    Emitter<TokenState> emit,
  ) async {
    debugPrint('🔍 [TOKEN_BLOC] GetPurchaseStatistics called');
    debugPrint(
        '🔍 [TOKEN_BLOC] Current state before statistics fetch: ${state.runtimeType}');

    // Check if we currently have purchase history loaded
    final currentState = state;
    List<PurchaseHistory>? existingPurchases;

    if (currentState is PurchaseHistoryLoaded) {
      existingPurchases = currentState.purchases;
      debugPrint(
          '🔍 [TOKEN_BLOC] Found existing purchase history with ${existingPurchases.length} items');
    }

    emit(const PurchaseStatisticsLoading());

    final result = await _getPurchaseStatistics(NoParams());

    result.fold(
      (failure) => emit(PurchaseHistoryError(
        failure: failure,
        operation: 'fetch_statistics',
      )),
      (statistics) {
        debugPrint('🔍 [TOKEN_BLOC] Statistics loaded successfully');

        // If we had existing purchase history, preserve it with the new statistics
        if (existingPurchases != null && existingPurchases.isNotEmpty) {
          debugPrint(
              '🔍 [TOKEN_BLOC] Preserving ${existingPurchases.length} existing purchases with new statistics');
          emit(PurchaseHistoryLoaded(
            purchases: existingPurchases,
            statistics: statistics,
            lastUpdated: DateTime.now(),
          ));
        } else {
          // No existing history, emit statistics only
          debugPrint(
              '🔍 [TOKEN_BLOC] No existing purchases to preserve, emitting statistics only');
          emit(PurchaseStatisticsLoaded(
            statistics: statistics,
            lastUpdated: DateTime.now(),
          ));
        }
      },
    );
  }

  /// Handles refreshing purchase history
  Future<void> _onRefreshPurchaseHistory(
    RefreshPurchaseHistory event,
    Emitter<TokenState> emit,
  ) async {
    // Get fresh purchase history (statistics will be auto-loaded after completion)
    debugPrint(
        '🔄 [TOKEN_BLOC] RefreshPurchaseHistory - loading fresh data from offset 0');
    add(const GetPurchaseHistory(limit: 20, offset: 0));
  }

  /// Updates the token status cache
  void _updateCache(TokenStatus tokenStatus) {
    _cachedTokenStatus = tokenStatus;
    _lastCacheUpdate = DateTime.now();
  }

  /// Checks if cached data is still valid
  bool _isCacheValid() {
    if (_lastCacheUpdate == null) return false;
    final now = DateTime.now();
    return now.difference(_lastCacheUpdate!) < _cacheValidityDuration;
  }

  /// Starts auto-refresh timer for background updates
  void _startAutoRefreshTimer() {
    _refreshTimer = Timer.periodic(_autoRefreshInterval, (timer) {
      if (_cachedTokenStatus != null && !isClosed) {
        add(const PrefetchTokenStatus());
      }
    });
  }

  /// Checks if current state should be preserved (purchase history related)
  ///
  /// Returns true if current state is purchase history related and should not be overwritten
  bool _shouldPreservePurchaseHistoryState() {
    return state is PurchaseHistoryLoaded ||
        state is PurchaseStatisticsLoaded ||
        state is PurchaseStatisticsLoading ||
        state is PurchaseHistoryLoading ||
        state is PurchaseHistoryError;
  }

  /// Validates payment confirmation inputs before processing
  ///
  /// Returns [ValidationFailure] if validation fails, null if valid
  ValidationFailure? _validatePaymentConfirmationInputs(ConfirmPayment event) {
    // Validate paymentId
    if (event.paymentId.trim().isEmpty) {
      return const ValidationFailure(message: 'Payment ID cannot be empty');
    }

    // Basic Razorpay payment ID format validation
    if (!RegExp(r'^pay_[A-Za-z0-9]{14}$').hasMatch(event.paymentId.trim())) {
      return const ValidationFailure(message: 'Invalid payment ID format');
    }

    // Validate orderId
    if (event.orderId.trim().isEmpty) {
      return const ValidationFailure(message: 'Order ID cannot be empty');
    }

    // Basic Razorpay order ID format validation
    if (!RegExp(r'^order_[A-Za-z0-9]{14}$').hasMatch(event.orderId.trim())) {
      return const ValidationFailure(message: 'Invalid order ID format');
    }

    // Validate signature
    if (event.signature.trim().isEmpty) {
      return const ValidationFailure(
          message: 'Payment signature cannot be empty');
    }

    // Basic signature format validation (hex string)
    if (!RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(event.signature.trim())) {
      return const ValidationFailure(
          message: 'Invalid payment signature format');
    }

    // Validate token amount
    if (event.tokenAmount <= 0) {
      return const ValidationFailure(
          message: 'Token amount must be greater than zero');
    }

    if (event.tokenAmount < 50) {
      return const ValidationFailure(
          message: 'Minimum token purchase is 50 tokens');
    }

    if (event.tokenAmount > 9999) {
      return const ValidationFailure(
          message: 'Maximum token purchase is 9,999 tokens per transaction');
    }

    return null; // All validations passed
  }
}

/// Validation-related failure
class ValidationFailure extends failures.Failure {
  const ValidationFailure({String? message})
      : super(
            message: message ?? 'Validation failed', code: 'VALIDATION_ERROR');

  @override
  List<Object?> get props => [message];
}
