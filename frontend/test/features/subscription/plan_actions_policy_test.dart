import 'package:flutter_test/flutter_test.dart';

import 'package:disciplefy_bible_study/features/subscription/presentation/utils/plan_actions_policy.dart';
import 'package:disciplefy_bible_study/features/tokens/domain/entities/token_status.dart';

void main() {
  group('canUpgrade', () {
    test('every plan below Premium can upgrade', () {
      expect(PlanActionsPolicy.canUpgrade(UserPlan.free), isTrue);
      expect(PlanActionsPolicy.canUpgrade(UserPlan.standard), isTrue);
      expect(PlanActionsPolicy.canUpgrade(UserPlan.plus), isTrue);
    });

    test('Premium is the top tier and cannot upgrade', () {
      expect(PlanActionsPolicy.canUpgrade(UserPlan.premium), isFalse);
    });

    test('kill switch suppresses every upgrade path', () {
      for (final plan in UserPlan.values) {
        expect(
          PlanActionsPolicy.canUpgrade(plan, newSubscriptionsEnabled: false),
          isFalse,
          reason: '${plan.name} must not offer upgrade when disabled',
        );
      }
    });
  });

  group('canDowngrade', () {
    test('only paid tiers above Standard can downgrade', () {
      expect(PlanActionsPolicy.canDowngrade(UserPlan.plus), isTrue);
      expect(PlanActionsPolicy.canDowngrade(UserPlan.premium), isTrue);
    });

    test('Standard and Free have no lower paid tier', () {
      // Dropping below Standard is a cancellation, not a downgrade.
      expect(PlanActionsPolicy.canDowngrade(UserPlan.standard), isFalse);
      expect(PlanActionsPolicy.canDowngrade(UserPlan.free), isFalse);
    });
  });

  group('canCancel', () {
    test('paid plans can cancel', () {
      expect(PlanActionsPolicy.canCancel(UserPlan.standard), isTrue);
      expect(PlanActionsPolicy.canCancel(UserPlan.plus), isTrue);
      expect(PlanActionsPolicy.canCancel(UserPlan.premium), isTrue);
    });

    test('Free has no paid subscription to cancel', () {
      // Regression guard: a Free subscription row reports itself active, which
      // previously surfaced "Cancel Subscription" on the Free plan.
      expect(PlanActionsPolicy.canCancel(UserPlan.free), isFalse);
    });
  });

  group('actions offered per plan', () {
    test('Free offers upgrade only', () {
      const plan = UserPlan.free;
      expect(PlanActionsPolicy.canUpgrade(plan), isTrue);
      expect(PlanActionsPolicy.canDowngrade(plan), isFalse);
      expect(PlanActionsPolicy.canCancel(plan), isFalse);
    });

    test('Standard offers upgrade and cancel', () {
      const plan = UserPlan.standard;
      expect(PlanActionsPolicy.canUpgrade(plan), isTrue);
      expect(PlanActionsPolicy.canDowngrade(plan), isFalse);
      expect(PlanActionsPolicy.canCancel(plan), isTrue);
    });

    test('Plus offers upgrade, downgrade and cancel', () {
      const plan = UserPlan.plus;
      expect(PlanActionsPolicy.canUpgrade(plan), isTrue);
      expect(PlanActionsPolicy.canDowngrade(plan), isTrue);
      expect(PlanActionsPolicy.canCancel(plan), isTrue);
    });

    test('Premium offers downgrade and cancel, never upgrade', () {
      const plan = UserPlan.premium;
      expect(PlanActionsPolicy.canUpgrade(plan), isFalse);
      expect(PlanActionsPolicy.canDowngrade(plan), isTrue);
      expect(PlanActionsPolicy.canCancel(plan), isTrue);
    });
  });
}
