import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// Memory Verse Notification Service.
///
/// Handles all notification types for memory verses:
/// 1. Daily Practice Reminder - 9 AM if due verses exist
/// 2. Streak At Risk - 8 PM if not practiced today
/// 3. Daily Goal Achievement - Immediate when completed
/// 4. Mastery Level Up - Immediate celebration
/// 5. Milestone Approaching - 2 days before milestone
/// 6. Challenge Completion - Immediate with XP reward
/// 7. New Challenge Available - Monday morning
class MemoryVerseNotificationService {
  final FlutterLocalNotificationsPlugin _localNotifications;

  MemoryVerseNotificationService(this._localNotifications);

  // Notification IDs
  static const int _dailyPracticeId = 1000;
  static const int _streakAtRiskId = 1001;
  static const int _dailyGoalId = 1002;
  static const int _masteryLevelUpId = 1003;
  static const int _milestoneApproachingId = 1004;
  static const int _challengeCompletionId = 1005;
  static const int _newChallengeId = 1006;

  // Notification channels
  static const _reminderChannelId = 'memory_verse_reminders';
  static const _achievementChannelId = 'memory_verse_achievements';

  /// Schedule daily practice reminder at 9 AM.
  ///
  /// Only schedules if user has due verses.
  Future<void> scheduleDailyPracticeReminder({
    required int dueVersesCount,
  }) async {
    if (dueVersesCount == 0) return;

    final scheduledTime = _getTodayAt(9, 0);

    const androidDetails = AndroidNotificationDetails(
      _reminderChannelId,
      'Memory Verse Reminders',
      channelDescription: 'Daily practice and streak reminders',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.zonedSchedule(
      _dailyPracticeId,
      '📚 Time to Practice!',
      'You have $dueVersesCount verses ready for review',
      tz.TZDateTime.from(scheduledTime, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Schedule streak at risk notification at 8 PM.
  ///
  /// Only schedules if user hasn't practiced today.
  Future<void> scheduleStreakAtRiskNotification({
    required int currentStreak,
    required bool practicedToday,
  }) async {
    if (practicedToday) return;

    final scheduledTime = _getTodayAt(20, 0);

    const androidDetails = AndroidNotificationDetails(
      _reminderChannelId,
      'Memory Verse Reminders',
      channelDescription: 'Daily practice and streak reminders',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.zonedSchedule(
      _streakAtRiskId,
      '🔥 Keep Your Streak Alive!',
      '$currentStreak-day streak needs you. Practice now?',
      tz.TZDateTime.from(scheduledTime, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Show immediate notification for daily goal achievement.
  Future<void> showDailyGoalAchievedNotification({
    required int xpEarned,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _achievementChannelId,
      'Memory Verse Achievements',
      channelDescription: 'Achievements and milestones',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      _dailyGoalId,
      '🎯 Daily Goal Complete!',
      'You earned $xpEarned XP. Keep it up!',
      details,
    );
  }

  /// Show immediate notification for mastery level up.
  Future<void> showMasteryLevelUpNotification({
    required String verseReference,
    required String masteryLevel,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _achievementChannelId,
      'Memory Verse Achievements',
      channelDescription: 'Achievements and milestones',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      _masteryLevelUpId,
      '⬆️ Level Up!',
      '$verseReference reached $masteryLevel mastery!',
      details,
    );
  }

  /// Schedule milestone approaching notification 2 days before.
  Future<void> scheduleMilestoneApproachingNotification({
    required int milestoneDays,
    required DateTime milestoneDate,
  }) async {
    final notificationDate = milestoneDate.subtract(const Duration(days: 2));

    const androidDetails = AndroidNotificationDetails(
      _achievementChannelId,
      'Memory Verse Achievements',
      channelDescription: 'Achievements and milestones',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.zonedSchedule(
      _milestoneApproachingId,
      '🏆 Milestone Ahead!',
      '2 days to your $milestoneDays-day streak!',
      tz.TZDateTime.from(notificationDate, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Show immediate notification for challenge completion.
  Future<void> showChallengeCompletionNotification({
    required String challengeName,
    required int xpEarned,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _achievementChannelId,
      'Memory Verse Achievements',
      channelDescription: 'Achievements and milestones',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      _challengeCompletionId,
      '✅ Challenge Complete!',
      'Earned $xpEarned XP from $challengeName',
      details,
    );
  }

  /// Schedule new challenge notification for Monday morning.
  Future<void> scheduleNewChallengeNotification() async {
    final nextMonday = _getNextMonday();

    const androidDetails = AndroidNotificationDetails(
      _achievementChannelId,
      'Memory Verse Achievements',
      channelDescription: 'Achievements and milestones',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.zonedSchedule(
      _newChallengeId,
      '🎯 New Weekly Challenge!',
      'Ready for this week\'s memory challenge?',
      tz.TZDateTime.from(nextMonday.add(const Duration(hours: 9)), tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Cancel all memory verse notifications.
  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancel(_dailyPracticeId);
    await _localNotifications.cancel(_streakAtRiskId);
    await _localNotifications.cancel(_dailyGoalId);
    await _localNotifications.cancel(_masteryLevelUpId);
    await _localNotifications.cancel(_milestoneApproachingId);
    await _localNotifications.cancel(_challengeCompletionId);
    await _localNotifications.cancel(_newChallengeId);
  }

  /// Cancel streak at risk notification (when user practices).
  Future<void> cancelStreakAtRiskNotification() async {
    await _localNotifications.cancel(_streakAtRiskId);
  }

  // Helper methods

  DateTime _getTodayAt(int hour, int minute) {
    final now = DateTime.now();
    final scheduledTime = DateTime(now.year, now.month, now.day, hour, minute);

    // If the time has passed today, schedule for tomorrow
    if (scheduledTime.isBefore(now)) {
      return scheduledTime.add(const Duration(days: 1));
    }

    return scheduledTime;
  }

  DateTime _getNextMonday() {
    final now = DateTime.now();
    final daysUntilMonday = (DateTime.monday - now.weekday + 7) % 7;
    final nextMonday =
        now.add(Duration(days: daysUntilMonday == 0 ? 7 : daysUntilMonday));

    return DateTime(
      nextMonday.year,
      nextMonday.month,
      nextMonday.day,
      9,
    );
  }
}
