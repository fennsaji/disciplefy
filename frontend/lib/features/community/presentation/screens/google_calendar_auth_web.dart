import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

// In-memory token cache keyed by user email — GIS tokens are valid for ~1 hour.
// Keying by email ensures a cached token from one account is never returned
// for a different account.
String? _cachedEmail;
String? _cachedToken;
DateTime? _tokenExpiry;

/// Returns the cached token if it belongs to [userEmail] and is still valid
/// (with a 2-minute safety buffer).
String? _validCachedToken(String? userEmail) {
  if (_cachedToken == null || _tokenExpiry == null) return null;
  if (_cachedEmail != userEmail) {
    // Different user — discard cache.
    _cachedToken = null;
    _cachedEmail = null;
    _tokenExpiry = null;
    return null;
  }
  if (DateTime.now()
      .isAfter(_tokenExpiry!.subtract(const Duration(minutes: 2)))) {
    _cachedToken = null;
    _cachedEmail = null;
    _tokenExpiry = null;
    return null;
  }
  return _cachedToken;
}

/// Requests a Google Calendar access token via the GIS Token Client.
///
/// [userEmail] is set as `login_hint` so Google pre-selects (and effectively
/// locks) the account picker to the user already signed into the app.
/// The cache is keyed by [userEmail] so a token granted for one account is
/// never reused for another.
Future<String?> requestCalendarAccessToken(
  String clientId, {
  String? userEmail,
}) async {
  // Return cached token if still valid for this user — no popup shown.
  final cached = _validCachedToken(userEmail);
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
        // Cache keyed by email for 1 hour (standard GIS token lifetime).
        _cachedToken = tokenStr;
        _cachedEmail = userEmail;
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
