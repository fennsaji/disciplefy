import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Platform checks that are safe to call on web builds
/// (dart:io Platform throws on web unless guarded by kIsWeb).
class PlatformUtils {
  const PlatformUtils._();

  /// True only on native iOS/iPadOS builds.
  /// Used to hide features Apple's App Store guidelines disallow
  /// (external donation links, non-IAP promo code redemption — guideline 3.1.1).
  static bool get isIOS => !kIsWeb && Platform.isIOS;
}
