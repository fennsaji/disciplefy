import 'package:disciplefy_bible_study/core/services/notification_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakePermissions implements NotificationPermissionPlatform {
  _FakePermissions({required this.granted, this.grantOnRequest = false});

  bool granted;
  final bool grantOnRequest;
  int requests = 0;

  @override
  Future<bool> isGranted() async => granted;

  @override
  Future<bool> request() async {
    requests++;
    if (grantOnRequest) granted = true;
    return granted;
  }
}

/// Regression (Android 13+, fresh install): the OS "Allow notifications?"
/// dialog opened on first launch, over the first-run language screen, because
/// startup requested the permission. Startup may only read it; the OS dialog
/// belongs to the in-app sheet's "Turn on".
void main() {
  late _FakePermissions permissions;
  late int pushStarts;

  NotificationService build() => NotificationService(
        supabaseClient: SupabaseClient('http://localhost', 'anon'),
        router: GoRouter(
          routes: [GoRoute(path: '/', builder: (_, __) => const SizedBox())],
        ),
        permissionPlatform: permissions,
        onPushPermitted: () async => pushStarts++,
      );

  setUp(() => pushStarts = 0);

  test('startup with permission not answered never asks the OS', () async {
    permissions = _FakePermissions(granted: false, grantOnRequest: true);

    final started = await build().startPushIfPermitted();

    expect(started, isFalse);
    expect(permissions.requests, 0);
    expect(pushStarts, 0);
  });

  test('startup with permission already granted registers silently', () async {
    permissions = _FakePermissions(granted: true);

    final started = await build().startPushIfPermitted();

    expect(started, isTrue);
    expect(permissions.requests, 0);
    expect(pushStarts, 1);
  });

  test('asking and being granted registers the token', () async {
    permissions = _FakePermissions(granted: false, grantOnRequest: true);

    final granted = await build().requestPermissions();

    expect(granted, isTrue);
    expect(permissions.requests, 1);
    expect(pushStarts, 1);
  });

  test('asking and being refused registers nothing', () async {
    permissions = _FakePermissions(granted: false);

    final granted = await build().requestPermissions();

    expect(granted, isFalse);
    expect(permissions.requests, 1);
    expect(pushStarts, 0);
  });
}
