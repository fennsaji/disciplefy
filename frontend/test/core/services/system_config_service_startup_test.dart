import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:disciplefy_bible_study/core/services/system_config_service.dart';

/// Startup-path behaviour of [SystemConfigService.initialize].
///
/// `initialize()` runs before `runApp()`, so every millisecond it awaits is
/// native splash time. These tests pin down when it may block on the network
/// (first launch, nothing cached) and when it must not (a cache exists, even a
/// stale one or one tagged with a user whose session is still being restored).
void main() {
  const cacheKey = 'system_config_cache';
  const cacheTimestampKey = 'system_config_cache_timestamp';
  const cacheUserKey = 'system_config_cache_user';

  /// Serialised config the way `_saveToCache` writes it.
  final cachedConfigJson = jsonEncode(SystemConfig.fromJson({
    'featureFlags': {
      'learning_paths': {'enabled': true, 'plans': [], 'displayMode': 'hide'},
    },
  }).toJson());

  /// A client whose `system-config` call blocks on [gate] and counts calls.
  /// Never completing [gate] proves a caller did not await the request.
  SupabaseClient clientGatedOn(Completer<void> gate, List<int> calls) {
    return SupabaseClient(
      'http://localhost',
      'test-anon-key',
      httpClient: MockClient((request) async {
        calls.add(1);
        await gate.future;
        return http.Response(
          jsonEncode({
            'success': true,
            'data': SystemConfig.fromJson({
              'featureFlags': {
                'fresh_flag': {
                  'enabled': true,
                  'plans': [],
                  'displayMode': 'hide'
                },
              },
            }).toJson(),
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  }

  /// The background refresh is fire-and-forget, so give it a bounded moment to
  /// reach the HTTP layer before asserting it was issued.
  Future<void> settleBackgroundCall(List<int> calls) async {
    final deadline = DateTime.now().add(const Duration(seconds: 1));
    while (calls.isEmpty && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  group('SystemConfigService.initialize on the startup path', () {
    test('serves a stale cache without waiting for the refresh', () async {
      final staleMs = DateTime.now()
          .subtract(const Duration(hours: 6))
          .millisecondsSinceEpoch;
      SharedPreferences.setMockInitialValues({
        cacheKey: cachedConfigJson,
        cacheTimestampKey: staleMs,
      });
      final gate = Completer<void>();
      final calls = <int>[];
      final service = SystemConfigService(client: clientGatedOn(gate, calls));

      await service.initialize().timeout(const Duration(seconds: 2));

      expect(service.config, isNotNull, reason: 'stale cache is the fallback');
      expect(
          service.config!.featureFlags.containsKey('learning_paths'), isTrue);
      expect(service.isInitialized, isTrue);
      await settleBackgroundCall(calls);
      expect(calls, hasLength(1), reason: 'refresh kicked off in background');
    });

    test('keeps a user-tagged cache while the session is still restoring',
        () async {
      // Cold start >1h idle: the cache was saved by a signed-in user, but
      // Supabase has not finished recovering the session yet, so currentUser
      // is null. That is not a different identity — it is an unknown one.
      SharedPreferences.setMockInitialValues({
        cacheKey: cachedConfigJson,
        cacheTimestampKey: DateTime.now().millisecondsSinceEpoch,
        cacheUserKey: 'user-a',
      });
      final gate = Completer<void>();
      final calls = <int>[];
      final service = SystemConfigService(client: clientGatedOn(gate, calls));

      await service.initialize().timeout(const Duration(seconds: 2));

      expect(service.config, isNotNull,
          reason: 'must not throw away the only config we have');
      await settleBackgroundCall(calls);
      expect(calls, isEmpty,
          reason: 'cache is fresh and was resolved for this same user — '
              'no network call belongs on the startup path');
    });

    test('blocks on the fetch when nothing is cached (first launch)', () async {
      SharedPreferences.setMockInitialValues({});
      final gate = Completer<void>()..complete();
      final calls = <int>[];
      final service = SystemConfigService(client: clientGatedOn(gate, calls));

      await service.initialize();

      expect(calls, hasLength(1));
      expect(service.config, isNotNull);
      expect(service.config!.featureFlags.containsKey('fresh_flag'), isTrue,
          reason: 'first launch has no fallback, so the fetch must complete');
    });
  });
}
