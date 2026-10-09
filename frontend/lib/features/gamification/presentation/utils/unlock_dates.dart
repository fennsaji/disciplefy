/// Date labels for achievement unlock times.
///
/// Unlock times arrive from the server in UTC. They are converted to the
/// user's local time before the calendar day is taken, so an achievement
/// unlocked late in the UTC day is still "Today" for users ahead of UTC.
library;

typedef ToLocal = DateTime Function(DateTime instant);

DateTime _deviceLocal(DateTime instant) => instant.toLocal();

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Whole local calendar days from [unlockedAt] to [now].
///
/// [now] is a local wall-clock time. [toLocal] converts the unlock instant to
/// local wall-clock time and defaults to the device time zone.
int unlockDaysAgo(DateTime unlockedAt,
    {required DateTime now, ToLocal? toLocal}) {
  final local = (toLocal ?? _deviceLocal)(unlockedAt);
  // Compare calendar days in UTC so a daylight-saving shift can't make a
  // 23-hour day count as zero days.
  return DateTime.utc(now.year, now.month, now.day)
      .difference(DateTime.utc(local.year, local.month, local.day))
      .inDays;
}

/// "Today", "Yesterday", "N days ago", or d/m/yyyy after a week.
String relativeUnlockLabel(
  DateTime unlockedAt, {
  required DateTime now,
  required String today,
  required String yesterday,
  required String daysAgo,
  ToLocal? toLocal,
}) {
  final days = unlockDaysAgo(unlockedAt, now: now, toLocal: toLocal);
  if (days <= 0) return today;
  if (days == 1) return yesterday;
  if (days < 7) return '$days $daysAgo';
  final local = (toLocal ?? _deviceLocal)(unlockedAt);
  return '${local.day}/${local.month}/${local.year}';
}

/// "Oct 7, 2026" on the user's local calendar.
String formatUnlockDate(DateTime unlockedAt, {ToLocal? toLocal}) {
  final local = (toLocal ?? _deviceLocal)(unlockedAt);
  return '${_months[local.month - 1]} ${local.day}, ${local.year}';
}
