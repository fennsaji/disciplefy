import 'package:flutter/foundation.dart';

/// Log levels for categorizing log messages
enum LogLevel {
  verbose(0, '🔍', 'VERBOSE'),
  debug(1, '🐛', 'DEBUG'),
  info(2, '📋', 'INFO'),
  warning(3, '⚠️', 'WARNING'),
  error(4, '❌', 'ERROR'),
  critical(5, '💥', 'CRITICAL');

  const LogLevel(this.priority, this.emoji, this.label);

  final int priority;
  final String emoji;
  final String label;
}

/// Centralized logging utility for the application
/// 
/// Features:
/// - Structured log levels with emojis
/// - Module-based tagging for easy filtering
/// - Debug mode filtering (no logs in release mode)
/// - Performance metrics logging
/// - Error context tracking
/// - Consistent formatting across the app
class Logger {
  static const String _appTag = 'DISCIPLEFY';
  static LogLevel _minLogLevel = LogLevel.debug;

  /// Set minimum log level (logs below this level will be ignored)
  static void setMinLogLevel(LogLevel level) {
    _minLogLevel = level;
  }

  /// Log a verbose message (detailed debugging information)
  static void verbose(String message, {String? tag, Map<String, dynamic>? context}) {
    _log(LogLevel.verbose, message, tag: tag, context: context);
  }

  /// Log a debug message (general debugging information)
  static void debug(String message, {String? tag, Map<String, dynamic>? context}) {
    _log(LogLevel.debug, message, tag: tag, context: context);
  }

  /// Log an info message (general information)
  static void info(String message, {String? tag, Map<String, dynamic>? context}) {
    _log(LogLevel.info, message, tag: tag, context: context);
  }

  /// Log a warning message (potentially harmful situations)
  static void warning(String message, {String? tag, Map<String, dynamic>? context}) {
    _log(LogLevel.warning, message, tag: tag, context: context);
  }

  /// Log an error message (error events that might still allow the app to continue)
  static void error(String message, {String? tag, Map<String, dynamic>? context, Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.error, message, tag: tag, context: context, error: error, stackTrace: stackTrace);
  }

  /// Log a critical message (very severe error events)
  static void critical(String message, {String? tag, Map<String, dynamic>? context, Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.critical, message, tag: tag, context: context, error: error, stackTrace: stackTrace);
  }

  /// Log performance metrics
  static void performance(String operation, Duration duration, {String? tag, Map<String, dynamic>? context}) {
    final perfContext = {
      'operation': operation,
      'duration_ms': duration.inMilliseconds,
      'duration_readable': '${duration.inMilliseconds}ms',
      ...?context,
    };
    _log(LogLevel.info, 'Performance: $operation completed', tag: tag ?? 'PERFORMANCE', context: perfContext);
  }

  /// Log API calls
  static void apiCall(String method, String endpoint, {int? statusCode, Duration? duration, String? tag}) {
    final message = statusCode != null 
        ? '$method $endpoint → $statusCode'
        : '$method $endpoint';
    
    final context = <String, dynamic>{
      'method': method,
      'endpoint': endpoint,
      if (statusCode != null) 'status_code': statusCode,
      if (duration != null) 'duration_ms': duration.inMilliseconds,
    };

    final level = statusCode != null && statusCode >= 400 ? LogLevel.error : LogLevel.info;
    _log(level, message, tag: tag ?? 'API', context: context);
  }

  /// Log user actions for analytics
  static void userAction(String action, {String? screen, Map<String, dynamic>? properties}) {
    final context = {
      'action': action,
      if (screen != null) 'screen': screen,
      ...?properties,
    };
    _log(LogLevel.info, 'User Action: $action', tag: 'USER_ACTION', context: context);
  }

  /// Log navigation events
  static void navigation(String from, String to, {Map<String, dynamic>? context}) {
    final navContext = {
      'from': from,
      'to': to,
      ...?context,
    };
    _log(LogLevel.debug, 'Navigation: $from → $to', tag: 'NAVIGATION', context: navContext);
  }

  /// Internal logging implementation
  static void _log(
    LogLevel level,
    String message, {
    String? tag,
    Map<String, dynamic>? context,
    Object? error,
    StackTrace? stackTrace,
  }) {
    // Skip logging in release mode unless it's an error or critical
    if (kReleaseMode && level.priority < LogLevel.error.priority) {
      return;
    }

    // Skip if below minimum log level
    if (level.priority < _minLogLevel.priority) {
      return;
    }

    final moduleTag = tag ?? 'GENERAL';
    final logTag = '[$_appTag:$moduleTag]';
    
    final logMessage = StringBuffer();
    logMessage.write('${level.emoji} $logTag $message');

    // Add context if provided
    if (context != null && context.isNotEmpty) {
      logMessage.write(' | Context: ${_formatContext(context)}');
    }

    // Add error details if provided
    if (error != null) {
      logMessage.write(' | Error: $error');
    }

    // Print the formatted log message
    if (kDebugMode) {
      print(logMessage.toString());
      
      // Print stack trace for errors and critical logs
      if (stackTrace != null && level.priority >= LogLevel.error.priority) {
        print('Stack trace: $stackTrace');
      }
    }

    // In production, you might want to send critical/error logs to a service
    if (kReleaseMode && level.priority >= LogLevel.error.priority) {
      _sendToLoggingService(level, message, tag: moduleTag, context: context, error: error);
    }
  }

  /// Format context map for readable logging
  static String _formatContext(Map<String, dynamic> context) => context.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join(', ');

  /// Send logs to external logging service (placeholder for production)
  static void _sendToLoggingService(
    LogLevel level,
    String message, {
    String? tag,
    Map<String, dynamic>? context,
    Object? error,
  }) {
    // TODO: Implement actual logging service integration
    // Examples: Firebase Crashlytics, Sentry, Datadog, etc.
    // This would typically be an async operation
    if (kDebugMode) {
      print('🚀 [LOGGING_SERVICE] Would send: ${level.label} - $message');
    }
  }

  /// Create a performance timing wrapper
  static Future<T> timeAsync<T>(
    Future<T> Function() operation,
    String operationName, {
    String? tag,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final result = await operation();
      stopwatch.stop();
      performance(operationName, stopwatch.elapsed, tag: tag);
      return result;
    } catch (e, stackTrace) {
      stopwatch.stop();
      error(
        'Operation failed: $operationName',
        tag: tag,
        context: {'duration_ms': stopwatch.elapsedMilliseconds},
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Create a synchronous performance timing wrapper
  static T timeSync<T>(
    T Function() operation,
    String operationName, {
    String? tag,
  }) {
    final stopwatch = Stopwatch()..start();
    try {
      final result = operation();
      stopwatch.stop();
      performance(operationName, stopwatch.elapsed, tag: tag);
      return result;
    } catch (e, stackTrace) {
      stopwatch.stop();
      error(
        'Operation failed: $operationName',
        tag: tag,
        context: {'duration_ms': stopwatch.elapsedMilliseconds},
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}

/// Extension methods for easier logging from any class
extension LoggerExtension on Object {
  /// Get the class name for tagging
  String get _className => runtimeType.toString().toUpperCase();

  /// Log debug message with automatic class tagging
  void logDebug(String message, {Map<String, dynamic>? context}) {
    Logger.debug(message, tag: _className, context: context);
  }

  /// Log info message with automatic class tagging
  void logInfo(String message, {Map<String, dynamic>? context}) {
    Logger.info(message, tag: _className, context: context);
  }

  /// Log warning message with automatic class tagging
  void logWarning(String message, {Map<String, dynamic>? context}) {
    Logger.warning(message, tag: _className, context: context);
  }

  /// Log error message with automatic class tagging
  void logError(String message, {Map<String, dynamic>? context, Object? error, StackTrace? stackTrace}) {
    Logger.error(message, tag: _className, context: context, error: error, stackTrace: stackTrace);
  }

  /// Log performance with automatic class tagging
  void logPerformance(String operation, Duration duration, {Map<String, dynamic>? context}) {
    Logger.performance(operation, duration, tag: _className, context: context);
  }
}

/// Module-specific loggers for consistency
class ModuleLoggers {
  /// Auth module logger
  static void auth(LogLevel level, String message, {Map<String, dynamic>? context}) {
    Logger._log(level, message, tag: 'AUTH', context: context);
  }

  /// Home module logger
  static void home(LogLevel level, String message, {Map<String, dynamic>? context}) {
    Logger._log(level, message, tag: 'HOME', context: context);
  }

  /// Study Generation module logger
  static void study(LogLevel level, String message, {Map<String, dynamic>? context}) {
    Logger._log(level, message, tag: 'STUDY', context: context);
  }

  /// Daily Verse module logger
  static void dailyVerse(LogLevel level, String message, {Map<String, dynamic>? context}) {
    Logger._log(level, message, tag: 'DAILY_VERSE', context: context);
  }

  /// Settings module logger
  static void settings(LogLevel level, String message, {Map<String, dynamic>? context}) {
    Logger._log(level, message, tag: 'SETTINGS', context: context);
  }

  /// Onboarding module logger
  static void onboarding(LogLevel level, String message, {Map<String, dynamic>? context}) {
    Logger._log(level, message, tag: 'ONBOARDING', context: context);
  }

  /// Saved Guides module logger
  static void savedGuides(LogLevel level, String message, {Map<String, dynamic>? context}) {
    Logger._log(level, message, tag: 'SAVED_GUIDES', context: context);
  }

  /// User Profile module logger
  static void userProfile(LogLevel level, String message, {Map<String, dynamic>? context}) {
    Logger._log(level, message, tag: 'USER_PROFILE', context: context);
  }

  /// Feedback module logger
  static void feedback(LogLevel level, String message, {Map<String, dynamic>? context}) {
    Logger._log(level, message, tag: 'FEEDBACK', context: context);
  }
}