import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:disciplefy_bible_study/core/models/bible_books_config.dart';
import 'package:disciplefy_bible_study/core/services/bible_books_service.dart';

/// Startup-path behaviour of [BibleBooksService.initialize].
///
/// Book names have static fallbacks, so startup must never wait for the
/// network: a cache is served as is, and a missing cache is filled in the
/// background.
void main() {
  const cacheKey = 'bible_books_config_v1';
  const cacheTimestampKey = 'bible_books_config_v1_timestamp';

  const config = BibleBooksConfig(
    english: ['Genesis'],
    hindi: ['उत्पत्ति'],
    malayalam: ['ഉല്പത്തി'],
    englishAbbreviations: ['Gen'],
    hindiAlternates: [],
    malayalamAlternates: [],
    version: 2,
  );

  /// A client whose `get-bible-books` call blocks on [gate] and counts calls.
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
            'data': {'data': config.toJson(), 'version': 2},
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
  }

  Future<void> waitFor(bool Function() condition) async {
    final deadline = DateTime.now().add(const Duration(seconds: 2));
    while (!condition() && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  group('BibleBooksService.initialize on the startup path', () {
    test('no cache: returns at once and fetches in the background', () async {
      SharedPreferences.setMockInitialValues({});
      final gate = Completer<void>();
      final calls = <int>[];
      final service = BibleBooksService(client: clientGatedOn(gate, calls));

      // The gate is still closed: initialize() must not be waiting on it.
      await service.initialize().timeout(const Duration(seconds: 1));

      await waitFor(() => calls.isNotEmpty);
      expect(calls, hasLength(1), reason: 'background fetch issued');

      gate.complete();
      final prefs = await SharedPreferences.getInstance();
      await waitFor(() => prefs.getString(cacheKey) != null);
      expect(prefs.getString(cacheKey), isNotNull,
          reason: 'background result is cached for the next launch');
    });

    test('cache present: served without any network call', () async {
      SharedPreferences.setMockInitialValues({
        cacheKey: jsonEncode(config.toJson()),
        cacheTimestampKey: DateTime.now()
                .subtract(const Duration(days: 90))
                .millisecondsSinceEpoch ~/
            1000,
      });
      final gate = Completer<void>();
      final calls = <int>[];
      final service = BibleBooksService(client: clientGatedOn(gate, calls));

      await service.initialize().timeout(const Duration(seconds: 1));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(calls, isEmpty);
    });

    test('concurrent refreshes share one request', () async {
      SharedPreferences.setMockInitialValues({});
      final gate = Completer<void>();
      final calls = <int>[];
      final service = BibleBooksService(client: clientGatedOn(gate, calls));

      final first = service.refreshInBackground();
      final second = service.refreshInBackground();
      gate.complete();
      await Future.wait([first, second]);

      expect(calls, hasLength(1));
    });
  });
}
