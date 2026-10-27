import 'package:flutter/material.dart';
import 'touch_input_handler.dart';

/// Adaptive game controls widget that responds to screen size and orientation
class AdaptiveGameControls extends StatelessWidget {
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onMoveLeft;
  final VoidCallback onMoveRight;
  final VoidCallback onStopMove;

  const AdaptiveGameControls({
    super.key,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onMoveLeft,
    required this.onMoveRight,
    required this.onStopMove,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 400;
        final isLandscape = constraints.maxWidth > constraints.maxHeight;

        return Stack(
          children: [
            // D-Pad positioned based on screen size
            Positioned(
              left: isSmallScreen ? 8 : 16,
              bottom: isSmallScreen ? 12 : 24,
              child: _buildDPad(isSmallScreen),
            ),
            // Action buttons on right side (optional)
            if (!isLandscape)
              Positioned(
                right: isSmallScreen ? 8 : 16,
                bottom: isSmallScreen ? 12 : 24,
                child: _buildActionButtons(isSmallScreen),
              ),
          ],
        );
      },
    );
  }

  Widget _buildDPad(bool isSmall) {
    return Column(
      children: [
        // Up arrow button
        _buildControlButton(
          icon: Icons.arrow_upward,
          onPressed: onMoveUp,
          onRelease: onStopMove,
          size: isSmall ? 32 : 44,
          margin: EdgeInsets.only(bottom: isSmall ? 4 : 8),
        ),
        Row(
          children: [
            // Left arrow button
            _buildControlButton(
              icon: Icons.arrow_back,
              onPressed: onMoveLeft,
              onRelease: onStopMove,
              size: isSmall ? 32 : 44,
              margin: EdgeInsets.only(right: isSmall ? 4 : 8),
            ),
            // Down arrow button
            _buildControlButton(
              icon: Icons.arrow_downward,
              onPressed: onMoveDown,
              onRelease: onStopMove,
              size: isSmall ? 32 : 44,
              margin: EdgeInsets.symmetric(horizontal: isSmall ? 4 : 8),
            ),
            // Right arrow button
            _buildControlButton(
              icon: Icons.arrow_forward,
              onPressed: onMoveRight,
              onRelease: onStopMove,
              size: isSmall ? 32 : 44,
              margin: EdgeInsets.only(left: isSmall ? 4 : 8),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButtons(bool isSmall) {
    return Tooltip(
      message: 'Action buttons',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSmallButton(
            icon: Icons.favorite,
            size: isSmall ? 28 : 36,
            margin: EdgeInsets.only(bottom: isSmall ? 4 : 8),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required VoidCallback onRelease,
    required double size,
    required EdgeInsets margin,
  }) {
    return Container(
      margin: margin,
      child: GestureDetector(
        onTapDown: (_) {
          HapticFeedbackHelper.lightTap();
          onPressed();
        },
        onTapUp: (_) => onRelease(),
        onTapCancel: onRelease,
        child: Container(
          width: size + 12,
          height: size + 12,
          decoration: BoxDecoration(
            color: const Color(0xFF4CAF50),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(100),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: size,
          ),
        ),
      ),
    );
  }

  Widget _buildSmallButton({
    required IconData icon,
    required double size,
    required EdgeInsets margin,
  }) {
    return Container(
      margin: margin,
      child: GestureDetector(
        onTapDown: (_) => HapticFeedbackHelper.mediumTap(),
        child: Container(
          width: size + 8,
          height: size + 8,
          decoration: BoxDecoration(
            color: const Color(0xFFE53935),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(100),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: size,
          ),
        ),
      ),
    );
  }
}

/// Screen orientation helper
class OrientationHelper {
  static bool isPortrait(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.portrait;
  }

  static bool isLandscape(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape;
  }

  static Size getScreenSize(BuildContext context) {
    return MediaQuery.of(context).size;
  }

  static EdgeInsets getDevicePadding(BuildContext context) {
    return MediaQuery.of(context).padding;
  }

  static double getDevicePixelRatio(BuildContext context) {
    return MediaQuery.of(context).devicePixelRatio;
  }

  /// Returns the usable screen height (excluding status bar and navigation bar)
  static double getUsableHeight(BuildContext context) {
    final size = getScreenSize(context);
    final padding = getDevicePadding(context);
    return size.height - padding.top - padding.bottom;
  }

  /// Returns the usable screen width (excluding system UI)
  static double getUsableWidth(BuildContext context) {
    final size = getScreenSize(context);
    final padding = getDevicePadding(context);
    return size.width - padding.left - padding.right;
  }
}

/// Device info helper
class DeviceInfoHelper {
  static bool isTablet(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final diagonal =
        (size.width * size.width + size.height * size.height).toDouble();
    return diagonal > 1000000; // Roughly 317 inches diagonal
  }

  static bool isSmallPhone(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width < 360;
  }

  static bool isLargePhone(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width > 500;
  }

  /// Get optimal control size based on device type
  static double getOptimalControlSize(BuildContext context) {
    if (isTablet(context)) {
      return 130;
    } else if (isSmallPhone(context)) {
      return 100;
    } else if (isLargePhone(context)) {
      return 140;
    }
    return 120; // Default
  }
}
