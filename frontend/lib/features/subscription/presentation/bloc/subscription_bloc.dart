import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dartz/dartz.dart';

import '../../domain/entities/subscription.dart';
import '../../domain/entities/user_subscription_status.dart';
import '../../domain/repositories/subscription_repository.dart';
import '../../domain/usecases/get_active_subscription.dart'
    as get_active_subscription;
import '../../domain/usecases/create_subscription.dart' as create_subscription;
import '../../domain/usecases/cancel_subscription.dart' as cancel_subscription;
import '../../domain/usecases/resume_subscription.dart' as resume_subscription;
import '../../domain/usecases/get_subscription_history.dart'
    as get_subscription_history;
import '../../domain/usecases/get_invoices.dart' as get_invoices;
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';

import 'subscription_event.dart';
import 'subscription_state.dart';

/// Subscription BLoC
///
/// Manages all subscription-related state and operations including:
/// - Fetching and caching active subscription status
/// - Creating new premium subscriptions
/// - Cancelling subscriptions (immediate or at cycle end)
/// - Managing subscription history and invoices
/// - Real-time subscription status updates
class SubscriptionBloc extends Bloc<SubscriptionEvent, SubscriptionState> {
  final get_active_subscription.GetActiveSubscription _getActiveSubscription;
  final create_subscription.CreateSubscription _createSubscription;
  final cancel_subscription.CancelSubscription _cancelSubscription;
  final resume_subscription.ResumeSubscription _resumeSubscription;
  final get_subscription_history.GetSubscriptionHistory _getSubscriptionHistory;
  final get_invoices.GetInvoices _getSubscriptionInvoices;
  final SubscriptionRepository _subscriptionRepository;

  // Subscription cache with timestamp
  Subscription? _cachedSubscription;
  DateTime? _lastCacheUpdate;
  Timer? _refreshTimer;

  // User subscription status cache
  UserSubscriptionStatus? _cachedSubscriptionStatus;
  DateTime? _lastStatusCacheUpdate;

  static const Duration _cacheValidityDuration = Duration(minutes: 10);
  static const Duration _autoRefreshInterval = Duration(minutes: 15);

  SubscriptionBloc({
    required get_active_subscription.GetActiveSubscription
        getActiveSubscription,
    required create_subscription.CreateSubscription createSubscription,
    required cancel_subscription.CancelSubscription cancelSubscription,
    required resume_subscription.ResumeSubscription resumeSubscription,
    required get_subscription_history.GetSubscriptionHistory
        getSubscriptionHistory,
    required get_invoices.GetInvoices getSubscriptionInvoices,
    required SubscriptionRepository subscriptionRepository,
  })  : _getActiveSubscription = getActiveSubscription,
        _createSubscription = createSubscription,
        _cancelSubscription = cancelSubscription,
        _resumeSubscription = resumeSubscription,
        _getSubscriptionHistory = getSubscriptionHistory,
        _getSubscriptionInvoices = getSubscriptionInvoices,
        _subscriptionRepository = subscriptionRepository,
        super(const SubscriptionInitial()) {
    // Register event handlers
    on<GetActiveSubscription>(_onGetActiveSubscription);
    on<CreateSubscription>(_onCreateSubscription);
    on<CancelSubscription>(_onCancelSubscription);
    on<ResumeSubscription>(_onResumeSubscription);
    on<RefreshSubscription>(_onRefreshSubscription);
    on<ClearSubscriptionError>(_onClearSubscriptionError);
    on<CheckSubscriptionEligibility>(_onCheckSubscriptionEligibility);
    on<PrefetchSubscriptionData>(_onPrefetchSubscriptionData);
    on<SubscriptionActivated>(_onSubscriptionActivated);
    on<SubscriptionExpired>(_onSubscriptionExpired);
    on<LoadSubscriptionStatus>(_onLoadSubscriptionStatus);
    on<CreateStandardSubscription>(_onCreateStandardSubscription);
    on<CreatePlusSubscription>(_onCreatePlusSubscription);
    on<GetSubscriptionInvoices>(_onGetSubscriptionInvoices);
    on<RefreshSubscriptionInvoices>(_onRefreshSubscriptionInvoices);
    on<StartPremiumTrial>(_onStartPremiumTrial);
    on<ActivateFreeSubscription>(_onActivateFreeSubscription);

    // Start auto-refresh timer for active subscriptions
    _startAutoRefreshTimer();
  }

  @override
  Future<void> close() {
    _refreshTimer?.cancel();
    return super.close();
  }

  /// Handles fetching active subscription from API or cache
  Future<void> _onGetActiveSubscription(
    GetActiveSubscription event,
    Emitter<SubscriptionState> emit,
  ) async {
    // Check if cached data is valid
    if (_isCacheValid() && _cachedSubscription != null) {
      emit(SubscriptionLoaded(
        activeSubscription: _cachedSubscription,
        lastUpdated: _lastCacheUpdate!,
      ));
      return;
    }

    emit(const SubscriptionLoading(operation: 'fetching'));

    final result = await _getActiveSubscription(NoParams());

    result.fold(
      (failure) => emit(SubscriptionError(
        failure: failure,
        operation: 'fetching',
        previousSubscription: _cachedSubscription,
      )),
      (subscription) {
        _updateCache(subscription);
        emit(SubscriptionLoaded(
          activeSubscription: subscription,
          lastUpdated: DateTime.now(),
        ));
      },
    );
  }

  /// Handles creating a new subscription
  Future<void> _onCreateSubscription(
    CreateSubscription event,
    Emitter<SubscriptionState> emit,
  ) async {
    emit(const SubscriptionLoading(operation: 'creating'));

    // Use V2 API with promo code
    final result = await _subscriptionRepository.createSubscriptionV2(
      planCode: 'premium',
      provider: 'razorpay',
      region: 'IN',
      promoCode: event.promoCode,
    );

    result.fold(
      (failure) => emit(SubscriptionError(
        failure: failure,
        operation: 'creating',
        previousSubscription: _cachedSubscription,
      )),
      (v2Result) {
        // Convert V2 response to legacy format for compatibility
        final createResult = CreateSubscriptionResult(
          success: v2Result.success,
          subscriptionId: v2Result.subscriptionId,
          razorpaySubscriptionId: v2Result.providerSubscriptionId,
          authorizationUrl: v2Result.authorizationUrl ?? '',
          amountRupees: 0.0, // Will be populated after payment confirmation
          status: SubscriptionStatus.created,
          message: 'Subscription created successfully',
        );

        // Emit subscription created state with authorization URL
        emit(SubscriptionCreated(
          result: createResult,
          createdAt: DateTime.now(),
        ));

        // Automatically trigger a refresh after a short delay
        // to get the updated subscription status
        Future.delayed(const Duration(seconds: 2), () {
          if (!isClosed) {
            add(const RefreshSubscription());
          }
        });
      },
    );
  }

  /// Handles cancelling a subscription
  Future<void> _onCancelSubscription(
    CancelSubscription event,
    Emitter<SubscriptionState> emit,
  ) async {
    emit(const SubscriptionLoading(operation: 'cancelling'));

    final params = cancel_subscription.CancelSubscriptionParams(
      cancelAtCycleEnd: event.cancelAtCycleEnd,
      reason: event.reason,
    );

    final result = await _cancelSubscription(params);

    result.fold(
      (failure) => emit(SubscriptionError(
        failure: failure,
        operation: 'cancelling',
        previousSubscription: _cachedSubscription,
      )),
      (cancelResult) {
        // Clear cache since subscription status changed
        _clearCache();

        emit(SubscriptionCancelled(
          result: cancelResult,
          cancelledAt: DateTime.now(),
        ));

        // Refresh subscription status to get updated data
        Future.delayed(const Duration(seconds: 1), () {
          if (!isClosed) {
            add(const RefreshSubscription());
          }
        });
      },
    );
  }

  /// Handles resuming a cancelled subscription
  Future<void> _onResumeSubscription(
    ResumeSubscription event,
    Emitter<SubscriptionState> emit,
  ) async {
    emit(const SubscriptionLoading(operation: 'resuming'));

    final result = await _resumeSubscription(NoParams());

    result.fold(
      (failure) => emit(SubscriptionError(
        failure: failure,
        operation: 'resuming',
        previousSubscription: _cachedSubscription,
      )),
      (resumeResult) {
        // Clear cache since subscription status changed
        _clearCache();

        emit(SubscriptionResumed(
          result: resumeResult,
          resumedAt: DateTime.now(),
        ));

        // Refresh subscription status to get updated data
        Future.delayed(const Duration(seconds: 1), () {
          if (!isClosed) {
            add(const RefreshSubscription());
          }
        });
      },
    );
  }

  /// Handles refreshing subscription status (ignores cache)
  Future<void> _onRefreshSubscription(
    RefreshSubscription event,
    Emitter<SubscriptionState> emit,
  ) async {
    // If already loaded, show refresh indicator
    if (state is SubscriptionLoaded) {
      final currentState = state as SubscriptionLoaded;
      emit(currentState.copyWith(isRefreshing: true));
    } else {
      emit(const SubscriptionLoading(operation: 'refreshing'));
    }

    final result = await _getActiveSubscription(NoParams());

    result.fold(
      (failure) => emit(SubscriptionError(
        failure: failure,
        operation: 'refreshing',
        previousSubscription: _cachedSubscription,
      )),
      (subscription) {
        _updateCache(subscription);
        emit(SubscriptionLoaded(
          activeSubscription: subscription,
          lastUpdated: DateTime.now(),
        ));
      },
    );
  }

  /// Handles clearing error state
  Future<void> _onClearSubscriptionError(
    ClearSubscriptionError event,
    Emitter<SubscriptionState> emit,
  ) async {
    // If we have cached subscription, return to loaded state
    if (_cachedSubscription != null && _lastCacheUpdate != null) {
      emit(SubscriptionLoaded(
        activeSubscription: _cachedSubscription,
        lastUpdated: _lastCacheUpdate!,
      ));
    } else {
      emit(const SubscriptionInitial());
    }
  }

  /// Handles checking subscription eligibility
  Future<void> _onCheckSubscriptionEligibility(
    CheckSubscriptionEligibility event,
    Emitter<SubscriptionState> emit,
  ) async {
    emit(const SubscriptionLoading(operation: 'checking'));

    final result = await _getActiveSubscription(NoParams());

    result.fold(
      (failure) {
        // If error is authentication failure, user can't subscribe
        if (failure is AuthenticationFailure) {
          emit(const SubscriptionEligibilityChecked(
            canSubscribe: false,
            reason: 'Please sign in to subscribe',
          ));
        } else {
          emit(SubscriptionError(
            failure: failure,
            operation: 'checking eligibility',
          ));
        }
      },
      (subscription) {
        if (subscription != null && subscription.isActive) {
          // User already has active subscription
          emit(SubscriptionEligibilityChecked(
            canSubscribe: false,
            reason: 'You already have an active premium subscription',
            existingSubscription: subscription,
          ));
        } else {
          // User can subscribe
          emit(const SubscriptionEligibilityChecked(
            canSubscribe: true,
          ));
        }
      },
    );
  }

  /// Handles prefetching subscription data
  Future<void> _onPrefetchSubscriptionData(
    PrefetchSubscriptionData event,
    Emitter<SubscriptionState> emit,
  ) async {
    // Only prefetch if cache is invalid
    if (!_isCacheValid()) {
      final result = await _getActiveSubscription(NoParams());

      result.fold(
        (_) {}, // Silently ignore errors for prefetch
        (subscription) => _updateCache(subscription),
      );
    }
  }

  /// Handles subscription activated event (from webhook/external source)
  Future<void> _onSubscriptionActivated(
    SubscriptionActivated event,
    Emitter<SubscriptionState> emit,
  ) async {
    // Clear cache and refresh to get latest data
    _clearCache();
    add(const RefreshSubscription());
  }

  /// Handles subscription expired event (from webhook/external source)
  Future<void> _onSubscriptionExpired(
    SubscriptionExpired event,
    Emitter<SubscriptionState> emit,
  ) async {
    // Clear cache and refresh to get latest data
    _clearCache();
    add(const RefreshSubscription());
  }

  /// Handles loading user subscription status (including trial info)
  Future<void> _onLoadSubscriptionStatus(
    LoadSubscriptionStatus event,
    Emitter<SubscriptionState> emit,
  ) async {
    // Check if cached status is valid
    if (_isStatusCacheValid() && _cachedSubscriptionStatus != null) {
      emit(UserSubscriptionStatusLoaded(
        subscriptionStatus: _cachedSubscriptionStatus!,
        lastUpdated: _lastStatusCacheUpdate!,
      ));
      return;
    }

    emit(const SubscriptionLoading(operation: 'loading status'));

    final result = await _subscriptionRepository.getSubscriptionStatus();

    result.fold(
      (failure) => emit(SubscriptionError(
        failure: failure,
        operation: 'loading subscription status',
      )),
      (status) {
        _updateStatusCache(status);
        emit(UserSubscriptionStatusLoaded(
          subscriptionStatus: status,
          lastUpdated: DateTime.now(),
        ));
      },
    );
  }

  /// Handles creating a Standard subscription
  Future<void> _onCreateStandardSubscription(
    CreateStandardSubscription event,
    Emitter<SubscriptionState> emit,
  ) async {
    // Preserve current status if available
    UserSubscriptionStatus? currentStatus;
    if (state is UserSubscriptionStatusLoaded) {
      currentStatus =
          (state as UserSubscriptionStatusLoaded).subscriptionStatus;
    }

    if (currentStatus != null) {
      emit(UserSubscriptionStatusLoaded(
        subscriptionStatus: currentStatus,
        lastUpdated: DateTime.now(),
        isLoading: true,
      ));
    } else {
      emit(const SubscriptionLoading(
          operation: 'creating standard subscription'));
    }

    // Use V2 API with promo code
    final result = await _subscriptionRepository.createSubscriptionV2(
      planCode: 'standard',
      provider: 'razorpay',
      region: 'IN',
      promoCode: event.promoCode,
    );

    result.fold(
      (failure) {
        final errorMessage = _getErrorMessage(failure);
        if (currentStatus != null) {
          emit(UserSubscriptionStatusLoaded(
            subscriptionStatus: currentStatus,
            lastUpdated: DateTime.now(),
            errorMessage: errorMessage,
          ));
        } else {
          emit(SubscriptionError(
            failure: failure,
            operation: 'creating standard subscription',
          ));
        }
      },
      (v2Result) {
        // Convert V2 response to legacy format for compatibility
        final createResult = CreateSubscriptionResult(
          success: v2Result.success,
          subscriptionId: v2Result.subscriptionId,
          razorpaySubscriptionId: v2Result.providerSubscriptionId,
          authorizationUrl: v2Result.authorizationUrl ?? '',
          amountRupees: 0.0, // Will be populated after payment confirmation
          status: SubscriptionStatus.created,
          message: 'Standard subscription created successfully',
        );

        if (currentStatus != null) {
          emit(UserSubscriptionStatusLoaded(
            subscriptionStatus: currentStatus,
            lastUpdated: DateTime.now(),
            authorizationUrl: createResult.authorizationUrl,
          ));
        } else {
          emit(SubscriptionCreated(
            result: createResult,
            createdAt: DateTime.now(),
          ));
        }
      },
    );
  }

  /// Handles creating a Plus subscription
  Future<void> _onCreatePlusSubscription(
    CreatePlusSubscription event,
    Emitter<SubscriptionState> emit,
  ) async {
    // Preserve current status if available
    UserSubscriptionStatus? currentStatus;
    if (state is UserSubscriptionStatusLoaded) {
      currentStatus =
          (state as UserSubscriptionStatusLoaded).subscriptionStatus;
    }

    if (currentStatus != null) {
      emit(UserSubscriptionStatusLoaded(
        subscriptionStatus: currentStatus,
        lastUpdated: DateTime.now(),
        isLoading: true,
      ));
    } else {
      emit(const SubscriptionLoading(operation: 'creating plus subscription'));
    }

    // Use V2 API with promo code
    final result = await _subscriptionRepository.createSubscriptionV2(
      planCode: 'plus',
      provider: 'razorpay',
      region: 'IN',
      promoCode: event.promoCode,
    );

    result.fold(
      (failure) {
        final errorMessage = _getErrorMessage(failure);
        if (currentStatus != null) {
          emit(UserSubscriptionStatusLoaded(
            subscriptionStatus: currentStatus,
            lastUpdated: DateTime.now(),
            errorMessage: errorMessage,
          ));
        } else {
          emit(SubscriptionError(
            failure: failure,
            operation: 'creating plus subscription',
          ));
        }
      },
      (v2Result) {
        // Convert V2 response to legacy format for compatibility
        final createResult = CreateSubscriptionResult(
          success: v2Result.success,
          subscriptionId: v2Result.subscriptionId,
          razorpaySubscriptionId: v2Result.providerSubscriptionId,
          authorizationUrl: v2Result.authorizationUrl ?? '',
          amountRupees: 0.0, // Will be populated after payment confirmation
          status: SubscriptionStatus.created,
          message: 'Plus subscription created successfully',
        );

        if (currentStatus != null) {
          emit(UserSubscriptionStatusLoaded(
            subscriptionStatus: currentStatus,
            lastUpdated: DateTime.now(),
            authorizationUrl: createResult.authorizationUrl,
          ));
        } else {
          emit(SubscriptionCreated(
            result: createResult,
            createdAt: DateTime.now(),
          ));
        }
      },
    );
  }

  /// Handles fetching subscription invoices
  Future<void> _onGetSubscriptionInvoices(
    GetSubscriptionInvoices event,
    Emitter<SubscriptionState> emit,
  ) async {
    emit(const SubscriptionLoading(operation: 'loading invoices'));

    final params = get_invoices.GetInvoicesParams(
      limit: event.limit ?? 20,
      offset: event.offset ?? 0,
    );

    final result = await _getSubscriptionInvoices(params);

    result.fold(
      (failure) => emit(SubscriptionError(
        failure: failure,
        operation: 'loading invoices',
        previousSubscription: _cachedSubscription,
      )),
      (invoices) {
        emit(SubscriptionLoaded(
          activeSubscription: _cachedSubscription,
          invoices: invoices,
          lastUpdated: DateTime.now(),
        ));
      },
    );
  }

  /// Handles refreshing subscription invoices (ignores cache)
  Future<void> _onRefreshSubscriptionInvoices(
    RefreshSubscriptionInvoices event,
    Emitter<SubscriptionState> emit,
  ) async {
    // If already loaded, preserve current data and show refresh indicator
    List<SubscriptionInvoice>? currentInvoices;
    if (state is SubscriptionLoaded) {
      final currentState = state as SubscriptionLoaded;
      currentInvoices = currentState.invoices;
      emit(currentState.copyWith(isRefreshing: true));
    } else {
      emit(const SubscriptionLoading(operation: 'refreshing invoices'));
    }

    final params = get_invoices.GetInvoicesParams(
      limit: 20,
      offset: 0,
    );

    final result = await _getSubscriptionInvoices(params);

    result.fold(
      (failure) => emit(SubscriptionError(
        failure: failure,
        operation: 'refreshing invoices',
        previousSubscription: _cachedSubscription,
      )),
      (invoices) {
        emit(SubscriptionLoaded(
          activeSubscription: _cachedSubscription,
          invoices: invoices,
          lastUpdated: DateTime.now(),
        ));
      },
    );
  }

  /// Get user-friendly error message from failure
  String _getErrorMessage(Failure failure) {
    if (failure is NetworkFailure) {
      return 'No internet connection. Please check your network.';
    } else if (failure is AuthenticationFailure) {
      return 'Please sign in to subscribe.';
    } else if (failure is ServerFailure) {
      return 'Server error. Please try again later.';
    } else if (failure is ClientFailure) {
      final clientFailure = failure;
      if (clientFailure.code == 'TRIAL_STILL_ACTIVE') {
        return 'Standard plan is currently free during trial period.';
      } else if (clientFailure.code == 'SUBSCRIPTION_EXISTS') {
        return 'You already have an active subscription.';
      }
      return clientFailure.message;
    } else {
      return 'An unexpected error occurred. Please try again.';
    }
  }

  // ========== Cache Management ==========

  /// Check if cached data is still valid
  bool _isCacheValid() {
    if (_lastCacheUpdate == null) return false;
    final now = DateTime.now();
    return now.difference(_lastCacheUpdate!) < _cacheValidityDuration;
  }

  /// Update cache with new subscription data
  void _updateCache(Subscription? subscription) {
    _cachedSubscription = subscription;
    _lastCacheUpdate = DateTime.now();
  }

  /// Clear cached subscription data
  void _clearCache() {
    _cachedSubscription = null;
    _lastCacheUpdate = null;
  }

  /// Check if subscription status cache is still valid
  bool _isStatusCacheValid() {
    if (_lastStatusCacheUpdate == null) return false;
    final now = DateTime.now();
    return now.difference(_lastStatusCacheUpdate!) < _cacheValidityDuration;
  }

  /// Update subscription status cache
  void _updateStatusCache(UserSubscriptionStatus status) {
    _cachedSubscriptionStatus = status;
    _lastStatusCacheUpdate = DateTime.now();
  }

  /// Clear subscription status cache
  void _clearStatusCache() {
    _cachedSubscriptionStatus = null;
    _lastStatusCacheUpdate = null;
  }

  /// Handles starting a Premium trial
  Future<void> _onStartPremiumTrial(
    StartPremiumTrial event,
    Emitter<SubscriptionState> emit,
  ) async {
    // Preserve current status if available
    UserSubscriptionStatus? currentStatus;
    if (state is UserSubscriptionStatusLoaded) {
      currentStatus =
          (state as UserSubscriptionStatusLoaded).subscriptionStatus;
    }

    if (currentStatus != null) {
      emit(UserSubscriptionStatusLoaded(
        subscriptionStatus: currentStatus,
        lastUpdated: DateTime.now(),
        isLoading: true,
      ));
    } else {
      emit(const SubscriptionLoading(operation: 'starting premium trial'));
    }

    final result = await _subscriptionRepository.startPremiumTrial();

    result.fold(
      (failure) {
        final errorMessage = _getPremiumTrialErrorMessage(failure);
        if (currentStatus != null) {
          emit(UserSubscriptionStatusLoaded(
            subscriptionStatus: currentStatus,
            lastUpdated: DateTime.now(),
            errorMessage: errorMessage,
          ));
        } else {
          emit(SubscriptionError(
            failure: failure,
            operation: 'starting premium trial',
          ));
        }
      },
      (trialResult) {
        // Clear status cache since user plan has changed
        _clearStatusCache();

        emit(PremiumTrialStarted(
          trialStartedAt: trialResult.trialStartedAt,
          trialEndAt: trialResult.trialEndAt,
          daysRemaining: trialResult.daysRemaining,
          message: trialResult.message,
        ));

        // Refresh subscription status to get updated data after a short delay
        Future.delayed(const Duration(seconds: 1), () {
          if (!isClosed) {
            add(const LoadSubscriptionStatus());
          }
        });
      },
    );
  }

  /// Get user-friendly error message for Premium trial failures
  String _getPremiumTrialErrorMessage(Failure failure) {
    if (failure is NetworkFailure) {
      return 'No internet connection. Please check your network.';
    } else if (failure is AuthenticationFailure) {
      return 'Please sign in to start your free trial.';
    } else if (failure is ServerFailure) {
      return 'Server error. Please try again later.';
    } else if (failure is ClientFailure) {
      final clientFailure = failure;
      if (clientFailure.code == 'TRIAL_ALREADY_USED') {
        return 'You have already used your free Premium trial.';
      } else if (clientFailure.code == 'ALREADY_PREMIUM') {
        return 'You already have Premium access.';
      } else if (clientFailure.code == 'NOT_ELIGIBLE') {
        return 'Premium trial is only available for new users.';
      } else if (clientFailure.code == 'TRIAL_NOT_AVAILABLE') {
        return 'Premium trial is not currently available.';
      }
      return clientFailure.message;
    } else {
      return 'An unexpected error occurred. Please try again.';
    }
  }

  /// Handles activating a free subscription (₹0 plans)
  ///
  /// Directly activates subscription for Free tier or plans with 100% discount
  /// Skips Razorpay payment flow since amount is ₹0
  Future<void> _onActivateFreeSubscription(
    ActivateFreeSubscription event,
    Emitter<SubscriptionState> emit,
  ) async {
    emit(const SubscriptionLoading(operation: 'activating_free_subscription'));

    // Call V2 API which will detect ₹0 and activate directly
    final result = await _subscriptionRepository.createSubscriptionV2(
      planCode: event.planCode,
      provider: 'razorpay',
      region: 'IN',
      promoCode: event.promoCode,
    );

    result.fold(
      (failure) => emit(SubscriptionError(
        failure: failure,
        operation: 'activating_free_subscription',
        previousSubscription: _cachedSubscription,
      )),
      (v2Result) {
        // Convert V2 response to legacy format for compatibility
        // For ₹0 plans, status should be 'active' and no authorization URL
        final createResult = CreateSubscriptionResult(
          success: v2Result.success,
          subscriptionId: v2Result.subscriptionId,
          razorpaySubscriptionId: v2Result.providerSubscriptionId,
          authorizationUrl:
              '', // No payment authorization needed for free plans
          amountRupees: 0.0,
          status: SubscriptionStatus.active, // Already active for free plans
          message: 'Free subscription activated successfully',
        );

        emit(SubscriptionCreated(
          result: createResult,
          createdAt: DateTime.now(),
        ));

        print(
            '✅ [BLOC] Free subscription activated: ${v2Result.subscriptionId}');

        // Refresh to update UI
        Future.delayed(const Duration(seconds: 1), () {
          if (!isClosed) {
            add(const RefreshSubscription());
          }
        });
      },
    );
  }

  // ========== Auto-Refresh Timer ==========

  /// Start timer for automatic subscription status refresh
  void _startAutoRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(_autoRefreshInterval, (_) {
      // Only auto-refresh if there's an active subscription
      if (_cachedSubscription?.isActive ?? false) {
        add(const RefreshSubscription());
      }
    });
  }
}
