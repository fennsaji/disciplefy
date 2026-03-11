import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

// In-memory token cache — GIS tokens are valid for ~1 hour.
String? _cachedToken;
DateTime? _tokenExpiry;

/// Returns the cached token if still valid (with a 2-minute safety buffer).
String? _validCachedToken() {
  if (_cachedToken == null || _tokenExpiry == null) return null;
  if (DateTime.now()
      .isAfter(_tokenExpiry!.subtract(const Duration(minutes: 2)))) {
    _cachedToken = null;
    _tokenExpiry = null;
    return null;
  }
  return _cachedToken;
}

/// Requests a Google Calendar access token via the GIS Token Client.
///
/// Caches the token for its ~1 hour lifetime — subsequent calls within that
/// window return immediately without any popup. After expiry the popup is
/// shown again (consent is never re-asked; Google only shows account picker).
///
/// [userEmail] is passed as `hint` so Google pre-selects the correct account.
Future<String?> requestCalendarAccessToken(
  String clientId, {
  String? userEmail,
}) async {
  // Return cached token if still valid — no popup shown.
  final cached = _validCachedToken();
  if (cached != null) return cached;

  final completer = Completer<String?>();

  final config = JSObject();
  config['client_id'] = clientId.toJS;
  config['scope'] = 'https://www.googleapis.com/auth/calendar.events'.toJS;
  if (userEmail != null) config['hint'] = userEmail.toJS;
  config['callback'] = ((JSObject response) {
    final error = response.getProperty<JSAny?>('error'.toJS);
    if (error != null && error.toString().isNotEmpty) {
      completer.complete(null);
    } else {
      final token = response.getProperty<JSAny?>('access_token'.toJS);
      final tokenStr = token?.dartify() as String?;
      if (tokenStr != null && tokenStr.isNotEmpty) {
        // Cache for 1 hour (standard GIS token lifetime).
        _cachedToken = tokenStr;
        _tokenExpiry = DateTime.now().add(const Duration(hours: 1));
        completer.complete(tokenStr);
      } else {
        completer.complete(null);
      }
    }
  }).toJS;

  try {
    final google = globalContext.getProperty<JSObject?>('google'.toJS);
    final accounts = google?.getProperty<JSObject?>('accounts'.toJS);
    final oauth2 = accounts?.getProperty<JSObject?>('oauth2'.toJS);
    if (oauth2 == null) {
      completer.complete(null);
      return completer.future;
    }
    final tokenClient =
        oauth2.callMethod<JSObject>('initTokenClient'.toJS, config);
    tokenClient.callMethod<JSAny?>('requestAccessToken'.toJS);
  } catch (_) {
    completer.complete(null);
  }

  return completer.future;
}
