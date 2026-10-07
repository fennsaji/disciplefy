import 'package:flutter_test/flutter_test.dart';

import 'package:disciplefy_bible_study/core/presentation/widgets/app_shell.dart';
import 'package:disciplefy_bible_study/features/auth/domain/entities/account_reason.dart';

/// Router branches: 0 Home, 1 Generate, 2 Topics, 3 Community, 4 Discipler.
void main() {
  group('guestAccountReasonForBranch', () {
    test('a guest is stopped at Generate, Community and Discipler', () {
      expect(
          guestAccountReasonForBranch(1, guest: true), AccountReason.generate);
      expect(
          guestAccountReasonForBranch(3, guest: true), AccountReason.community);
      expect(
          guestAccountReasonForBranch(4, guest: true), AccountReason.discipler);
    });

    test('Home and Topics stay open for a guest', () {
      expect(guestAccountReasonForBranch(0, guest: true), isNull);
      expect(guestAccountReasonForBranch(2, guest: true), isNull);
    });

    test('a full account (or guest mode off) opens every tab', () {
      for (var branch = 0; branch < 5; branch++) {
        expect(guestAccountReasonForBranch(branch, guest: false), isNull);
      }
    });
  });
}
