import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mathquest/game/math_world_game.dart';
import 'package:flutter_mathquest/game/npc_question.dart';

void main() {
  final mapSize = Vector2(1392, 1120);
  final viewports = <Vector2>[
    Vector2(568, 320),
    Vector2(768, 1024),
    Vector2(1024, 768),
    Vector2(1280, 800),
    Vector2(1366, 1024),
    Vector2(1920, 1080),
    Vector2(800, 1280),
    Vector2(390, 844),
  ];

  test('all viewport sizes use the original close-up zoom proportion', () {
    for (final viewport in viewports) {
      final baseScale = [
        viewport.x / mapSize.x,
        viewport.y / mapSize.y,
      ].reduce((first, second) => first > second ? first : second);
      final zoom = MathWorldGame.calculateResponsiveCameraZoom(
        viewportSize: viewport,
        mapSize: mapSize,
      );

      expect(zoom, baseScale * 2);
      expect(viewport.x / zoom, lessThan(mapSize.x));
      expect(viewport.y / zoom, lessThan(mapSize.y));
    }
  });

  test('camera bounds allow every NPC to enter tablet and mobile viewports',
      () {
    final placements = NpcQuestion.createNpcPlacements(
      playerSpawn: Vector2(570, 620),
      canOccupy: (_, __) => true,
      level: 1,
    );
    expect(placements, hasLength(6));

    for (final viewport in viewports) {
      final zoom = MathWorldGame.calculateResponsiveCameraZoom(
        viewportSize: viewport,
        mapSize: mapSize,
      );
      final visibleWidth = viewport.x / zoom;
      final visibleHeight = viewport.y / zoom;
      final cameraBounds = MathWorldGame.calculateCameraCenterBounds(
        viewportSize: viewport,
        mapSize: mapSize,
        zoom: zoom,
      );

      for (final placement in placements) {
        final cameraCenterX =
            placement.position.x.clamp(cameraBounds.left, cameraBounds.right);
        final cameraCenterY =
            placement.position.y.clamp(cameraBounds.top, cameraBounds.bottom);
        expect(
          (placement.position.x - cameraCenterX).abs(),
          lessThanOrEqualTo(visibleWidth / 2),
          reason: 'NPC ${placement.questionNumber} is horizontally visible.',
        );
        expect(
          (placement.position.y - cameraCenterY).abs(),
          lessThanOrEqualTo(visibleHeight / 2),
          reason: 'NPC ${placement.questionNumber} is vertically visible.',
        );
      }
    }
  });

  test('camera center bounds account for zoom-scaled viewport dimensions', () {
    final viewport = Vector2(800, 1280);
    final zoom = MathWorldGame.calculateResponsiveCameraZoom(
      viewportSize: viewport,
      mapSize: mapSize,
    );
    final bounds = MathWorldGame.calculateCameraCenterBounds(
      viewportSize: viewport,
      mapSize: mapSize,
      zoom: zoom,
    );

    expect(bounds.left, viewport.x / zoom / 2);
    expect(bounds.top, viewport.y / zoom / 2);
    expect(bounds.right, mapSize.x - viewport.x / zoom / 2);
    expect(bounds.bottom, mapSize.y - viewport.y / zoom / 2);
    expect(bounds.bottom, greaterThan(mapSize.y - viewport.y / 2));
    expect(
      (1016 - bounds.bottom).abs(),
      lessThanOrEqualTo(viewport.y / zoom / 2),
    );
  });

  test('camera zoom recalculates for viewport resizing and orientation', () {
    final tabletLandscapeZoom = MathWorldGame.calculateResponsiveCameraZoom(
      viewportSize: Vector2(1280, 800),
      mapSize: mapSize,
    );
    final tabletPortraitZoom = MathWorldGame.calculateResponsiveCameraZoom(
      viewportSize: Vector2(800, 1280),
      mapSize: mapSize,
    );
    final resizedZoom = MathWorldGame.calculateResponsiveCameraZoom(
      viewportSize: Vector2(1024, 768),
      mapSize: mapSize,
    );

    expect(tabletLandscapeZoom, isNot(tabletPortraitZoom));
    expect(tabletLandscapeZoom, isNot(resizedZoom));
  });
}
