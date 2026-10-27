import 'dart:math';
import 'package:flutter/material.dart';

/// Enhanced joystick controller with improved touch tracking and responsiveness
class GameJoystick extends StatefulWidget {
  final void Function(Offset) onJoystickChanged;
  final VoidCallback onJoystickEnd;

  const GameJoystick({
    super.key,
    required this.onJoystickChanged,
    required this.onJoystickEnd,
  });

  @override
  State<GameJoystick> createState() => _GameJoystickState();
}

class _GameJoystickState extends State<GameJoystick> {
  Offset _normalizedOffset = Offset.zero;
  bool _isPressed = false;

  double _joystickDiameter(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final minSide = min(size.width, size.height);
    return min(max(minSide * 0.22, 100), 180);
  }

  void _handlePanStart(DragStartDetails details) {
    setState(() {
      _isPressed = true;
    });
    _updateTouchPosition(details.localPosition, context);
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    _updateTouchPosition(details.localPosition, context);
  }

  void _updateTouchPosition(Offset localPosition, BuildContext context) {
    final diameter = _joystickDiameter(context);
    final radius = diameter / 2;
    final center = Offset(radius, radius);
    final delta = localPosition - center;
    final distance = delta.distance;

    if (distance < radius * 0.05) {
      setState(() {
        _normalizedOffset = Offset.zero;
      });
      widget.onJoystickChanged(Offset.zero);
      return;
    }

    final constrainedDelta = distance > radius
        ? center + (delta / distance) * radius
        : localPosition;
    final normalizedDelta = (constrainedDelta - center) / radius;

    setState(() {
      _normalizedOffset = normalizedDelta;
    });

    widget.onJoystickChanged(normalizedDelta);
  }

  void _handlePanEnd(DragEndDetails details) {
    setState(() {
      _isPressed = false;
      _normalizedOffset = Offset.zero;
    });
    widget.onJoystickEnd();
  }

  void _handlePanCancel() {
    setState(() {
      _isPressed = false;
      _normalizedOffset = Offset.zero;
    });
    widget.onJoystickEnd();
  }

  @override
  Widget build(BuildContext context) {
    final diameter = _joystickDiameter(context);
    final radius = diameter / 2;
    final center = Offset(radius, radius);
    final thumbPosition = center + _normalizedOffset * radius;

    return GestureDetector(
      onPanStart: _handlePanStart,
      onPanUpdate: _handlePanUpdate,
      onPanEnd: _handlePanEnd,
      onPanCancel: _handlePanCancel,
      child: CustomPaint(
        painter: _JoystickPainter(
          thumbPosition: thumbPosition,
          isPressed: _isPressed,
        ),
        size: Size(diameter, diameter),
      ),
    );
  }
}

/// Custom painter for joystick visualization with improved styling
class _JoystickPainter extends CustomPainter {
  final Offset thumbPosition;
  final bool isPressed;

  _JoystickPainter({
    required this.thumbPosition,
    required this.isPressed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width / 2;
    final thumbRadius = size.width * 0.2;

    // Draw outer circle (base)
    final basePaint = Paint()
      ..color = isPressed
          ? const Color(0xFF4CAF50).withAlpha(180)
          : const Color(0xFF4CAF50).withAlpha(120)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, baseRadius, basePaint);

    // Draw border
    final borderPaint = Paint()
      ..color = const Color(0xFF2E7D32).withAlpha(200)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(center, baseRadius, borderPaint);

    // Draw inner circle (background for thumb)
    final innerPaint = Paint()
      ..color = Colors.black.withAlpha(40)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, baseRadius * 0.6, innerPaint);

    // Draw directional indicators (subtle grid)
    _drawDirectionalGuides(canvas, center, baseRadius);

    // Draw thumb
    final thumbPaint = Paint()
      ..color = isPressed ? Colors.white : Colors.white.withAlpha(230)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(thumbPosition, thumbRadius, thumbPaint);

    // Draw thumb border
    final thumbBorderPaint = Paint()
      ..color = const Color(0xFF1976D2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    canvas.drawCircle(thumbPosition, thumbRadius, thumbBorderPaint);

    // Draw icon in center
    _drawGamepadIcon(canvas, center);
  }

  void _drawDirectionalGuides(Canvas canvas, Offset center, double radius) {
    final guidePaint = Paint()
      ..color = Colors.white.withAlpha(30)
      ..strokeWidth = 1;

    // Horizontal line
    canvas.drawLine(
      Offset(center.dx - radius * 0.5, center.dy),
      Offset(center.dx + radius * 0.5, center.dy),
      guidePaint,
    );

    // Vertical line
    canvas.drawLine(
      Offset(center.dx, center.dy - radius * 0.5),
      Offset(center.dx, center.dy + radius * 0.5),
      guidePaint,
    );
  }

  void _drawGamepadIcon(Canvas canvas, Offset center) {
    // Simple gamepad icon representation
    final iconPaint = Paint()
      ..color = const Color(0xFF1976D2)
      ..style = PaintingStyle.fill;

    // Draw a small circle in center as gamepad indicator
    canvas.drawCircle(center, 6, iconPaint);
  }

  @override
  bool shouldRepaint(_JoystickPainter oldDelegate) {
    return oldDelegate.thumbPosition != thumbPosition ||
        oldDelegate.isPressed != isPressed;
  }
}
