import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../utils/logger.dart';

/// Listens for incoming deep links (Android App Links) and navigates
/// to the correct screen via GoRouter.
///
/// Call [init] once from main() after [AppRouter.router] is created.
/// Call [dispose] when the app is torn down (rarely needed).
class DeepLinkService {
  static const _tag = 'DeepLinkService';

  final GoRouter _router;
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  DeepLinkService({required GoRouter router}) : _router = router;

  /// Starts listening for deep links and handles the initial (cold-start) link.
  Future<void> init() async {
    // Flutter web routing is handled natively by GoRouter — no action needed.
    if (kIsWeb) return;

    _appLinks = AppLinks();

    // Cold-start: app launched directly via a deep link tap.
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        Logger.info('Initial deep link: $initialUri', tag: _tag);
        _handleUri(initialUri);
      }
    } catch (e) {
      Logger.error('Failed to get initial deep link', tag: _tag, error: e);
    }

    // Warm-start: link received while app is already running.
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) {
        Logger.info('Incoming deep link: $uri', tag: _tag);
        _handleUri(uri);
      },
      onError: (err) {
        Logger.error('Deep link stream error', tag: _tag, error: err);
      },
    );
  }

  void _handleUri(Uri uri) {
    final segments = uri.pathSegments;
    // Match /fellowship/join/<token>
    if (segments.length >= 3 &&
        segments[0] == 'fellowship' &&
        segments[1] == 'join' &&
        segments[2].isNotEmpty) {
      final token = segments[2].toUpperCase();
      // Validate: alphanumeric only, 4–20 characters
      final isValidToken = RegExp(r'^[A-Z0-9]{4,20}$').hasMatch(token);
      if (!isValidToken) {
        Logger.warning(
            'Invalid fellowship token format in deep link: ${uri.path}',
            tag: _tag);
        return;
      }
      _router.go('/fellowship/join/$token');
      return;
    }
    Logger.warning('Unhandled deep link path: ${uri.path}', tag: _tag);
  }

  void dispose() {
    _linkSubscription?.cancel();
  }
}
