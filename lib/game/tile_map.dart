import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'math_world_game.dart';
import 'npc_question.dart';

class TileMap extends Component with HasGameReference<MathWorldGame> {
  final Map<String, dynamic> mapData;
  final double tileSize;
  final List<_TileChunk> _chunks = [];
  static Image? _cachedMapImage;
  static Future<Image>? _mapImageLoading;

  TileMap({
    required this.mapData,
    this.tileSize = 16.0,
  });

  static Future<Map<String, dynamic>> loadMapData() async {
    final xml = await rootBundle.loadString('assets/maps/map2.tmx');

    return parseTmxMap(xml) ??
        (throw const FormatException(
          'Invalid map2.tmx',
        ));
  }

  static Map<String, dynamic>? parseTmxMap(String xml) {
    // ============================================================
    // MAP HEADER
    // ============================================================

    final header = RegExp(
      r'<map\b[^>]*'
      r'\bwidth="(\d+)"[^>]*'
      r'\bheight="(\d+)"[^>]*'
      r'\btilewidth="(\d+)"[^>]*'
      r'\btileheight="(\d+)"',
      dotAll: true,
    ).firstMatch(xml);

    if (header == null) {
      return null;
    }

    final mapWidth = int.parse(header.group(1)!);

    final mapHeight = int.parse(header.group(2)!);

    final tileWidth = int.parse(header.group(3)!);

    final tileHeight = int.parse(header.group(4)!);

    // ============================================================
    // TILE LAYERS
    // ============================================================

    final layers = <Map<String, dynamic>>[];

    var minTileX = 0;
    var minTileY = 0;
    var maxTileX = 0;
    var maxTileY = 0;

    final layerMatches = RegExp(
      r'<layer\b[^>]*>(.*?)</layer>',
      dotAll: true,
    ).allMatches(xml);

    for (final layer in layerMatches) {
      final layerXml = layer.group(1)!;

      final chunks = <Map<String, dynamic>>[];

      // ----------------------------------------------------------
      // INFINITE MAP CHUNKS
      // ----------------------------------------------------------

      for (final chunk in RegExp(
        r'<chunk\b[^>]*'
        r'\bx="(-?\d+)"[^>]*'
        r'\by="(-?\d+)"[^>]*'
        r'\bwidth="(\d+)"[^>]*'
        r'\bheight="(\d+)"[^>]*'
        r'>(.*?)</chunk>',
        dotAll: true,
      ).allMatches(layerXml)) {
        final x = int.parse(chunk.group(1)!);

        final y = int.parse(chunk.group(2)!);

        final width = int.parse(chunk.group(3)!);

        final height = int.parse(chunk.group(4)!);

        chunks.add({
          'x': x,
          'y': y,
          'width': width,
          'height': height,
          'data': _parseCsv(
            chunk.group(5)!,
          ),
        });

        if (chunks.length == 1 && layers.isEmpty) {
          minTileX = x;
          minTileY = y;
        } else {
          if (x < minTileX) {
            minTileX = x;
          }

          if (y < minTileY) {
            minTileY = y;
          }
        }

        final right = x + width;

        final bottom = y + height;

        if (right > maxTileX) {
          maxTileX = right;
        }

        if (bottom > maxTileY) {
          maxTileY = bottom;
        }
      }

      // ----------------------------------------------------------
      // FINITE MAP
      // ----------------------------------------------------------

      final isFiniteLayer = chunks.isEmpty;

      if (isFiniteLayer) {
        final dataMatch = RegExp(
          r'<data\b[^>]*>(.*?)</data>',
          dotAll: true,
        ).firstMatch(layerXml);

        final fullLayer = layer.group(0)!;

        final widthMatch = RegExp(
          r'\bwidth="(\d+)"',
        ).firstMatch(fullLayer);

        final heightMatch = RegExp(
          r'\bheight="(\d+)"',
        ).firstMatch(fullLayer);

        if (widthMatch == null || heightMatch == null) {
          continue;
        }

        final width = int.parse(
          widthMatch.group(1)!,
        );

        final height = int.parse(
          heightMatch.group(1)!,
        );

        chunks.add({
          'x': 0,
          'y': 0,
          'width': width,
          'height': height,
          'data': _parseCsv(
            dataMatch?.group(1) ?? '',
          ),
        });

        maxTileX = width;
        maxTileY = height;
      }

      final name = RegExp(
            r'\bname="([^"]+)"',
          )
              .firstMatch(
                layer.group(0)!,
              )
              ?.group(1) ??
          'layer';

      final parsedLayer = <String, dynamic>{
        'name': name,
        'chunks': chunks,
      };

      if (isFiniteLayer && chunks.isNotEmpty) {
        parsedLayer['data'] = chunks.first['data'];
      }

      layers.add(parsedLayer);
    }

    // ============================================================
    // COLLISION RECTANGLES
    // ============================================================

    final collisionRectangles = <Rect>[];

    // ============================================================
    // COLLISION POLYGONS
    // ============================================================

    final collisionPolygons = <List<Offset>>[];

    // ============================================================
    // OBJECT GROUPS
    // ============================================================

    final questionNpcs = <QuestionNpcPlacement>[];

    for (final group in RegExp(
      r'<objectgroup\b([^>]*)>(.*?)</objectgroup>',
      dotAll: true,
    ).allMatches(xml)) {
      final groupAttributes = group.group(1)!;

      final groupContent = group.group(2)!;

      final groupName = _getAttribute(
        groupAttributes,
        'name',
      )?.toLowerCase();

      // We only care about these two collision layers.
      final isRectangleLayer = groupName == 'collision_rectangle';

      final isPolygonLayer = groupName == 'collision_polygon';
      final isQuestionNpcLayer = groupName == 'question_npcs';

      if (!isRectangleLayer && !isPolygonLayer && !isQuestionNpcLayer) {
        continue;
      }

      // ==========================================================
      // OBJECTS
      // ==========================================================

      final objectMatches = RegExp(
        r'<object\b([^>]*?)(?:/>|>(.*?)</object>)',
        dotAll: true,
      ).allMatches(groupContent);

      for (final object in objectMatches) {
        final attributes = object.group(1)!;

        final objectContent = object.group(2) ?? '';

        final x = double.tryParse(
          _getAttribute(
                attributes,
                'x',
              ) ??
              '0',
        );

        final y = double.tryParse(
          _getAttribute(
                attributes,
                'y',
              ) ??
              '0',
        );

        if (x == null || y == null) {
          continue;
        }

        if (isQuestionNpcLayer) {
          final properties = objectContent;
          final questionId = _getProperty(properties, 'question_id');
          final topic = _getProperty(properties, 'topic');
          if (questionId == null || topic == null) {
            throw const FormatException(
              'Each question_npcs object must define question_id and topic.',
            );
          }

          questionNpcs.add(
            QuestionNpcPlacement(
              questionId: questionId,
              topic: topic,
              position: Vector2(
                x - minTileX * tileWidth,
                y - minTileY * tileHeight,
              ),
            ),
          );
          continue;
        }

        // ========================================================
        // RECTANGLE
        // ========================================================

        if (isRectangleLayer) {
          final width = double.tryParse(
            _getAttribute(
                  attributes,
                  'width',
                ) ??
                '0',
          );

          final height = double.tryParse(
            _getAttribute(
                  attributes,
                  'height',
                ) ??
                '0',
          );

          if (width == null || height == null || width <= 0 || height <= 0) {
            continue;
          }

          collisionRectangles.add(
            Rect.fromLTWH(
              x - minTileX * tileWidth,
              y - minTileY * tileHeight,
              width,
              height,
            ),
          );

          continue;
        }

        // ========================================================
        // POLYGON
        // ========================================================

        if (isPolygonLayer) {
          final polygonMatch = RegExp(
            r'<polygon\b[^>]*\bpoints="([^"]+)"',
            dotAll: true,
          ).firstMatch(
            objectContent,
          );

          if (polygonMatch == null) {
            continue;
          }

          final rawPoints = polygonMatch.group(1)!;

          final points = <Offset>[];

          for (final pair in rawPoints.split(' ')) {
            if (pair.trim().isEmpty) {
              continue;
            }

            final values = pair.split(',');

            if (values.length < 2) {
              continue;
            }

            final localX = double.tryParse(
              values[0],
            );

            final localY = double.tryParse(
              values[1],
            );

            if (localX == null || localY == null) {
              continue;
            }

            points.add(
              Offset(
                x + localX - minTileX * tileWidth,
                y + localY - minTileY * tileHeight,
              ),
            );
          }

          if (points.length >= 3) {
            collisionPolygons.add(
              points,
            );
          }
        }
      }
    }

    // ============================================================
    // DEBUG
    // ============================================================

    print(
      'TMX collision rectangles: '
      '${collisionRectangles.length}',
    );

    print(
      'TMX collision polygons: '
      '${collisionPolygons.length}',
    );

    // ============================================================
    // RETURN MAP DATA
    // ============================================================

    return {
      'tileWidth': tileWidth,
      'tileHeight': tileHeight,
      'layers': layers,
      'minTileX': minTileX,
      'minTileY': minTileY,
      'width': mapWidth,
      'height': mapHeight,
      'worldWidth': (maxTileX - minTileX) * tileWidth,
      'worldHeight': (maxTileY - minTileY) * tileHeight,
      'collisionRectangles': collisionRectangles,
      'collisionPolygons': collisionPolygons,
      'questionNpcs': questionNpcs,
    };
  }

  static String? _getProperty(String objectContent, String name) {
    for (final property in RegExp(
      r'<property\b([^>]*?)(?:/>|>(.*?)</property>)',
      dotAll: true,
    ).allMatches(objectContent)) {
      final attributes = property.group(1)!;
      if (_getAttribute(attributes, 'name') != name) continue;

      final value = _getAttribute(attributes, 'value') ?? property.group(2);
      return value == null ? null : _decodeXml(value.trim());
    }
    return null;
  }

  static String _decodeXml(String value) {
    return value
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'");
  }

  static String? _getAttribute(
    String attributes,
    String name,
  ) {
    return RegExp(
      '\\b$name="([^"]*)"',
    )
        .firstMatch(
          attributes,
        )
        ?.group(1);
  }

  static List<int> _parseCsv(
    String raw,
  ) {
    return raw
        .split(RegExp(r'[\s,]+'))
        .where(
          (value) => value.isNotEmpty,
        )
        .map(
          (value) => int.tryParse(value) ?? 0,
        )
        .toList();
  }

  // ============================================================
  // DRAW MAP
  // ============================================================

  @override
  Future<void> onLoad() async {
    final image = await _loadImage();
    _addTiles(image);
  }

  Future<Image> _loadImage() async {
    final cachedImage = _cachedMapImage;
    if (cachedImage != null) return cachedImage;

    final imageLoading = _mapImageLoading;
    if (imageLoading != null) return imageLoading;

    final loading = _decodeMapImage();
    _mapImageLoading = loading;
    try {
      final image = await loading;
      _cachedMapImage = image;
      return image;
    } catch (_) {
      _mapImageLoading = null;
      rethrow;
    }
  }

  Future<Image> _decodeMapImage() async {
    final bytes = await rootBundle.load('assets/maps/map2_preview.png');
    final codec = await instantiateImageCodec(bytes.buffer.asUint8List());
    try {
      final frame = await codec.getNextFrame();
      return frame.image;
    } finally {
      codec.dispose();
    }
  }

  void _addTiles(
    Image image,
  ) {
    final tileWidth = mapData['tileWidth'] as int;

    final tileHeight = mapData['tileHeight'] as int;

    final minX = mapData['minTileX'] as int;

    final minY = mapData['minTileY'] as int;

    final columns = image.width ~/ tileWidth;

    final tileCount = columns * (image.height ~/ tileHeight);
    final paint = Paint()
      ..isAntiAlias = false
      ..filterQuality = FilterQuality.none;

    for (final layer in mapData['layers'] as List<Map<String, dynamic>>) {
      for (final chunk in layer['chunks'] as List<Map<String, dynamic>>) {
        final data = chunk['data'] as List<int>;
        final chunkWidth = chunk['width'] as int;
        final chunkHeight = chunk['height'] as int;
        final chunkX = (chunk['x'] as int) - minX;
        final chunkY = (chunk['y'] as int) - minY;
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);
        var hasTiles = false;

        for (var index = 0; index < data.length; index++) {
          final gid = data[index];

          if (gid <= 0 || gid > tileCount) {
            continue;
          }

          final column = (gid - 1) % columns;
          final row = (gid - 1) ~/ columns;
          final localX = index % chunkWidth;
          final localY = index ~/ chunkWidth;
          canvas.drawImageRect(
            image,
            Rect.fromLTWH(
              (column * tileWidth).toDouble(),
              (row * tileHeight).toDouble(),
              tileWidth.toDouble(),
              tileHeight.toDouble(),
            ),
            Rect.fromLTWH(
              (chunkX + localX) * tileWidth.toDouble(),
              (chunkY + localY) * tileHeight.toDouble(),
              tileWidth.toDouble(),
              tileHeight.toDouble(),
            ),
            paint,
          );
          hasTiles = true;
        }

        final picture = recorder.endRecording();
        if (hasTiles) {
          final left = chunkX * tileWidth.toDouble();
          final top = chunkY * tileHeight.toDouble();
          _chunks.add(
            _TileChunk(
              picture: picture,
              bounds: Rect.fromLTWH(
                left,
                top,
                chunkWidth * tileWidth.toDouble(),
                chunkHeight * tileHeight.toDouble(),
              ).inflate(1),
            ),
          );
        } else {
          picture.dispose();
        }
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final visibleWorldRect = game.camera.visibleWorldRect;
    for (final chunk in _chunks) {
      if (chunk.bounds.overlaps(visibleWorldRect)) {
        canvas.drawPicture(chunk.picture);
      }
    }
  }

  @override
  void onRemove() {
    for (final chunk in _chunks) {
      chunk.picture.dispose();
    }
    _chunks.clear();
  }
}

class _TileChunk {
  final Picture picture;
  final Rect bounds;

  const _TileChunk({
    required this.picture,
    required this.bounds,
  });
}
