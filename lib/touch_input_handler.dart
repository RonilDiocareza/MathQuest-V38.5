import 'package:flutter/services.dart';

/// Touch input handler utility for improved mobile responsiveness
class TouchInputHandler {
  static const int tapThreshold = 200; // milliseconds
  static const double dragThreshold = 10.0; // logical pixels
  static const int longPressThreshold = 500; // milliseconds

  /// Detects if touch was a tap (not a drag)
  static bool isTap(
    Offset startPosition,
    Offset endPosition,
    Duration duration,
  ) {
    final distance = (endPosition - startPosition).distance;
    return distance < dragThreshold && duration.inMilliseconds < tapThreshold;
  }

  /// Calculates velocity of touch movement
  static Offset calculateVelocity(
    Offset delta,
    Duration duration,
  ) {
    if (duration.inMilliseconds == 0) return Offset.zero;
    final milliseconds = duration.inMilliseconds.toDouble();
    return Offset(
        delta.dx / milliseconds * 1000, delta.dy / milliseconds * 1000);
  }

  /// Normalizes touch position to range 0.0-1.0
  static Offset normalizePosition(
    Offset position,
    Size containerSize,
  ) {
    return Offset(
      position.dx.clamp(0, containerSize.width) / containerSize.width,
      position.dy.clamp(0, containerSize.height) / containerSize.height,
    );
  }

  /// Converts touch delta to normalized direction vector (-1 to 1)
  static Offset normalizeDirection(
    Offset delta, {
    double maxDistance = 100,
  }) {
    final distance = delta.distance;
    if (distance == 0) return Offset.zero;
    if (distance > maxDistance) {
      return delta / distance;
    }
    return delta / maxDistance;
  }

  /// Applies deadzone to eliminate small movements
  static Offset applyDeadzone(
    Offset value, {
    double deadzone = 0.1,
  }) {
    return Offset(
      value.dx.abs() < deadzone ? 0 : value.dx,
      value.dy.abs() < deadzone ? 0 : value.dy,
    );
  }

  /// Smooths rapid input changes using exponential moving average
  static Offset smoothInput(
    Offset current,
    Offset previous, {
    double smoothingFactor = 0.3,
  }) {
    return Offset(
      previous.dx * (1 - smoothingFactor) + current.dx * smoothingFactor,
      previous.dy * (1 - smoothingFactor) + current.dy * smoothingFactor,
    );
  }

  /// Detects if a multi-touch gesture is happening
  static bool isMultiTouch(int pointerCount) {
    return pointerCount > 1;
  }
}

/// Gesture configuration optimized for mobile games
class MobileGameGestureConfig {
  static const tapDownConfig = {
    'enableFeedback': true,
    'hapticFeedback': true,
  };

  static const dragConfig = {
    'minFlingDistance': 50.0,
    'minFlingVelocity': 365.0,
    'maxFlingVelocity': 8000.0,
  };

  static const longPressConfig = {
    'duration': Duration(milliseconds: 500),
    'enableFeedback': true,
  };

  /// Get responsive button size based on screen size
  static double getResponsiveButtonSize(Size screenSize) {
    final minDimension = screenSize.width < screenSize.height
        ? screenSize.width
        : screenSize.height;
    return (minDimension * 0.12).clamp(48.0, 72.0);
  }

  /// Get responsive touch target minimum size (48x48 according to Material design)
  static const double minimumTouchTargetSize = 48.0;

  /// Validate touch target size meets accessibility standards
  static bool isValidTouchTarget(Size size) {
    return size.width >= minimumTouchTargetSize &&
        size.height >= minimumTouchTargetSize;
  }
}

/// Haptic feedback helper for mobile touch feedback
class HapticFeedbackHelper {
  /// Light vibration for button press
  static Future<void> lightTap() async {
    try {
      HapticFeedback.lightImpact();
    } catch (e) {
      // Device may not support haptics
    }
  }

  /// Medium vibration for significant action
  static Future<void> mediumTap() async {
    try {
      HapticFeedback.mediumImpact();
    } catch (e) {
      // Device may not support haptics
    }
  }

  /// Heavy vibration for important events
  static Future<void> heavyTap() async {
    try {
      HapticFeedback.heavyImpact();
    } catch (e) {
      // Device may not support haptics
    }
  }

  /// Selection haptic (common on Android)
  static Future<void> selection() async {
    try {
      HapticFeedback.selectionClick();
    } catch (e) {
      // Device may not support haptics
    }
  }
}

/// Performance monitor for touch input latency
class TouchPerformanceMonitor {
  final List<Duration> _latencies = [];
  static const int maxSamples = 100;

  void recordLatency(Duration latency) {
    _latencies.add(latency);
    if (_latencies.length > maxSamples) {
      _latencies.removeAt(0);
    }
  }

  Duration getAverageLatency() {
    if (_latencies.isEmpty) return Duration.zero;
    final total = _latencies.fold<int>(
      0,
      (sum, latency) => sum + latency.inMilliseconds,
    );
    return Duration(milliseconds: (total / _latencies.length).toInt());
  }

  Duration getMaxLatency() {
    if (_latencies.isEmpty) return Duration.zero;
    return _latencies.reduce(
      (max, current) =>
          current.inMilliseconds > max.inMilliseconds ? current : max,
    );
  }

  void clear() {
    _latencies.clear();
  }

  void printStats() {
    print('Touch Performance - Avg: ${getAverageLatency().inMilliseconds}ms, '
        'Max: ${getMaxLatency().inMilliseconds}ms, Samples: ${_latencies.length}');
  }
}
