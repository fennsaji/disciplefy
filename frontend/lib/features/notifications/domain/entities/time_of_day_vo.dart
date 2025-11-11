// ============================================================================
// Time of Day Value Object
// ============================================================================
// Framework-agnostic value object representing a time of day.
// This keeps the domain layer independent of Flutter framework.

import 'package:equatable/equatable.dart';

/// Framework-agnostic time of day value object.
///
/// Represents a time of day with hour (0-23) and minute (0-59) components,
/// without any dependency on Flutter's TimeOfDay class.
///
/// **Usage in Domain Layer:**
/// Use this value object in all domain entities, use cases, and repository
/// interfaces to maintain framework independence.
///
/// **Conversion at Boundaries:**
/// Convert to/from Flutter's TimeOfDay only at presentation and data layer
/// boundaries using extension methods or mappers.
///
/// **Example:**
/// ```dart
/// // Domain layer usage
/// final reminderTime = TimeOfDayVO(hour: 9, minute: 30);
///
/// // Presentation layer conversion (Flutter TimeOfDay -> TimeOfDayVO)
/// final vo = TimeOfDayVO.fromFlutterTimeOfDay(flutterTimeOfDay);
///
/// // Presentation layer conversion (TimeOfDayVO -> Flutter TimeOfDay)
/// final flutterTime = vo.toFlutterTimeOfDay();
/// ```
class TimeOfDayVO extends Equatable {
  /// Hour of the day (0-23)
  final int hour;

  /// Minute of the hour (0-59)
  final int minute;

  /// Creates a time of day value object.
  ///
  /// **Parameters:**
  /// - [hour] - Hour of the day, must be between 0 and 23 (inclusive)
  /// - [minute] - Minute of the hour, must be between 0 and 59 (inclusive)
  ///
  /// **Throws:**
  /// - [ArgumentError] if hour is not in range 0-23
  /// - [ArgumentError] if minute is not in range 0-59
  const TimeOfDayVO({
    required this.hour,
    required this.minute,
  })  : assert(hour >= 0 && hour <= 23, 'Hour must be between 0 and 23'),
        assert(minute >= 0 && minute <= 59, 'Minute must be between 0 and 59');

  /// Creates a TimeOfDayVO from hour and minute integers with validation.
  ///
  /// **Throws:**
  /// - [ArgumentError] if hour or minute are out of valid range
  factory TimeOfDayVO.fromInts(int hour, int minute) {
    if (hour < 0 || hour > 23) {
      throw ArgumentError('Hour must be between 0 and 23, got: $hour');
    }
    if (minute < 0 || minute > 59) {
      throw ArgumentError('Minute must be between 0 and 59, got: $minute');
    }
    return TimeOfDayVO(hour: hour, minute: minute);
  }

  /// Formats the time as HH:MM string (24-hour format).
  ///
  /// **Example:**
  /// ```dart
  /// TimeOfDayVO(hour: 9, minute: 30).format() // "09:30"
  /// TimeOfDayVO(hour: 14, minute: 5).format() // "14:05"
  /// ```
  String format() {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// Returns a 12-hour format string with AM/PM.
  ///
  /// **Example:**
  /// ```dart
  /// TimeOfDayVO(hour: 9, minute: 30).format12Hour() // "9:30 AM"
  /// TimeOfDayVO(hour: 14, minute: 5).format12Hour() // "2:05 PM"
  /// TimeOfDayVO(hour: 0, minute: 0).format12Hour() // "12:00 AM"
  /// ```
  String format12Hour() {
    final period = hour < 12 ? 'AM' : 'PM';
    final h = hour == 0
        ? 12
        : hour > 12
            ? hour - 12
            : hour;
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m $period';
  }

  /// Returns total minutes since midnight (0-1439).
  ///
  /// Useful for comparisons and calculations.
  ///
  /// **Example:**
  /// ```dart
  /// TimeOfDayVO(hour: 0, minute: 0).totalMinutes // 0
  /// TimeOfDayVO(hour: 1, minute: 30).totalMinutes // 90
  /// TimeOfDayVO(hour: 23, minute: 59).totalMinutes // 1439
  /// ```
  int get totalMinutes => hour * 60 + minute;

  /// Creates a TimeOfDayVO from total minutes since midnight.
  ///
  /// **Parameters:**
  /// - [totalMinutes] - Minutes since midnight (0-1439)
  ///
  /// **Throws:**
  /// - [ArgumentError] if totalMinutes is not in range 0-1439
  ///
  /// **Example:**
  /// ```dart
  /// TimeOfDayVO.fromTotalMinutes(90) // TimeOfDayVO(hour: 1, minute: 30)
  /// TimeOfDayVO.fromTotalMinutes(1439) // TimeOfDayVO(hour: 23, minute: 59)
  /// ```
  factory TimeOfDayVO.fromTotalMinutes(int totalMinutes) {
    if (totalMinutes < 0 || totalMinutes > 1439) {
      throw ArgumentError(
          'Total minutes must be between 0 and 1439, got: $totalMinutes');
    }
    final hour = totalMinutes ~/ 60;
    final minute = totalMinutes % 60;
    return TimeOfDayVO(hour: hour, minute: minute);
  }

  @override
  List<Object?> get props => [hour, minute];

  @override
  String toString() => format();
}
