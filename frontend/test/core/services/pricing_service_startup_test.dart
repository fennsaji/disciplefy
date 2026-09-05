import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:disciplefy_bible_study/core/models/subscription_pricing.dart';
import 'package:disciplefy_bible_study/core/services/pricing_service.dart';

/// Startup-path behaviour of [PricingService.initialize].
///
/// Pricing is only read on upgrade/limit screens, never by the first frame, so
/// the startup call may only block when there is no cached pricing at all.
void main() {
  const cacheKey = 'subscription_pricing';
  const cacheTimestampKey = 'subscription_pricing_timestamp';

  final cachedPricingJson = jsonEncode(SubscriptionPricing.empty().toJson());

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
            'data': SubscriptionPricing.empty().toJson(),
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

  group('PricingService.initialize on the startup path', () {
    test('serves a stale cache without waiting for the refresh', () async {
      final staleSeconds = DateTime.now()
              .subtract(const Duration(hours: 6))
              .millisecondsSinceEpoch ~/
          1000;
      SharedPreferences.setMockInitialValues({
        cacheKey: cachedPricingJson,
        cacheTimestampKey: staleSeconds,
      });
      final gate = Completer<void>();
      final calls = <int>[];
      final service = PricingService(client: clientGatedOn(gate, calls));

      await service.initialize().timeout(const Duration(seconds: 2));

      await settleBackgroundCall(calls);
      expect(calls, hasLength(1), reason: 'refresh kicked off in background');
    });

    test('blocks on the fetch when nothing is cached (first launch)', () async {
      SharedPreferences.setMockInitialValues({});
      final gate = Completer<void>()..complete();
      final calls = <int>[];
      final service = PricingService(client: clientGatedOn(gate, calls));

      await service.initialize();

      expect(calls, hasLength(1));
    });
  });
}
