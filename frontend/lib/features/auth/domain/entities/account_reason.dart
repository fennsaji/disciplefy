/// Why a guest is asked to create an account.
///
/// [wireValue] is the reason string shared with the router's
/// `?account=<reason>` query and the backend's `ACCOUNT_REQUIRED`
/// `details.reason`.
enum AccountReason {
  generate('generate'),
  discipler('discipler'),
  community('community'),
  memoryVerses('memory_verses'),

  /// "Listen" (read aloud) in a lesson.
  listen('listen'),
  otherPath('other_path'),
  secondPath('second_path'),

  /// Sign-up nudges on "Lesson complete".
  saveProgress('save_progress'),

  /// Any other reason (an unknown value from a link or the server).
  other('other');

  final String wireValue;

  const AccountReason(this.wireValue);

  /// The reason for [value]. Null when [value] is null or blank; an unknown
  /// value becomes [other] so the generic copy is shown.
  static AccountReason? fromWire(String? value) {
    final v = value?.trim();
    if (v == null || v.isEmpty) return null;
    for (final reason in values) {
      if (reason.wireValue == v) return reason;
    }
    return other;
  }
}
