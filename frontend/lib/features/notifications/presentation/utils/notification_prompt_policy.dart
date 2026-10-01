import 'package:shared_preferences/shared_preferences.dart';

/// Decides whether the in-app "enable notifications" sheet may be shown.
///
/// Notifications are on by default, so the sheet is never about a category
/// preference (those live in Settings). Its only job is to recover a refused
/// OS/browser permission, and it does that at most once per install: the
/// "asked" flag is shared by every notification type and survives logout.
class NotificationPromptPolicy {
  /// SharedPreferences key recording that the sheet was already shown.
  /// Preserved across logout by the local store.
  static const String askedKey = 'notification_permission_prompt_asked';

  final SharedPreferences _prefs;

  const NotificationPromptPolicy(this._prefs);

  /// Whether the sheet was already shown on this install.
  bool get hasAsked => _prefs.getBool(askedKey) ?? false;

  /// Returns true only when the permission was explicitly refused and the
  /// sheet has never been shown. A granted permission never prompts, and an
  /// unanswered one is left to the system's own permission request.
  bool shouldShow({
    required bool permissionGranted,
    required bool permissionDenied,
  }) {
    if (permissionGranted || !permissionDenied) return false;
    return !hasAsked;
  }

  /// Records that the sheet was shown, however it is dismissed.
  Future<void> markAsked() => _prefs.setBool(askedKey, true);
}
