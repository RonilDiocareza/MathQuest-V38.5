import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'math_world_game.dart';
import 'npc_question.dart';

class QuestionNpc extends SpriteComponent with HasGameReference<MathWorldGame> {
  static const double visibleHeight = 40;
  static const double contactReleaseDistance = 8;

  final NpcQuestion question;
  final String spriteAssetPath;
  final double collisionRadius;
  bool _wasTouching = false;

  QuestionNpc({
    required this.question,
    required this.spriteAssetPath,
    required Vector2 position,
    required this.collisionRadius,
  }) : super(
          position: position,
          size: Vector2(20, 48),
          anchor: Anchor.bottomCenter,
        ) {
    priority = position.y.round();
  }

  @override
  Future<void> onLoad() async {
    try {
      final assetKey = spriteAssetPath.replaceFirst('assets/images/', '');
      final image = await game.images.load(assetKey);
      final frameTop = image.width == 1254 && image.height == 1254 ? 12 : 0;
      final sourceSize = Vector2(
        (image.width / 6).floorToDouble(),
        (image.height / 4).floorToDouble(),
      );
      sprite = Sprite(image,
          srcPosition: Vector2(0, frameTop.toDouble()), srcSize: sourceSize);
      size = Vector2(
        visibleHeight * sourceSize.x / sourceSize.y,
        visibleHeight,
      );
    } catch (error, stackTrace) {
      debugPrint('Unable to load NPC sprite $spriteAssetPath: $error');
      debugPrintStack(stackTrace: stackTrace);
      add(
        CircleComponent(
          radius: 10,
          position: Vector2(0, -10),
          paint: Paint()..color = const Color(0xFFFFC107),
          anchor: Anchor.center,
        ),
      );
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (game.isMovementPaused || !game.isGameLoaded) return;

    final playerFeet = game.player.position + Vector2(0, 21);
    checkPlayerContactAt(
      playerFeet,
      MathWorldGame.playerFeetCollisionRadius,
    );
  }

  void checkPlayerContactAt(Vector2 playerCenter, double playerRadius) {
    final npcCenter = position - Vector2(0, collisionRadius);
    final contactDistance = collisionRadius + playerRadius;
    final distance = playerCenter.distanceTo(npcCenter);
    if (distance <= contactDistance) {
      if (!_wasTouching) game.interactWithNpc(question);
      _wasTouching = true;
    } else if (distance > contactDistance + contactReleaseDistance) {
      _wasTouching = false;
    }
  }
}
