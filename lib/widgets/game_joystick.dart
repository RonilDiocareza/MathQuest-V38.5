import 'dart:math' as math;

import 'package:flutter/material.dart';

typedef JoystickCallback = void Function(Offset offset);

class GameJoystick extends StatefulWidget {
  final JoystickCallback onJoystickChanged;
  final VoidCallback onJoystickEnd;
  final double size;

  const GameJoystick(
      {super.key,
      required this.onJoystickChanged,
      required this.onJoystickEnd,
      this.size = 120});

  @override
  State<GameJoystick> createState() => _GameJoystickState();
}

class _GameJoystickState extends State<GameJoystick> {
  Offset _localPos = Offset.zero;

  void _updateOffset(Offset local) {
    final center = Offset(widget.size / 2, widget.size / 2);
    final delta = local - center;
    final max = widget.size / 2;
    final dist = math.min(delta.distance, max);
    final offset = delta.distance == 0
        ? Offset.zero
        : (delta / delta.distance) * (dist / max);
    setState(() => _localPos = offset * max);
    widget.onJoystickChanged(offset);
  }

  void _end() {
    setState(() => _localPos = Offset.zero);
    widget.onJoystickEnd();
  }

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: GestureDetector(
          onPanStart: (e) => _updateOffset(e.localPosition),
          onPanUpdate: (e) => _updateOffset(e.localPosition),
          onPanEnd: (_) => _end(),
          onPanCancel: _end,
          child: Stack(
            children: [
              Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  color: Colors.black45,
                  shape: BoxShape.circle,
                ),
              ),
              Positioned(
                left: widget.size / 2 - 20 + _localPos.dx,
                top: widget.size / 2 - 20 + _localPos.dy,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white70,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black26, blurRadius: 4)
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FloatingGameJoystick extends StatefulWidget {
  const FloatingGameJoystick({
    super.key,
    required this.child,
    required this.onJoystickChanged,
    required this.onJoystickEnd,
    this.size = 120,
    this.enabled = true,
  });

  final Widget child;
  final JoystickCallback onJoystickChanged;
  final VoidCallback onJoystickEnd;
  final double size;
  final bool enabled;

  @override
  State<FloatingGameJoystick> createState() => _FloatingGameJoystickState();
}

class _FloatingGameJoystickState extends State<FloatingGameJoystick> {
  int? _pointer;
  Offset? _center;
  Offset _knobOffset = Offset.zero;

  void _onPointerDown(PointerDownEvent event) {
    if (!widget.enabled || _pointer != null) return;
    setState(() {
      _pointer = event.pointer;
      _center = event.localPosition;
      _knobOffset = Offset.zero;
    });
    widget.onJoystickChanged(Offset.zero);
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_pointer != event.pointer || _center == null) return;
    final delta = event.localPosition - _center!;
    final radius = widget.size / 2;
    final distance = math.min(delta.distance, radius);
    final knobOffset =
        delta.distance == 0 ? Offset.zero : delta / delta.distance * distance;
    setState(() => _knobOffset = knobOffset);
    widget.onJoystickChanged(
      radius == 0 ? Offset.zero : knobOffset / radius,
    );
  }

  void _endPointer(int pointer) {
    if (_pointer != pointer) return;
    setState(() {
      _pointer = null;
      _center = null;
      _knobOffset = Offset.zero;
    });
    widget.onJoystickEnd();
  }

  @override
  void didUpdateWidget(covariant FloatingGameJoystick oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled && !widget.enabled && _pointer != null) {
      _endPointer(_pointer!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final center = _center;
    final radius = widget.size / 2;
    return Stack(
      fit: StackFit.expand,
      children: [
        Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: (event) => _endPointer(event.pointer),
          onPointerCancel: (event) => _endPointer(event.pointer),
          child: widget.child,
        ),
        if (center != null)
          Positioned(
            left: center.dx - radius,
            top: center.dy - radius,
            width: widget.size,
            height: widget.size,
            child: IgnorePointer(
              child: ClipOval(
                key: const ValueKey('floating-joystick'),
                child: Stack(
                  children: [
                    const Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
                      left: radius - 20 + _knobOffset.dx,
                      top: radius - 20 + _knobOffset.dy,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: Colors.white70,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
