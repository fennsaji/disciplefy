import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:disciplefy_bible_study/core/services/rollout_flags.dart';
import 'package:disciplefy_bible_study/core/services/system_config_service.dart';

/// A system-config service whose backend answers with [flags()] at call time.
SystemConfigService serviceReturning(
    Map<String, dynamic> Function() flags, List<int> calls) {
  return SystemConfigService(
    client: SupabaseClient(
      'http://localhost',
      'test-anon-key',
      httpClient: MockClient((request) async {
        calls.add(1);
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {'featureFlags': flags()},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    ),
  );
}

Map<String, dynamic> flag(bool enabled, [List<String> plans = const []]) =>
    {'enabled': enabled, 'plans': plans, 'displayMode': 'hide'};

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a switch reads only its enabled state, not its plans', () async {
    final calls = <int>[];
    final config = serviceReturning(
        () => {
              'new_first_run': flag(true),
              'guest_mode': flag(true, ['premium']),
              'home_today_layout': flag(false, ['free']),
            },
        calls);
    await config.fetchSystemConfig(forceRefresh: true);
    final flags = RolloutFlags(config);

    expect(flags.newFirstRun, isTrue);
    expect(flags.guestMode, isTrue);
    expect(flags.homeTodayLayout, isFalse);
    // No row: off.
    expect(flags.generateSingleInput, isFalse);
  });

  test('off before any config has loaded', () {
    final flags = RolloutFlags(serviceReturning(() => {}, []));
    expect(flags.newFirstRun, isFalse);
    expect(flags.guestMode, isFalse);
  });

  test('notifies when a refetch flips a switch, not on an unchanged refetch',
      () async {
    var on = false;
    final config = serviceReturning(
        () => {
              'home_today_layout': flag(on, ['free']),
              'learning_paths': flag(true, ['free']),
            },
        []);
    await config.fetchSystemConfig(forceRefresh: true);
    final flags = RolloutFlags(config);
    var notified = 0;
    flags.addListener(() => notified++);

    await config.fetchSystemConfig(forceRefresh: true);
    expect(notified, 0);

    on = true; // admin toggles it on
    await config.fetchSystemConfig(forceRefresh: true);
    expect(flags.homeTodayLayout, isTrue);
    expect(notified, 1);

    flags.dispose();
  });

  test('refreshIfStale skips a fresh config and fetches a missing one',
      () async {
    final calls = <int>[];
    final config = serviceReturning(() => {}, calls);

    await config.refreshIfStale();
    expect(calls, hasLength(1));

    await config.refreshIfStale();
    expect(calls, hasLength(1));
  });
}
