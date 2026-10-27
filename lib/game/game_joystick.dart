import 'dart:math' as math;

import 'package:flutter/material.dart';

typedef JoystickCallback = void Function(Offset offset);

class GameJoystick extends StatefulWidget {
  final JoystickCallback onJoystickChanged;
  final VoidCallback onJoystickEnd;
  final double size;

  const GameJoystick({super.key, required this.onJoystickChanged, required this.onJoystickEnd, this.size = 120});

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
    final offset = delta.distance == 0 ? Offset.zero : (delta / delta.distance) * (dist / max);
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
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
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
