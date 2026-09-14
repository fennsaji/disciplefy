import 'package:disciplefy_bible_study/core/services/android_hybrid_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// flutter_secure_storage when EncryptedSharedPreferences cannot be opened
/// (e.g. its file was restored from a backup onto a reinstall): writes are
/// accepted and dropped, reads return null, and nothing throws.
class _UnopenableSecureStorage extends Fake implements FlutterSecureStorage {
  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {}

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      null;

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {}
}

class _WorkingSecureStorage extends Fake implements FlutterSecureStorage {
  final values = <String, String>{};

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      values[key];

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    values.remove(key);
  }
}

void main() {
  const session = '{"access_token":"a","refresh_token":"r"}';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
      'keeps the session when secure storage silently drops writes, '
      'so a cold start still finds it', () async {
    final prefs = await SharedPreferences.getInstance();
    final storage = AndroidHybridStorage.forTesting(
      secure: _UnopenableSecureStorage(),
      prefs: prefs,
    );

    await storage.persistSession(session);

    // A fresh instance over the same prefs stands in for the next launch.
    final nextLaunch = AndroidHybridStorage.forTesting(
      secure: _UnopenableSecureStorage(),
      prefs: prefs,
    );
    expect(await nextLaunch.hasAccessToken(), isTrue);
    expect(await nextLaunch.accessToken(), session);
  });

  test('stores only the encrypted copy when secure storage works', () async {
    final prefs = await SharedPreferences.getInstance();
    final secure = _WorkingSecureStorage();
    final storage =
        AndroidHybridStorage.forTesting(secure: secure, prefs: prefs);

    await storage.persistSession(session);

    expect(secure.values.values, contains(session));
    expect(
      prefs.getKeys().where((k) => prefs.get(k) == session),
      isEmpty,
      reason: 'no plaintext copy of the session should remain',
    );
  });

  test('sign-out removes the session from both stores', () async {
    final prefs = await SharedPreferences.getInstance();
    final storage = AndroidHybridStorage.forTesting(
      secure: _UnopenableSecureStorage(),
      prefs: prefs,
    );
    await storage.persistSession(session);

    await storage.removePersistedSession();

    expect(await storage.hasAccessToken(), isFalse);
  });
}
