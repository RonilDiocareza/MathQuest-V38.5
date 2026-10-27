import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'math_world_game.dart';

class NumberItem extends PositionComponent
    with CollisionCallbacks, HasGameReference<MathWorldGame> {
  final int value;
  bool isCollected = false;
  Sprite? numberSprite;

  NumberItem({
    required this.value,
    required Vector2 position,
  }) : super(
          position: position,
          size: Vector2(50, 50),
          anchor: Anchor.center,
        );

  @override
  Future<void> onLoad() async {
    // Apply responsive scaling based on device size
    try {
      if (game.runtimeType.toString().contains('MathWorldGame')) {
        // Access deviceScaleFactor through reflection or type casting if available
        // For now, we'll use a simple heuristic based on viewport width
        final scaleFactor = (game.size.x / 400).clamp(0.6, 1.5);
        size *= scaleFactor;
      }
    } catch (_) {
      // Default size if scaling fails
    }

    add(CircleHitbox(radius: size.x / 2));

    try {
      numberSprite = await Sprite.load('images/numbers/number_$value.png');
    } catch (_) {
      numberSprite = null;
    }
  }

  @override
  void render(Canvas canvas) {
    if (isCollected) {
      return;
    }

    if (numberSprite != null) {
      numberSprite!.render(canvas, size: size);
    } else {
      final paint = Paint()..color = const Color(0xFFFFD700);
      canvas.drawCircle(Offset.zero, size.x / 2, paint);

      final fontSize = (size.x * 0.8).clamp(14.0, 24.0);
      final textPainter = TextPainter(
        text: TextSpan(
          text: value.toString(),
          style: TextStyle(
            color: Colors.black,
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          -textPainter.width / 2,
          -textPainter.height / 2,
        ),
      );
    }
  }

  void pickup() {
    isCollected = true;
    removeFromParent();
  }
}
