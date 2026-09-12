import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../extensions/translation_extension.dart';
import '../i18n/translation_keys.dart';
import '../localization/app_localizations.dart';
import '../theme/app_colors.dart';
import '../utils/logger.dart';

/// Address issue reports from this screen are sent to.
const String kSupportEmail = 'techsupport@disciplefy.in';

/// Full-screen error state, shown by the router for unmatched routes and by
/// features that navigate to [AppRoutes.error].
///
/// Beyond showing the message, it does two things the user cannot do for us:
/// it reports the failure to Crashlytics automatically (these errors were
/// previously invisible — the screen rendered and nothing was recorded), and it
/// offers a prefilled support email so a user can report what they hit.
class ErrorPage extends StatefulWidget {
  final String? error;

  /// Stack trace, when the caller has one. Included in the Crashlytics report
  /// and in the support email.
  final StackTrace? stackTrace;

  /// Where the error happened — a route, screen name or operation. Falls back
  /// to the current route when not supplied.
  final String? location;

  const ErrorPage({
    super.key,
    this.error,
    this.stackTrace,
    this.location,
  });

  @override
  State<ErrorPage> createState() => _ErrorPageState();
}

class _ErrorPageState extends State<ErrorPage> {
  /// When the failure was surfaced — captured once so the report and the email
  /// agree, rather than using "now" at the moment the user taps Report.
  late final DateTime _occurredAt = DateTime.now();

  String? _resolvedLocation;

  @override
  void initState() {
    super.initState();
    // Report after the first frame so the route is resolvable and reporting can
    // never interfere with rendering the error screen itself.
    WidgetsBinding.instance.addPostFrameCallback((_) => _reportToCrashlytics());
  }

  /// Records the failure as a non-fatal Crashlytics issue.
  ///
  /// Non-fatal because the app is still running and the user can continue —
  /// but it is recorded, since this screen previously swallowed every error it
  /// displayed, leaving no trace of routing failures or unexpected states.
  Future<void> _reportToCrashlytics() async {
    _resolvedLocation = widget.location ?? _currentRoute();

    if (kDebugMode) {
      Logger.error(
        '[ErrorPage] ${widget.error ?? 'Unknown error'} at ${_resolvedLocation ?? 'unknown'}',
      );
      return; // Keep debug runs out of the production Crashlytics stream
    }

    try {
      final crashlytics = FirebaseCrashlytics.instance;
      await crashlytics.setCustomKey(
          'error_location', _resolvedLocation ?? 'unknown');
      await crashlytics.setCustomKey(
          'error_occurred_at', _occurredAt.toIso8601String());
      // Non-fatal (the default): the app is still running and the user can
      // continue from this screen.
      await crashlytics.recordError(
        widget.error ?? 'ErrorPage shown without an error message',
        widget.stackTrace,
        reason: 'ErrorPage displayed',
      );
    } catch (e) {
      // Reporting must never break the error screen.
      Logger.error('[ErrorPage] Failed to report error', error: e);
    }
  }

  String? _currentRoute() {
    try {
      return GoRouterState.of(context).matchedLocation;
    } catch (_) {
      return null; // Not always available (e.g. shown outside a router context)
    }
  }

  /// Opens the user's email client with a prefilled report.
  ///
  /// Everything a support engineer needs is filled in — what failed, where,
  /// when, the stack trace, and the app/platform build — so the user only has
  /// to describe what they were doing.
  Future<void> _reportIssue() async {
    final l10n = AppLocalizations.of(context);
    final body = await _buildReportBody();
    if (!mounted) return;

    final uri = Uri(
      scheme: 'mailto',
      path: kSupportEmail,
      query: _encodeQuery({
        'subject': 'Disciplefy issue report: ${_shortError()}',
        'body': body,
      }),
    );

    try {
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) throw Exception('launchUrl returned false');
    } catch (e) {
      Logger.error('[ErrorPage] Could not open email client', error: e);
      if (!mounted) return;
      // Show the address so the report is not a dead end on devices with no
      // mail app configured.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n?.errorPageReportUnavailable ??
              'No email app found. Please write to $kSupportEmail'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  /// `Uri(queryParameters:)` encodes spaces as '+', which mail clients show
  /// literally in the subject and body. Percent-encoding keeps them as spaces.
  String _encodeQuery(Map<String, String> params) => params.entries
      .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
      .join('&');

  String _shortError() {
    final raw = (widget.error ?? 'Unexpected error').replaceAll('\n', ' ');
    return raw.length > 60 ? '${raw.substring(0, 60)}…' : raw;
  }

  Future<String> _buildReportBody() async {
    final buffer = StringBuffer()
      ..writeln('Please describe what you were doing when this happened:')
      ..writeln()
      ..writeln()
      ..writeln('---------- technical details ----------')
      ..writeln('Error: ${widget.error ?? 'Unknown error'}')
      ..writeln(
          'Where: ${_resolvedLocation ?? widget.location ?? _currentRoute() ?? 'unknown'}')
      ..writeln('When: ${_occurredAt.toIso8601String()}');

    try {
      final info = await PackageInfo.fromPlatform();
      buffer.writeln('App: ${info.version} (${info.buildNumber})');
    } catch (_) {
      // Version is a nice-to-have; never block the report on it.
    }

    buffer.writeln('Platform: ${kIsWeb ? 'web' : defaultTargetPlatform.name}');

    if (widget.stackTrace != null) {
      buffer
        ..writeln()
        ..writeln('Stack trace:')
        ..writeln(_trimStackTrace(widget.stackTrace!));
    }

    return buffer.toString();
  }

  /// Mail clients (and some OSes) silently drop very long mailto URLs, so send
  /// the top frames — which is where the cause almost always is.
  String _trimStackTrace(StackTrace trace) {
    const maxLines = 30;
    final lines = trace.toString().split('\n');
    if (lines.length <= maxLines) return trace.toString();
    return '${lines.take(maxLines).join('\n')}\n… (${lines.length - maxLines} more frames)';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // If localization is not ready, show basic error page
    if (l10n == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Error'),
          leading: IconButton(
            icon: const Icon(Icons.home),
            onPressed: () => context.go('/'),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 80,
                  color: context.appError,
                ),
                const SizedBox(height: 24),
                Text(
                  context.tr(TranslationKeys.commonErrorTryAgain),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: context.appError,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Please try again later.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 24),
                TextButton.icon(
                  onPressed: _reportIssue,
                  icon: const Icon(Icons.mail_outline),
                  label: const Text('Report this issue'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.errorPageTitle),
        leading: IconButton(
          icon: const Icon(Icons.home),
          onPressed: () => context.go('/'),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 80,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 24),
              Text(
                l10n.errorTitle,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                _getErrorMessage(context),
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.home),
                label: Text(l10n.continueButton),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  // Go back to home and retry
                  context.go('/');
                },
                child: Text(l10n.retryButton),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _reportIssue,
                icon: const Icon(Icons.mail_outline, size: 18),
                label: Text(l10n.errorPageReportButton),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getErrorMessage(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (widget.error == null) return l10n.errorMessage;

    final error = widget.error!.toLowerCase();

    // Categorize error types
    if (error.contains('network') || error.contains('connection')) {
      return l10n.errorPageNetwork;
    }

    if (error.contains('server') ||
        error.contains('500') ||
        error.contains('503')) {
      return l10n.errorPageServer;
    }

    return l10n.errorPageUnknown;
  }
}
