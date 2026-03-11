/// Stub implementation — returns null on platforms without calendar auth.
Future<String?> requestCalendarAccessToken(
  String clientId, {
  String? userEmail,
}) async =>
    null;
