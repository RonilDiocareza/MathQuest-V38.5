import 'package:flutter/material.dart';

/// Enhanced D-Pad controller for mobile with continuous touch tracking
class MobileDpadController extends StatefulWidget {
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onMoveLeft;
  final VoidCallback onMoveRight;
  final VoidCallback onStopMove;
  final double size;
  final EdgeInsets padding;

  const MobileDpadController({
    super.key,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onMoveLeft,
    required this.onMoveRight,
    required this.onStopMove,
    this.size = 120,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  State<MobileDpadController> createState() => _MobileDpadControllerState();
}

class _MobileDpadControllerState extends State<MobileDpadController> {
  late Rect _upButtonRect;
  late Rect _downButtonRect;
  late Rect _leftButtonRect;
  late Rect _rightButtonRect;

  Set<String> _activeButtons = {};
  bool _isTouching = false;

  @override
  void initState() {
    super.initState();
    _calculateButtonRects();
  }

  void _calculateButtonRects() {
    final buttonSize = widget.size / 3;
    final centerX = widget.size / 2;
    final centerY = widget.size / 2;

    _upButtonRect =
        Rect.fromLTWH(centerX - buttonSize / 2, 0, buttonSize, buttonSize);
    _downButtonRect = Rect.fromLTWH(centerX - buttonSize / 2,
        widget.size - buttonSize, buttonSize, buttonSize);
    _leftButtonRect =
        Rect.fromLTWH(0, centerY - buttonSize / 2, buttonSize, buttonSize);
    _rightButtonRect = Rect.fromLTWH(widget.size - buttonSize,
        centerY - buttonSize / 2, buttonSize, buttonSize);
  }

  void _handlePointerDown(PointerDownEvent event) {
    _isTouching = true;
    _updateTouchPosition(event.localPosition);
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_isTouching) {
      _updateTouchPosition(event.localPosition);
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    _isTouching = false;
    _activeButtons.clear();
    widget.onStopMove();
    setState(() {});
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _isTouching = false;
    _activeButtons.clear();
    widget.onStopMove();
    setState(() {});
  }

  void _updateTouchPosition(Offset position) {
    final newActiveButtons = <String>{};

    // Check which buttons are under the touch
    if (_upButtonRect.contains(position)) {
      newActiveButtons.add('up');
    }
    if (_downButtonRect.contains(position)) {
      newActiveButtons.add('down');
    }
    if (_leftButtonRect.contains(position)) {
      newActiveButtons.add('left');
    }
    if (_rightButtonRect.contains(position)) {
      newActiveButtons.add('right');
    }

    if (_activeButtons.length == newActiveButtons.length &&
        _activeButtons.containsAll(newActiveButtons)) {
      return;
    }

    // Trigger callbacks for buttons that changed state
    if (!_activeButtons.contains('up') && newActiveButtons.contains('up')) {
      widget.onMoveUp();
    }
    if (!_activeButtons.contains('down') && newActiveButtons.contains('down')) {
      widget.onMoveDown();
    }
    if (!_activeButtons.contains('left') && newActiveButtons.contains('left')) {
      widget.onMoveLeft();
    }
    if (!_activeButtons.contains('right') &&
        newActiveButtons.contains('right')) {
      widget.onMoveRight();
    }

    // Stop movement when buttons are no longer pressed
    if (_activeButtons.contains('up') && !newActiveButtons.contains('up')) {
      widget.onStopMove();
    }
    if (_activeButtons.contains('down') && !newActiveButtons.contains('down')) {
      widget.onStopMove();
    }
    if (_activeButtons.contains('left') && !newActiveButtons.contains('left')) {
      widget.onStopMove();
    }
    if (_activeButtons.contains('right') &&
        !newActiveButtons.contains('right')) {
      widget.onStopMove();
    }

    _activeButtons = newActiveButtons;

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      child: Padding(
        padding: widget.padding,
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: _DpadPainter(activeButtons: _activeButtons),
            size: Size(widget.size, widget.size),
          ),
        ),
      ),
    );
  }
}

/// Custom painter for D-Pad visualization
class _DpadPainter extends CustomPainter {
  final Set<String> activeButtons;

  _DpadPainter({required this.activeButtons});

  @override
  void paint(Canvas canvas, Size size) {
    const buttonSize = 40.0;
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final buttonSpacing = (size.width - buttonSize) / 2;

    // Draw buttons
    _drawButton(
      canvas,
      Offset(centerX - buttonSize / 2, buttonSpacing),
      size: buttonSize,
      isActive: activeButtons.contains('up'),
      icon: '▲',
    );

    _drawButton(
      canvas,
      Offset(
          centerX - buttonSize / 2, size.height - buttonSpacing - buttonSize),
      size: buttonSize,
      isActive: activeButtons.contains('down'),
      icon: '▼',
    );

    _drawButton(
      canvas,
      Offset(buttonSpacing, centerY - buttonSize / 2),
      size: buttonSize,
      isActive: activeButtons.contains('left'),
      icon: '◀',
    );

    _drawButton(
      canvas,
      Offset(size.width - buttonSpacing - buttonSize, centerY - buttonSize / 2),
      size: buttonSize,
      isActive: activeButtons.contains('right'),
      icon: '▶',
    );

    // Draw center circle
    final centerPaint = Paint()
      ..color = Colors.black.withAlpha(80)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(centerX, centerY), buttonSize * 0.4, centerPaint);
  }

  void _drawButton(
    Canvas canvas,
    Offset position, {
    required double size,
    required bool isActive,
    required String icon,
  }) {
    final buttonPaint = Paint()
      ..color = isActive ? const Color(0xFF4CAF50) : const Color(0xFF558B2F)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = const Color(0xFF2E7D32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Draw button background with rounded corners
    final rect = Rect.fromLTWH(position.dx, position.dy, size, size);
    const radius = 8.0;

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(radius)),
      buttonPaint,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(radius)),
      borderPaint,
    );

    // Draw icon shadow for depth
    if (isActive) {
      final shadowPaint = Paint()
        ..color = Colors.white.withAlpha(100)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(position.dx + size / 2, position.dy + size / 2),
        size * 0.2,
        shadowPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_DpadPainter oldDelegate) {
    return oldDelegate.activeButtons != activeButtons;
  }
}
