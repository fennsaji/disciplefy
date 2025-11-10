// ============================================================================
// TimeOfDay Extensions
// ============================================================================
// Conversion extensions between Flutter's TimeOfDay and domain's TimeOfDayVO.
// These extensions handle the framework boundary, keeping domain layer clean.

import 'package:flutter/material.dart';
import '../../domain/entities/time_of_day_vo.dart';

/// Extension methods for converting between Flutter TimeOfDay and TimeOfDayVO.
///
/// **Usage in Presentation Layer:**
/// These extensions should ONLY be used in the presentation layer (UI widgets,
/// BLoCs) to convert between Flutter's framework-dependent TimeOfDay and the
/// domain's framework-agnostic TimeOfDayVO.
///
/// **Example:**
/// ```dart
/// // Converting from Flutter TimeOfDay to domain TimeOfDayVO
/// TimeOfDay flutterTime = await showTimePicker(...);
/// TimeOfDayVO domainTime = flutterTime.toTimeOfDayVO();
///
/// // Converting from domain TimeOfDayVO to Flutter TimeOfDay
/// TimeOfDayVO domainTime = preferences.streakReminderTime;
/// TimeOfDay flutterTime = domainTime.toFlutterTimeOfDay();
/// ```
extension TimeOfDayToVOExtension on TimeOfDay {
  /// Converts Flutter's TimeOfDay to domain's TimeOfDayVO.
  ///
  /// Use this when passing time data from UI (TimePicker) to domain use cases.
  ///
  /// **Example:**
  /// ```dart
  /// final pickedTime = await showTimePicker(context: context, initialTime: TimeOfDay.now());
  /// if (pickedTime != null) {
  ///   final domainTime = pickedTime.toTimeOfDayVO();
  ///   // Pass domainTime to use case
  /// }
  /// ```
  TimeOfDayVO toTimeOfDayVO() {
    return TimeOfDayVO(hour: hour, minute: minute);
  }
}

extension TimeOfDayVOToFlutterExtension on TimeOfDayVO {
  /// Converts domain's TimeOfDayVO to Flutter's TimeOfDay.
  ///
  /// Use this when displaying time data from domain entities in Flutter UI widgets.
  ///
  /// **Example:**
  /// ```dart
  /// final domainTime = notificationPreferences.streakReminderTime;
  /// final flutterTime = domainTime.toFlutterTimeOfDay();
  /// // Use flutterTime in TimePicker or display in Text widget
  /// Text('Reminder: ${flutterTime.format(context)}')
  /// ```
  TimeOfDay toFlutterTimeOfDay() {
    return TimeOfDay(hour: hour, minute: minute);
  }
}
