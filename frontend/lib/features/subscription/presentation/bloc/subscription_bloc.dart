import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dartz/dartz.dart';

import '../../domain/entities/subscription.dart';
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

  // Subscription cache with timestamp
  Subscription? _cachedSubscription;
  DateTime? _lastCacheUpdate;
  Timer? _refreshTimer;

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
  })  : _getActiveSubscription = getActiveSubscription,
        _createSubscription = createSubscription,
        _cancelSubscription = cancelSubscription,
        _resumeSubscription = resumeSubscription,
        _getSubscriptionHistory = getSubscriptionHistory,
        _getSubscriptionInvoices = getSubscriptionInvoices,
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

    final result = await _createSubscription(NoParams());

    result.fold(
      (failure) => emit(SubscriptionError(
        failure: failure,
        operation: 'creating',
        previousSubscription: _cachedSubscription,
      )),
      (createResult) {
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
