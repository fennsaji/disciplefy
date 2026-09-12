import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../di/injection_container.dart';
import '../extensions/translation_extension.dart';
import '../i18n/translation_keys.dart';
import '../utils/logger.dart';
import '../../features/community/domain/repositories/community_repository.dart';

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
    // Match /fellowship/<fellowshipId>/post/<postId>
    if (segments.length >= 4 &&
        segments[0] == 'fellowship' &&
        segments[2] == 'post') {
      final fellowshipId = segments[1];
      final postId = segments[3];
      final uuidPattern = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      );
      if (!uuidPattern.hasMatch(fellowshipId) ||
          !uuidPattern.hasMatch(postId)) {
        Logger.warning('Invalid fellowship/post id in deep link: ${uri.path}',
            tag: _tag);
        return;
      }
      // Do not navigate yet: a shared link reaches people who are not in the
      // fellowship, and the fellowship screen cannot render for them — every
      // call it makes returns 403. Opening it anyway produced a half-drawn
      // screen with "0 members" and a red server-error toast. Decide first,
      // then either enter, offer to join, or say plainly that it is not open.
      unawaited(_openFellowshipPost(fellowshipId, postId));
      return;
    }
    // Match /learning-path/<pathId>
    //
    // This path is advertised as an App Link in AndroidManifest.xml and in
    // api/apple-app-site-association.js. Without a branch here the link
    // verified, opened the app, and then silently dropped the user on Home.
    if (segments.length >= 2 &&
        segments[0] == 'learning-path' &&
        segments[1].isNotEmpty) {
      final pathId = segments[1];
      // Path ids are UUIDs; anything else is a malformed or hostile link.
      final isValidId = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      ).hasMatch(pathId);
      if (!isValidId) {
        Logger.warning('Invalid learning path id in deep link: ${uri.path}',
            tag: _tag);
        return;
      }
      _router.go('/learning-path/$pathId');
      return;
    }

    // Match /daily-verse — no per-verse content to deep-link into, so this
    // just opens the app to Home.
    if (segments.length == 1 && segments[0] == 'daily-verse') {
      _router.go('/daily-verse');
      return;
    }

    // Match /study-guide/<guideId>
    if (segments.length >= 2 &&
        segments[0] == 'study-guide' &&
        segments[1].isNotEmpty) {
      final guideId = segments[1];
      final uuidPattern = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      );
      if (!uuidPattern.hasMatch(guideId)) {
        Logger.warning('Invalid study guide id in deep link: ${uri.path}',
            tag: _tag);
        return;
      }
      _router.go('/study-guide/$guideId');
      return;
    }

    Logger.warning('Unhandled deep link path: ${uri.path}', tag: _tag);
  }

  /// Opens a shared fellowship post, or explains why it cannot be opened.
  ///
  /// The fellowship lookup is the one endpoint a non-member may call for a
  /// given fellowship, so it is what decides between three outcomes: enter
  /// (already a member), offer to join (public), or decline politely (private).
  /// Whatever happens, the user is left where they were rather than inside a
  /// screen that cannot load.
  Future<void> _openFellowshipPost(String fellowshipId, String postId) async {
    final target = '/community/$fellowshipId/post/$postId';
    final repository = sl<CommunityRepository>();

    final result = await repository.getFellowship(fellowshipId, 'en');

    final fellowship = result.fold<Map<String, dynamic>?>((failure) {
      Logger.warning('Could not resolve shared fellowship: $failure',
          tag: _tag);
      return null;
    }, (data) => data);

    if (fellowship == null) {
      // Deleted, private to the point of being unreadable, or simply offline.
      // Either way there is nothing to show, and no reason to blame the user.
      _showMessage(TranslationKeys.fellowshipLinkUnavailable);
      return;
    }

    if (fellowship['caller_is_member'] == true) {
      _router.go(target);
      return;
    }

    if (fellowship['is_public'] == true) {
      await _offerToJoin(fellowshipId, fellowship['name'] as String?, target);
      return;
    }

    _showMessage(TranslationKeys.fellowshipLinkNotAMember);
  }

  /// Asks whether to join a public fellowship, and joins on confirmation.
  Future<void> _offerToJoin(
    String fellowshipId,
    String? name,
    String target,
  ) async {
    final context = _router.routerDelegate.navigatorKey.currentContext;
    if (context == null || !context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title:
            Text(dialogContext.tr(TranslationKeys.fellowshipJoinPromptTitle)),
        content: Text(
          dialogContext.tr(
            TranslationKeys.fellowshipJoinPromptBody,
            {
              'name':
                  name ?? dialogContext.tr(TranslationKeys.fellowshipThisGroup)
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.tr(TranslationKeys.commonCancel)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
                dialogContext.tr(TranslationKeys.fellowshipJoinPromptConfirm)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final joined =
        await sl<CommunityRepository>().joinPublicFellowship(fellowshipId);
    joined.fold(
      (failure) {
        Logger.warning('Join from shared link failed: $failure', tag: _tag);
        _showMessage(TranslationKeys.fellowshipJoinFailed);
      },
      (_) => _router.go(target),
    );
  }

  /// Shows a message without navigating, so the user keeps the screen they had.
  void _showMessage(String translationKey) {
    final context = _router.routerDelegate.navigatorKey.currentContext;
    if (context == null || !context.mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(context.tr(translationKey)),
        behavior: SnackBarBehavior.floating,
      ));
  }

  void dispose() {
    _linkSubscription?.cancel();
  }
}
