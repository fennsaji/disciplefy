import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mockito/mockito.dart';

import 'package:disciplefy_bible_study/core/config/app_config.dart';
import 'package:disciplefy_bible_study/core/services/api_auth_helper.dart';

import 'api_auth_helper_test.mocks.dart';

/// Anonymous requests must not wait for a session that is not coming.
void main() {
  late MockSupabaseClient client;
  late MockGoTrueClient auth;
  late Directory hiveDir;

  setUpAll(() async {
    hiveDir = await Directory.systemTemp.createTemp('anon_headers');
    Hive.init(hiveDir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDir.delete(recursive: true);
  });

  setUp(() {
    client = MockSupabaseClient();
    auth = MockGoTrueClient();
    when(client.auth).thenReturn(auth);
    when(auth.currentSession).thenReturn(null);
    ApiAuthHelper.clientOverride = client;
  });

  tearDown(() {
    ApiAuthHelper.clientOverride = null;
    ApiAuthHelper.sessionPendingOverride = null;
  });

  test('no pending session: anon headers without retrying', () async {
    ApiAuthHelper.sessionPendingOverride = () async => false;
    final sw = Stopwatch()..start();
    final headers = await ApiAuthHelper.getAuthHeaders();
    sw.stop();

    expect(headers['Authorization'], 'Bearer ${AppConfig.supabaseAnonKey}');
    expect(headers['x-session-id'], isNotEmpty);
    expect(sw.elapsedMilliseconds, lessThan(400));
    verify(auth.currentSession).called(1);
  });

  test('pending session: keeps retrying as before', () async {
    ApiAuthHelper.sessionPendingOverride = () async => true;
    final headers = await ApiAuthHelper.getAuthHeaders(
      retryDelay: const Duration(milliseconds: 1),
    );

    expect(headers['Authorization'], 'Bearer ${AppConfig.supabaseAnonKey}');
    verify(auth.currentSession).called(3);
  });
}
