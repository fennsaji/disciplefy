import 'dart:io';

import 'package:disciplefy_bible_study/features/subscription/presentation/widgets/insufficient_tokens_dialog.dart';
import 'package:flutter_test/flutter_test.dart';

/// The insufficient-credits dialog quotes each plan's daily allowance. Those
/// numbers used to be inline literals and silently went stale when migration
/// 20260319000004 raised the limits, so the dialog advertised fewer credits
/// than the plans actually grant.
///
/// This pins the Dart map to the migration that is the source of truth.
void main() {
  test('kPlanDailyCredits matches the token-economy migration', () {
    final migration = File(
      '../backend/supabase/migrations/20260319000004_update_token_economy.sql',
    ).readAsStringSync();

    // One UPDATE statement per plan; parse each in isolation so a greedy
    // match cannot pair one plan's number with another plan's plan_code.
    final fromMigration = <String, int>{};
    for (final statement in migration.split(';')) {
      final tokens =
          RegExp(r"'\{daily_tokens\}', '(\d+)'").firstMatch(statement);
      final plan = RegExp(r"plan_code = '(\w+)'").firstMatch(statement);
      if (tokens != null && plan != null) {
        fromMigration[plan.group(1)!] = int.parse(tokens.group(1)!);
      }
    }

    expect(fromMigration, isNotEmpty, reason: 'parsed no plans from migration');

    for (final entry in kPlanDailyCredits.entries) {
      expect(
        fromMigration[entry.key],
        entry.value,
        reason:
            'kPlanDailyCredits["${entry.key}"] disagrees with the migration',
      );
    }
  });
}
