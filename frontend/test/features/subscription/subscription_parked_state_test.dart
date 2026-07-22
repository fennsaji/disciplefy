import 'package:flutter_test/flutter_test.dart';

import 'package:disciplefy_bible_study/features/subscription/domain/entities/subscription.dart';

Subscription buildSubscription({
  required SubscriptionStatus status,
  String? cancellationReason,
  String planType = 'free_tier',
}) {
  final now = DateTime(2026, 7, 22);
  return Subscription(
    id: 'sub-1',
    userId: 'user-1',
    razorpaySubscriptionId: 'rzp-1',
    status: status,
    planType: planType,
    amountPaise: 0,
    currency: 'INR',
    paidCount: 0,
    cancelAtCycleEnd: true,
    cancellationReason: cancellationReason,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  // The exact marker written by create-subscription-v2 when it parks the old
  // subscription while an upgrade checkout is in flight.
  const parkedReason =
      'Pending upgrade — will be cancelled on new subscription activation';

  group('isParkedForUpgrade', () {
    test('true for a subscription parked by an in-flight upgrade', () {
      final sub = buildSubscription(
        status: SubscriptionStatus.pending_cancellation,
        cancellationReason: parkedReason,
      );
      expect(sub.isParkedForUpgrade, isTrue);
      expect(sub.isPendingUserCancellation, isFalse);
    });

    test('false for a cancellation the user actually requested', () {
      final sub = buildSubscription(
        status: SubscriptionStatus.pending_cancellation,
      );
      expect(sub.isParkedForUpgrade, isFalse);
      expect(sub.isPendingUserCancellation, isTrue);
    });

    test('false for a scheduled downgrade', () {
      // Downgrades also park the old sub, but they are a real user decision and
      // should keep showing the cancellation notice.
      final sub = buildSubscription(
        status: SubscriptionStatus.pending_cancellation,
        cancellationReason: 'Scheduled downgrade to standard',
      );
      expect(sub.isParkedForUpgrade, isFalse);
      expect(sub.isPendingUserCancellation, isTrue);
    });

    test('false for any non-pending_cancellation status', () {
      for (final status in SubscriptionStatus.values) {
        if (status == SubscriptionStatus.pending_cancellation) continue;
        final sub = buildSubscription(
          status: status,
          cancellationReason: parkedReason,
        );
        expect(sub.isParkedForUpgrade, isFalse,
            reason: '${status.name} must never read as parked');
      }
    });
  });

  test('a parked subscription still counts as active', () {
    // The user keeps their plan while the upgrade checkout is pending.
    final sub = buildSubscription(
      status: SubscriptionStatus.pending_cancellation,
      cancellationReason: parkedReason,
    );
    expect(sub.isActive, isTrue);
  });

  group('isActivatedPlan', () {
    test('true only when the purchased plan is genuinely active', () {
      final sub = buildSubscription(
        status: SubscriptionStatus.active,
        planType: 'standard_monthly',
      );
      expect(sub.isActivatedPlan('standard'), isTrue);
    });

    test('accepts the authenticated (mandate approved) state', () {
      final sub = buildSubscription(
        status: SubscriptionStatus.authenticated,
        planType: 'standard_monthly',
      );
      expect(sub.isActivatedPlan('standard'), isTrue);
    });

    test('false for a different plan than the one purchased', () {
      final sub = buildSubscription(
        status: SubscriptionStatus.active,
        planType: 'plus_monthly',
      );
      expect(sub.isActivatedPlan('standard'), isFalse);
    });

    test('false for the old plan parked during checkout', () {
      // Regression guard: this is the false "Subscription activated!" toast —
      // the parked free plan reports isActive == true while the user has not
      // paid, so a success check must not accept it.
      final parked = buildSubscription(
        status: SubscriptionStatus.pending_cancellation,
        cancellationReason: parkedReason,
      );
      expect(parked.isActive, isTrue, reason: 'isActive is the trap');
      expect(parked.isActivatedPlan('standard'), isFalse);
      expect(parked.isActivatedPlan('free'), isFalse);
    });

    test('false while the new subscription is still awaiting payment', () {
      final pending = buildSubscription(
        status: SubscriptionStatus.created,
        planType: 'standard_monthly',
      );
      expect(pending.isActivatedPlan('standard'), isFalse);
    });
  });
}
