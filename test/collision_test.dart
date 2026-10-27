import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mathquest/game/math_world_game.dart';

void main() {
  test('circle collision stops at a wall edge', () {
    final game = MathWorldGame(correctAnswer: 0, problem: '2 + 2');
    game.mapWidth = 200;
    game.mapHeight = 200;

    game.collisionPolygons.add([
      const Offset(0, 0),
      const Offset(10, 10),
      const Offset(10, 12),
      const Offset(0, 2),
    ]);

    expect(game.canPlayerMoveTo(Vector2(8, 9), 3), isFalse);
    expect(game.canPlayerMoveTo(Vector2(18, 9), 3), isTrue);
  });

  test('circle collision detects polygon edges without center overlap', () {
    final game = MathWorldGame(correctAnswer: 0, problem: '2 + 2');
    game.mapWidth = 200;
    game.mapHeight = 200;

    game.collisionPolygons.add([
      const Offset(20, 20),
      const Offset(40, 20),
      const Offset(40, 40),
      const Offset(20, 40),
    ]);

    expect(game.canPlayerMoveTo(Vector2(42, 30), 3), isFalse);
    expect(game.canPlayerMoveTo(Vector2(44, 30), 3), isTrue);
  });

  test('circle collision checks obstacles across spatial cell boundaries', () {
    final game = MathWorldGame(correctAnswer: 0, problem: '2 + 2');
    game.mapWidth = 600;
    game.mapHeight = 600;
    game.collisionRectangles.add(
      const ui.Rect.fromLTWH(260, 100, 20, 20),
    );
    game.collisionPolygons.add([
      const Offset(510, 100),
      const Offset(530, 100),
      const Offset(530, 120),
      const Offset(510, 120),
    ]);

    expect(game.canPlayerMoveTo(Vector2(253, 110), 8), isFalse);
    expect(game.canPlayerMoveTo(Vector2(250, 110), 8), isTrue);
    expect(game.canPlayerMoveTo(Vector2(507, 110), 4), isFalse);
    expect(game.canPlayerMoveTo(Vector2(504, 110), 4), isTrue);
  });

  test('player movement stops at stationary NPC collision circles', () {
    final game = MathWorldGame(correctAnswer: 0, problem: '2 + 2');
    game.mapWidth = 200;
    game.mapHeight = 200;
    game.registerNpcCollisionCircle(
      center: const Offset(50, 50),
      radius: 10,
    );

    expect(game.canPlayerMoveTo(Vector2(34, 50), 6), isFalse);
    expect(game.canPlayerMoveTo(Vector2(33.9, 50), 6), isTrue);
    expect(
      game.canPlayerMoveTo(
        Vector2(50, 50),
        6,
        checkNpcCollisions: false,
      ),
      isTrue,
    );
  });
}
