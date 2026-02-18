import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'device_keyboard_handler.dart';
import 'logger.dart';

/// Performance monitoring system for keyboard interactions to identify
/// and resolve performance bottlenecks that could cause shadow issues.
///
/// Tracks metrics like animation frame drops, transition timing,
/// and device-specific performance patterns.
class KeyboardPerformanceMonitor {
  static KeyboardPerformanceMonitor? _instance;
  static KeyboardPerformanceMonitor get instance =>
      _instance ??= KeyboardPerformanceMonitor._();

  KeyboardPerformanceMonitor._();

  bool _isMonitoring = false;
  Timer? _performanceTimer;
  final Queue<KeyboardPerformanceMetric> _metrics =
      Queue<KeyboardPerformanceMetric>();
  static const int _maxMetrics = 100; // Keep last 100 metrics

  DateTime? _lastKeyboardChange;
  double _lastKeyboardHeight = 0;
  int _frameDropCount = 0;
  Duration _totalTransitionTime = Duration.zero;
  int _transitionCount = 0;

  /// Start performance monitoring
  void startMonitoring() {
    if (_isMonitoring) return;

    _isMonitoring = true;
    _setupPerformanceTimer();

    Logger.debug('⚡ [KEYBOARD PERFORMANCE] Monitoring started');
  }

  /// Stop performance monitoring
  void stopMonitoring() {
    _isMonitoring = false;
    _performanceTimer?.cancel();
    _performanceTimer = null;

    Logger.debug('⚡ [KEYBOARD PERFORMANCE] Monitoring stopped');
  }

  void _setupPerformanceTimer() {
    // Monitor performance every second
    _performanceTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _collectPerformanceMetrics();
    });
  }

  /// Record keyboard height change for performance tracking
  void recordKeyboardChange(double newHeight) {
    final now = DateTime.now();
    final wasKeyboardVisible = _lastKeyboardHeight > 0;
    final isKeyboardVisible = newHeight > 0;

    // Detect transition
    if (wasKeyboardVisible != isKeyboardVisible) {
      if (_lastKeyboardChange != null) {
        final transitionTime = now.difference(_lastKeyboardChange!);
        _totalTransitionTime += transitionTime;
        _transitionCount++;

        _recordMetric(KeyboardPerformanceMetric(
          timestamp: now,
          eventType: isKeyboardVisible
              ? KeyboardEventType.appeared
              : KeyboardEventType.disappeared,
          transitionDuration: transitionTime,
          keyboardHeight: newHeight,
          deviceManufacturer: DeviceKeyboardHandler.deviceManufacturer,
          frameDrops: _frameDropCount,
        ));

        Logger.debug(
            '⚡ [KEYBOARD PERFORMANCE] Transition: ${transitionTime.inMilliseconds}ms, '
            'Height: $newHeight, Drops: $_frameDropCount');
      }

      _frameDropCount = 0; // Reset for next transition
    }

    _lastKeyboardChange = now;
    _lastKeyboardHeight = newHeight;
  }

  /// Record frame drop (called by frame observer)
  void recordFrameDrop() {
    _frameDropCount++;
  }

  void _collectPerformanceMetrics() {
    if (!_isMonitoring) return;

    final now = DateTime.now();

    // Create summary metric
    _recordMetric(KeyboardPerformanceMetric(
      timestamp: now,
      eventType: KeyboardEventType.summary,
      transitionDuration: _transitionCount > 0
          ? Duration(
              milliseconds:
                  _totalTransitionTime.inMilliseconds ~/ _transitionCount)
          : Duration.zero,
      keyboardHeight: _lastKeyboardHeight,
      deviceManufacturer: DeviceKeyboardHandler.deviceManufacturer,
      frameDrops: _frameDropCount,
      averageTransitionTime: _transitionCount > 0
          ? _totalTransitionTime.inMilliseconds / _transitionCount
          : 0.0,
      totalTransitions: _transitionCount,
    ));
  }

  void _recordMetric(KeyboardPerformanceMetric metric) {
    _metrics.add(metric);

    // Keep only recent metrics
    while (_metrics.length > _maxMetrics) {
      _metrics.removeFirst();
    }
  }

  /// Get performance summary for current session
  KeyboardPerformanceSummary getPerformanceSummary() {
    if (_metrics.isEmpty) {
      return KeyboardPerformanceSummary.empty();
    }

    final recentMetrics = _metrics.toList();
    final transitionMetrics = recentMetrics
        .where((m) => m.eventType != KeyboardEventType.summary)
        .toList();

    double avgTransitionTime = 0;
    int totalFrameDrops = 0;
    int slowTransitions = 0;

    if (transitionMetrics.isNotEmpty) {
      avgTransitionTime = transitionMetrics
              .map((m) => m.transitionDuration.inMilliseconds)
              .reduce((a, b) => a + b) /
          transitionMetrics.length;

      totalFrameDrops =
          transitionMetrics.map((m) => m.frameDrops).fold(0, (a, b) => a + b);

      slowTransitions = transitionMetrics
          .where((m) => m.transitionDuration.inMilliseconds > 300)
          .length;
    }

    return KeyboardPerformanceSummary(
      averageTransitionTime: avgTransitionTime,
      totalTransitions: transitionMetrics.length,
      totalFrameDrops: totalFrameDrops,
      slowTransitions: slowTransitions,
      deviceManufacturer: DeviceKeyboardHandler.deviceManufacturer,
      hasPerformanceIssues: _hasPerformanceIssues(
          avgTransitionTime, totalFrameDrops, slowTransitions),
      recommendations: _generateRecommendations(
          avgTransitionTime, totalFrameDrops, slowTransitions),
    );
  }

  bool _hasPerformanceIssues(
      double avgTransitionTime, int frameDrops, int slowTransitions) {
    return avgTransitionTime > 250 || // Transitions slower than 250ms
        frameDrops > 5 || // More than 5 frame drops per session
        slowTransitions > 2; // More than 2 slow transitions
  }

  List<String> _generateRecommendations(
      double avgTransitionTime, int frameDrops, int slowTransitions) {
    final recommendations = <String>[];

    if (avgTransitionTime > 300) {
      recommendations
          .add('Enable reduced motion settings for better performance');
    }

    if (frameDrops > 10) {
      recommendations
          .add('Consider using simplified animations for this device');
    }

    if (slowTransitions > 3) {
      recommendations.add('Device may benefit from custom keyboard handling');
    }

    final manufacturer = DeviceKeyboardHandler.deviceManufacturer.toLowerCase();
    if (manufacturer.contains('samsung') && avgTransitionTime > 200) {
      recommendations
          .add('Samsung device detected - using One UI optimizations');
    }

    if (manufacturer.contains('xiaomi') && frameDrops > 5) {
      recommendations
          .add('MIUI device detected - applying performance optimizations');
    }

    return recommendations;
  }

  /// Get recent performance metrics
  List<KeyboardPerformanceMetric> getRecentMetrics({int count = 10}) {
    final recent = _metrics.toList();
    return recent.length > count
        ? recent.sublist(recent.length - count)
        : recent;
  }

  /// Clear all performance data
  void clearMetrics() {
    _metrics.clear();
    _frameDropCount = 0;
    _totalTransitionTime = Duration.zero;
    _transitionCount = 0;

    Logger.debug('⚡ [KEYBOARD PERFORMANCE] Metrics cleared');
  }

  /// Export performance data for analysis
  Map<String, dynamic> exportMetrics() {
    return {
      'device_manufacturer': DeviceKeyboardHandler.deviceManufacturer,
      'device_model': DeviceKeyboardHandler.deviceModel,
      'android_version': DeviceKeyboardHandler.androidVersion,
      'total_transitions': _transitionCount,
      'average_transition_time_ms': _transitionCount > 0
          ? _totalTransitionTime.inMilliseconds / _transitionCount
          : 0,
      'total_frame_drops': _frameDropCount,
      'performance_summary': getPerformanceSummary().toMap(),
      'recent_metrics': getRecentMetrics().map((m) => m.toMap()).toList(),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
}

/// Individual performance metric data point
class KeyboardPerformanceMetric {
  final DateTime timestamp;
  final KeyboardEventType eventType;
  final Duration transitionDuration;
  final double keyboardHeight;
  final String deviceManufacturer;
  final int frameDrops;
  final double? averageTransitionTime;
  final int? totalTransitions;

  const KeyboardPerformanceMetric({
    required this.timestamp,
    required this.eventType,
    required this.transitionDuration,
    required this.keyboardHeight,
    required this.deviceManufacturer,
    required this.frameDrops,
    this.averageTransitionTime,
    this.totalTransitions,
  });

  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'event_type': eventType.toString(),
      'transition_duration_ms': transitionDuration.inMilliseconds,
      'keyboard_height': keyboardHeight,
      'device_manufacturer': deviceManufacturer,
      'frame_drops': frameDrops,
      if (averageTransitionTime != null)
        'average_transition_time': averageTransitionTime,
      if (totalTransitions != null) 'total_transitions': totalTransitions,
    };
  }
}

/// Performance summary for analysis
class KeyboardPerformanceSummary {
  final double averageTransitionTime;
  final int totalTransitions;
  final int totalFrameDrops;
  final int slowTransitions;
  final String deviceManufacturer;
  final bool hasPerformanceIssues;
  final List<String> recommendations;

  const KeyboardPerformanceSummary({
    required this.averageTransitionTime,
    required this.totalTransitions,
    required this.totalFrameDrops,
    required this.slowTransitions,
    required this.deviceManufacturer,
    required this.hasPerformanceIssues,
    required this.recommendations,
  });

  factory KeyboardPerformanceSummary.empty() {
    return const KeyboardPerformanceSummary(
      averageTransitionTime: 0,
      totalTransitions: 0,
      totalFrameDrops: 0,
      slowTransitions: 0,
      deviceManufacturer: 'Unknown',
      hasPerformanceIssues: false,
      recommendations: [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'average_transition_time_ms': averageTransitionTime,
      'total_transitions': totalTransitions,
      'total_frame_drops': totalFrameDrops,
      'slow_transitions': slowTransitions,
      'device_manufacturer': deviceManufacturer,
      'has_performance_issues': hasPerformanceIssues,
      'recommendations': recommendations,
    };
  }

  @override
  String toString() {
    return 'KeyboardPerformanceSummary('
        'avgTime: ${averageTransitionTime.toStringAsFixed(1)}ms, '
        'transitions: $totalTransitions, '
        'frameDrops: $totalFrameDrops, '
        'issues: $hasPerformanceIssues)';
  }
}

/// Types of keyboard events for performance tracking
enum KeyboardEventType {
  appeared,
  disappeared,
  resized,
  summary,
}

/// Widget for displaying performance metrics in debug mode
class KeyboardPerformanceOverlay extends StatelessWidget {
  final bool showDetailedMetrics;

  const KeyboardPerformanceOverlay({
    super.key,
    this.showDetailedMetrics = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();

    return Positioned(
      bottom: 100,
      right: 10,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.8),
          borderRadius: BorderRadius.circular(4),
        ),
        child: DefaultTextStyle(
          style: const TextStyle(color: Colors.white, fontSize: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🎯 Keyboard Performance',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              _buildSummaryView(),
              if (showDetailedMetrics) _buildDetailedView(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryView() {
    final summary = KeyboardPerformanceMonitor.instance.getPerformanceSummary();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Avg: ${summary.averageTransitionTime.toStringAsFixed(0)}ms'),
        Text('Transitions: ${summary.totalTransitions}'),
        Text('Drops: ${summary.totalFrameDrops}'),
        if (summary.hasPerformanceIssues)
          const Text('⚠️ Issues detected',
              style: TextStyle(color: Colors.yellow)),
      ],
    );
  }

  Widget _buildDetailedView() {
    final metrics =
        KeyboardPerformanceMonitor.instance.getRecentMetrics(count: 5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        const Text('Recent:', style: TextStyle(fontWeight: FontWeight.bold)),
        ...metrics.map((metric) => Text(
            '${metric.eventType.toString().split('.').last}: ${metric.transitionDuration.inMilliseconds}ms')),
      ],
    );
  }
}
