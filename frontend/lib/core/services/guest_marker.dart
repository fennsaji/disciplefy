import 'dart:async';

import 'package:hive/hive.dart';

import 'package:disciplefy_bible_study/core/utils/logger.dart';

/// Remembers on this device that the person used the app as a guest.
///
/// A guest has no credentials to log back in with. If their session is lost
/// (the refresh token is gone), the router starts a new first run instead
/// of sending them to the login screen. The marker is set when a guest
/// session starts and cleared once a full account is signed in.
///
/// Stored as Hive `app_settings['was_guest']`. Every call is a no-op when
/// the box is not open, so it is safe in tests and early start-up.
class GuestMarker {
  GuestMarker._();

  static const String key = 'was_guest';
  static const String _boxName = 'app_settings';

  static Box? get _box => Hive.isBoxOpen(_boxName) ? Hive.box(_boxName) : null;

  /// True when this device last ran a guest session that never became a
  /// full account.
  static bool get wasGuest {
    try {
      return _box?.get(key, defaultValue: false) == true;
    } catch (_) {
      return false;
    }
  }

  /// Marks the device as having a guest session.
  static Future<void> markGuest() async {
    try {
      await _box?.put(key, true);
    } catch (e) {
      Logger.warning('Could not store the guest marker',
          tag: 'GUEST', context: {'error': e.runtimeType.toString()});
    }
  }

  /// Clears the marker (a full account is signed in).
  static Future<void> clear() async {
    try {
      final box = _box;
      if (box == null || !box.containsKey(key)) return;
      await box.delete(key);
      Logger.info('Guest marker cleared: full account signed in', tag: 'GUEST');
    } catch (e) {
      Logger.warning('Could not clear the guest marker',
          tag: 'GUEST', context: {'error': e.runtimeType.toString()});
    }
  }

  /// Keeps the marker in step with the signed-in user: cleared for a full
  /// account, left alone for a guest.
  static void syncWithUser({required bool isAnonymous}) {
    if (!isAnonymous && wasGuest) unawaited(clear());
  }
}
