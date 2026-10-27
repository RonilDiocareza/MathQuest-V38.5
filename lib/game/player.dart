import 'dart:ui' as ui;

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'math_world_game.dart';

class Player extends SpriteAnimationComponent
    with KeyboardHandler, CollisionCallbacks, HasGameReference<MathWorldGame> {
  static const String boySpriteAssetPath = 'assets/images/player/character.png';
  static const String girlSpriteAssetPath =
      'assets/images/player/character2.png';
  static const double feetCollisionRadius =
      MathWorldGame.playerFeetCollisionRadius;

  final String characterId;
  static const double walkSpeed = 80;

  final Set<int> collectedNumbers = {};

  bool isMoving = false;

  Vector2 lastMove = Vector2.zero();

  Vector2 moveDirection = Vector2.zero();
  final Vector2 _candidatePosition = Vector2.zero();
  List<int> _frameRowTops = const [];

  SpriteAnimation? walkAnimation;
  SpriteAnimation? idleAnimation;
  SpriteAnimation? downAnimation;
  SpriteAnimation? upAnimation;
  SpriteAnimation? leftAnimation;
  SpriteAnimation? rightAnimation;

  Player({String characterId = 'boy'})
      : characterId = characterId == 'girl' ? 'girl' : 'boy',
        super(
          anchor: Anchor.center,
        );

  String get spriteAssetPath =>
      characterId == 'girl' ? girlSpriteAssetPath : boySpriteAssetPath;

  @override
  Future<void> onLoad() async {
    ui.Image? image;
    try {
      image = await _decodeSprite(spriteAssetPath);
    } catch (error, stackTrace) {
      debugPrint('Unable to load $characterId player sprite: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (characterId == 'girl') {
        try {
          image = await _decodeSprite(boySpriteAssetPath);
          debugPrint('Loaded the Boy sprite as a player fallback.');
        } catch (fallbackError, fallbackStackTrace) {
          debugPrint('Unable to load the Boy player fallback: $fallbackError');
          debugPrintStack(stackTrace: fallbackStackTrace);
        }
      }
    }

    if (image != null) {
      _configureAnimations(image);
    } else {
      size = Vector2(32, 48);
      add(
        RectangleComponent(
          size: Vector2(32, 48),
          paint: Paint()..color = const Color(0xFF0000FF),
          anchor: Anchor.center,
        ),
      );
    }

    add(
      CircleHitbox(
        radius: feetCollisionRadius,
        position: Vector2(0, 21),
      ),
    );
    _updateDepthPriority();
  }

  Future<ui.Image> _decodeSprite(String assetPath) async {
    final spriteBytes = await rootBundle.load(assetPath);
    final codec = await ui.instantiateImageCodec(
      spriteBytes.buffer.asUint8List(),
    );
    try {
      final frame = await codec.getNextFrame();
      return frame.image;
    } finally {
      codec.dispose();
    }
  }

  void _configureAnimations(ui.Image image) {
    if (image.width >= 6 && image.height >= 4) {
      try {
        _frameRowTops = _getFrameRowTops(image);
        downAnimation = _createRowAnimation(image, 0);
        upAnimation = _createRowAnimation(image, 1);
        leftAnimation = _createRowAnimation(image, 2);
        rightAnimation = _createRowAnimation(image, 3);

        idleAnimation = SpriteAnimation.spriteList(
          [_spriteAtFrame(image, 0, 0)],
          stepTime: 1.0,
          loop: true,
        );

        walkAnimation = downAnimation;
        size = Vector2(32, 48);
      } catch (error, stackTrace) {
        debugPrint('Unable to create player sprite animations: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }

    if (idleAnimation == null || walkAnimation == null) {
      size = Vector2(32, 48);
      final fullSprite = Sprite(image);
      idleAnimation = SpriteAnimation.spriteList(
        [fullSprite],
        stepTime: 1.0,
        loop: true,
      );
      walkAnimation = idleAnimation;
    }

    animation = idleAnimation;
    debugPrint('Player animation loaded successfully from $spriteAssetPath');
  }

  SpriteAnimation _createRowAnimation(ui.Image image, int row) {
    final frames = List.generate(
      6,
      (column) => _spriteAtFrame(image, column, row),
    );

    return SpriteAnimation.spriteList(
      frames,
      stepTime: 0.12,
      loop: true,
    );
  }

  List<int> _getFrameRowTops(ui.Image image) {
    // The artwork crosses nominal row boundaries; these starts use the clear gaps.
    if (image.width == 768 && image.height == 768) {
      return const [5, 197, 384, 576];
    }
    if (image.width == 1254 && image.height == 1254) {
      return const [12, 336, 627, 941];
    }

    return List.generate(4, (row) => row * image.height ~/ 4);
  }

  Sprite _spriteAtFrame(ui.Image image, int column, int row) {
    final left = column * image.width ~/ 6;
    final right = (column + 1) * image.width ~/ 6;
    final top = _frameRowTops[row];
    final bottom = top + image.height ~/ 4;

    return Sprite(
      image,
      srcPosition: Vector2(left.toDouble(), top.toDouble()),
      srcSize: Vector2(
        (right - left).toDouble(),
        (bottom - top).toDouble(),
      ),
    );
  }

  @override
  void render(ui.Canvas canvas) {
    final sprite = animationTicker?.getSprite();
    var verticalOffset = 0.0;
    if (sprite != null) {
      final row = _frameRowTops.indexWhere(
        (top) => top.toDouble() == sprite.srcPosition.y,
      );
      if (row >= 0) {
        verticalOffset = (_frameRowTops[row] - row * sprite.image.height / 4) *
            size.y /
            sprite.srcSize.y;
      }
    }

    canvas.save();
    try {
      canvas.translate(0, verticalOffset);
      super.render(canvas);
    } finally {
      canvas.restore();
    }
  }

  @override
  void update(
    double dt,
  ) {
    super.update(dt);

    if (game.isMovementPaused) {
      moveDirection.setZero();
      lastMove.setZero();

      isMoving = false;

      if (idleAnimation != null && animation != idleAnimation) {
        animation = idleAnimation!;
      }

      _updateDepthPriority();
      return;
    }

    // ============================================================
    // MOVEMENT
    // ============================================================

    final directionLength = moveDirection.length;
    if (directionLength > 0) {
      final normalizedDirection = moveDirection / directionLength;
      final movementX = normalizedDirection.x * walkSpeed * dt;
      final movementY = normalizedDirection.y * walkSpeed * dt;

      // ==========================================================
      // FEET-ONLY COLLISION
      // ==========================================================

      const collisionRadius = feetCollisionRadius;

      var moved = false;

      // ----------------------------------------------------------
      // HORIZONTAL MOVEMENT
      // ----------------------------------------------------------

      if (movementX != 0) {
        _candidatePosition
          ..x = position.x + movementX
          ..y = position.y + 21;
      }

      if (movementX != 0) {
        if (game.canPlayerMoveTo(_candidatePosition, collisionRadius)) {
          position.x += movementX;
          moved = true;
        } else if (game.canPlayerMoveTo(
          _candidatePosition,
          collisionRadius,
          checkNpcCollisions: false,
        )) {
          game.checkNpcCollisionsAt(_candidatePosition, collisionRadius);
          if (game.isMovementPaused) {
            if (idleAnimation != null) animation = idleAnimation!;
            _updateDepthPriority();
            return;
          }
        }
      }

      // ----------------------------------------------------------
      // VERTICAL MOVEMENT
      // ----------------------------------------------------------

      if (movementY != 0) {
        _candidatePosition
          ..x = position.x
          ..y = position.y + movementY + 21;
      }

      if (movementY != 0) {
        if (game.canPlayerMoveTo(_candidatePosition, collisionRadius)) {
          position.y += movementY;
          moved = true;
        } else if (game.canPlayerMoveTo(
          _candidatePosition,
          collisionRadius,
          checkNpcCollisions: false,
        )) {
          game.checkNpcCollisionsAt(_candidatePosition, collisionRadius);
        }
      }

      lastMove.setValues(
        moved ? movementX : 0,
        moved ? movementY : 0,
      );

      isMoving = moved;

      // ==========================================================
      // ANIMATION DIRECTION
      // ==========================================================

      if (moveDirection.x.abs() >= moveDirection.y.abs()) {
        if (moveDirection.x > 0 && rightAnimation != null) {
          animation = rightAnimation;
        } else if (moveDirection.x < 0 && leftAnimation != null) {
          animation = leftAnimation;
        }
      } else if (moveDirection.y < 0 && upAnimation != null) {
        animation = upAnimation;
      } else if (moveDirection.y > 0 && downAnimation != null) {
        animation = downAnimation;
      }
    } else {
      lastMove.setZero();

      isMoving = false;
    }

    // ============================================================
    // IDLE
    // ============================================================

    if (!isMoving) {
      if (idleAnimation != null && animation != idleAnimation) {
        animation = idleAnimation!;
      }
    }

    // ============================================================
    // MAP BOUNDARIES
    // ============================================================

    if (position.x < 0) {
      position.x = 0;
    }

    if (position.y < 0) {
      position.y = 0;
    }

    if (position.x > game.mapWidth) {
      position.x = game.mapWidth;
    }

    if (position.y > game.mapHeight) {
      position.y = game.mapHeight;
    }
    _updateDepthPriority();
  }

  void _updateDepthPriority() {
    priority = (position.y + size.y / 2).round();
  }

  @override
  bool onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    if (game.isMovementPaused) {
      moveDirection.setZero();

      return true;
    }

    moveDirection.setZero();

    if (keysPressed.contains(
          LogicalKeyboardKey.arrowRight,
        ) ||
        keysPressed.contains(
          LogicalKeyboardKey.keyD,
        )) {
      moveDirection.x = 1;
    }

    if (keysPressed.contains(
          LogicalKeyboardKey.arrowLeft,
        ) ||
        keysPressed.contains(
          LogicalKeyboardKey.keyA,
        )) {
      moveDirection.x = -1;
    }

    if (keysPressed.contains(
          LogicalKeyboardKey.arrowUp,
        ) ||
        keysPressed.contains(
          LogicalKeyboardKey.keyW,
        ) ||
        keysPressed.contains(
          LogicalKeyboardKey.keyE,
        )) {
      moveDirection.y = -1;
    }

    if (keysPressed.contains(
          LogicalKeyboardKey.arrowDown,
        ) ||
        keysPressed.contains(
          LogicalKeyboardKey.keyS,
        ) ||
        keysPressed.contains(
          LogicalKeyboardKey.keyF,
        )) {
      moveDirection.y = 1;
    }

    return true;
  }

  void addCollectedNumber(
    int number,
  ) {
    collectedNumbers.add(
      number,
    );
  }

  bool hasCollected(
    int number,
  ) {
    return collectedNumbers.contains(
      number,
    );
  }

  Set<int> getCollectedNumbers() {
    return Set.from(
      collectedNumbers,
    );
  }
}

class Character extends Player {
  Character({super.characterId = 'boy'});
}
