import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../utils/logger.dart';

/// API.Bible FUMS (Fair Use Management System) reporter.
///
/// API.Bible requires webapps to report a FUMS token for each Scripture view so
/// usage can be profiled back to copyright holders. Our verse fetches happen in
/// the backend, which returns the FUMS v3 token(s) in the response; this service
/// reports them from the client via the documented HTTP endpoint:
///   `https://fums.api.bible/f3?t={token}&dId={deviceId}&sId={sessionId}`
///
/// Reporting is best-effort and must never block or fail a verse display. On web,
/// a CORS error is expected when reading the response — the request still reaches
/// FUMS, so we simply swallow the error.
class FumsService {
  FumsService._();
  static final FumsService instance = FumsService._();

  static const String _endpoint = 'https://fums.api.bible/f3';
  static const String _deviceIdKey = 'fums_device_id';

  /// Regenerated each app session.
  final String _sessionId = const Uuid().v4();

  String? _deviceId;

  /// Persistent, anonymous device id (no PII). Generated once and stored.
  Future<String> _getDeviceId() async {
    if (_deviceId != null) return _deviceId!;
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_deviceIdKey);
    if (id == null) {
      id = const Uuid().v4();
      await prefs.setString(_deviceIdKey, id);
    }
    _deviceId = id;
    return id;
  }

  /// Reports one or more FUMS tokens (e.g. from a fetch-verse response).
  Future<void> trackView(List<String> tokens) async {
    if (tokens.isEmpty) return;
    try {
      final deviceId = await _getDeviceId();
      for (final token in tokens) {
        if (token.isEmpty) continue;
        final uri = Uri.parse(_endpoint).replace(queryParameters: {
          't': token,
          'dId': deviceId,
          'sId': _sessionId,
        });
        // Fire-and-forget; ignore failures (incl. expected web CORS read errors).
        http.get(uri).then((_) {}, onError: (Object _) {});
      }
    } catch (e) {
      Logger.debug('FUMS trackView skipped: $e');
    }
  }
}
